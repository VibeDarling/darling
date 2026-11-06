/*
 * This file is part of Darling.
 *
 * Copyright (C) 2026 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

// MSGetImageByName and MSFindSymbol: finding what to hook.

#include <substrate.h>
#include <dlfcn.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "internal.h"

// iOS frameworks live under /System/iOSSupport here, but tweaks name them
// by their iOS paths.
static const char MSiOSSupport[] = "/System/iOSSupport";

static bool MSSameFile(const char *a, const char *b)
{
	char resolvedA[PATH_MAX], resolvedB[PATH_MAX];
	return realpath(a, resolvedA) != NULL && realpath(b, resolvedB) != NULL
		&& strcmp(resolvedA, resolvedB) == 0;
}

static int MSImageIndex(MSImageRef image)
{
	uint32_t count = _dyld_image_count();
	for (uint32_t i = 0; i < count; i++) {
		if (_dyld_get_image_header(i) == image)
			return i;
	}
	return -1;
}

MSImageRef MSGetImageByName(const char *file)
{
	if (file == NULL)
		return NULL;

	char ios[PATH_MAX];
	snprintf(ios, sizeof(ios), "%s%s", MSiOSSupport, file);

	uint32_t count = _dyld_image_count();
	for (uint32_t i = 0; i < count; i++) {
		const char *name = _dyld_get_image_name(i);
		if (name != NULL && (strcmp(name, file) == 0 || strcmp(name, ios) == 0))
			return _dyld_get_image_header(i);
	}
	// The same file under another name: Versions/A, or a symlink.
	for (uint32_t i = 0; i < count; i++) {
		const char *name = _dyld_get_image_name(i);
		if (name != NULL && (MSSameFile(name, file) || MSSameFile(name, ios)))
			return _dyld_get_image_header(i);
	}
	if (MSDebug)
		MSLog("MSGetImageByName(%s): not loaded", file);
	return NULL;
}

// Looks name up in the image's symbol table, which holds local symbols
// too, unlike dlsym.
static void *MSFindSymbolInImage(uint32_t index, const char *name)
{
	const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(index);
	intptr_t slide = _dyld_get_image_vmaddr_slide(index);
	if (header == NULL || header->magic != MH_MAGIC_64)
		return NULL;

	const struct segment_command_64 *linkedit = NULL;
	const struct symtab_command *symtab = NULL;
	const struct load_command *command = (const struct load_command *)(header + 1);
	for (uint32_t i = 0; i < header->ncmds; i++) {
		if (command->cmd == LC_SEGMENT_64) {
			const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
			if (strcmp(segment->segname, SEG_LINKEDIT) == 0)
				linkedit = segment;
		} else if (command->cmd == LC_SYMTAB) {
			symtab = (const struct symtab_command *)command;
		}
		command = (const struct load_command *)((const char *)command + command->cmdsize);
	}
	if (linkedit == NULL || symtab == NULL)
		return NULL;

	uintptr_t base = slide + linkedit->vmaddr - linkedit->fileoff;
	const struct nlist_64 *symbols = (const struct nlist_64 *)(base + symtab->symoff);
	const char *strings = (const char *)(base + symtab->stroff);
	for (uint32_t i = 0; i < symtab->nsyms; i++) {
		const struct nlist_64 *symbol = &symbols[i];
		if ((symbol->n_type & N_STAB) != 0 || (symbol->n_type & N_TYPE) != N_SECT)
			continue;
		if (symbol->n_un.n_strx != 0 && strcmp(strings + symbol->n_un.n_strx, name) == 0)
			return (void *)(symbol->n_value + slide);
	}
	return NULL;
}

void *MSFindSymbol(MSImageRef image, const char *name)
{
	if (name == NULL)
		return NULL;

	void *result = NULL;
	if (image != NULL) {
		int index = MSImageIndex(image);
		if (index >= 0)
			result = MSFindSymbolInImage(index, name);
	} else {
		uint32_t count = _dyld_image_count();
		for (uint32_t i = 0; i < count && result == NULL; i++)
			result = MSFindSymbolInImage(i, name);
		if (result == NULL && name[0] == '_')
			result = dlsym(RTLD_DEFAULT, name + 1);
	}
	if (MSDebug)
		MSLog("MSFindSymbol(%p, %s) = %p", image, name, result);
	return result;
}
