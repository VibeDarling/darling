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

// SubstrateLoader: loads the tweaks meant for this process.
//
// A tweak is a dylib in one of the directories below, next to a plist of
// the same name. The plist's Filter says which processes it is for:
//
//   Bundles                any of these bundle identifiers is loaded
//   Classes                any of these Objective-C classes exists
//   Executables            the executable has one of these names
//   CoreFoundationVersion  [min] or [min, max)
//   Mode                   "Any": one of the above is enough
//
// Without Mode, every key that is present must match. A plist without a
// Filter loads the tweak everywhere; a dylib without a plist is skipped.
// UIKit loads this at startup; other processes get it with
// DYLD_INSERT_LIBRARIES. _MSSafeMode=1 in the environment loads nothing;
// SUBSTRATE_LOADER_DEBUG=1 lists what is loaded and skipped.

#include <CoreFoundation/CoreFoundation.h>
#include <dirent.h>
#include <dlfcn.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *const SLDirectories[] = {
	"/Library/MobileSubstrate/DynamicLibraries",
	"/var/jb/Library/MobileSubstrate/DynamicLibraries",
	"/var/jb/usr/lib/TweakInject",
};

static bool SLDebug;

static CFStringRef SLExecutableName(void)
{
	char path[PATH_MAX];
	uint32_t size = sizeof(path);
	if (_NSGetExecutablePath(path, &size) != 0)
		return NULL;
	const char *slash = strrchr(path, '/');
	return CFStringCreateWithCString(NULL, slash ? slash + 1 : path, kCFStringEncodingUTF8);
}

static bool SLBundleLoaded(CFStringRef identifier)
{
	if (CFBundleGetBundleWithIdentifier(identifier) != NULL)
		return true;
	CFStringRef main = CFBundleGetIdentifier(CFBundleGetMainBundle());
	return main != NULL && CFEqual(main, identifier);
}

static bool SLClassExists(CFStringRef name)
{
	char buffer[256];
	return CFStringGetCString(name, buffer, sizeof(buffer), kCFStringEncodingUTF8) && objc_getClass(buffer) != Nil;
}

static bool SLExecutableIs(CFStringRef name)
{
	static CFStringRef executable;
	if (executable == NULL)
		executable = SLExecutableName();
	return executable != NULL && CFEqual(executable, name);
}

// Whether any string in list passes test. *present is set when the list is.
static bool SLAnyMatches(CFDictionaryRef filter, CFStringRef key, bool (*test)(CFStringRef), bool *present)
{
	CFArrayRef list = CFDictionaryGetValue(filter, key);
	*present = list != NULL && CFGetTypeID(list) == CFArrayGetTypeID();
	if (!*present)
		return false;
	for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
		CFStringRef item = CFArrayGetValueAtIndex(list, i);
		if (CFGetTypeID(item) == CFStringGetTypeID() && test(item))
			return true;
	}
	return false;
}

static bool SLVersionMatches(CFDictionaryRef filter, bool *present)
{
	CFArrayRef range = CFDictionaryGetValue(filter, CFSTR("CoreFoundationVersion"));
	*present = range != NULL && CFGetTypeID(range) == CFArrayGetTypeID() && CFArrayGetCount(range) > 0;
	if (!*present)
		return false;
	double bounds[2] = { 0, 0 };
	CFIndex count = CFArrayGetCount(range) > 1 ? 2 : 1;
	for (CFIndex i = 0; i < count; i++) {
		CFNumberRef number = CFArrayGetValueAtIndex(range, i);
		if (CFGetTypeID(number) == CFNumberGetTypeID())
			CFNumberGetValue(number, kCFNumberDoubleType, &bounds[i]);
	}
	return kCFCoreFoundationVersionNumber >= bounds[0] && (count < 2 || kCFCoreFoundationVersionNumber < bounds[1]);
}

static bool SLFilterMatches(CFDictionaryRef filter)
{
	if (filter == NULL || CFGetTypeID(filter) != CFDictionaryGetTypeID())
		return true;

	CFStringRef mode = CFDictionaryGetValue(filter, CFSTR("Mode"));
	bool any = mode != NULL && CFGetTypeID(mode) == CFStringGetTypeID() && CFEqual(mode, CFSTR("Any"));

	bool present[4];
	bool matched[4] = {
		SLVersionMatches(filter, &present[0]),
		SLAnyMatches(filter, CFSTR("Bundles"), SLBundleLoaded, &present[1]),
		SLAnyMatches(filter, CFSTR("Classes"), SLClassExists, &present[2]),
		SLAnyMatches(filter, CFSTR("Executables"), SLExecutableIs, &present[3]),
	};

	int presentCount = 0, matchedCount = 0;
	for (int i = 0; i < 4; i++) {
		presentCount += present[i];
		matchedCount += present[i] && matched[i];
	}
	if (presentCount == 0)
		return true;
	return any ? matchedCount > 0 : matchedCount == presentCount;
}

static CFPropertyListRef SLReadPlist(const char *path)
{
	FILE *file = fopen(path, "rb");
	if (file == NULL)
		return NULL;
	CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
	UInt8 buffer[4096];
	size_t length;
	while ((length = fread(buffer, 1, sizeof(buffer), file)) > 0)
		CFDataAppendBytes(data, buffer, length);
	fclose(file);
	CFPropertyListRef plist = CFPropertyListCreateWithData(NULL, data, kCFPropertyListImmutable, NULL, NULL);
	CFRelease(data);
	return plist;
}

static int SLIsDylib(const struct dirent *entry)
{
	size_t length = strlen(entry->d_name);
	return length > 6 && strcmp(entry->d_name + length - 6, ".dylib") == 0;
}

// Loads the tweaks in directory, in name order as Substrate does, skipping
// names already loaded from an earlier directory.
static void SLLoadDirectory(const char *directory, CFMutableSetRef loaded)
{
	struct dirent **entries;
	int count = scandir(directory, &entries, SLIsDylib, alphasort);
	if (count < 0)
		return;

	for (int i = 0; i < count; i++) {
		const char *name = entries[i]->d_name;
		char path[PATH_MAX], plistPath[PATH_MAX];
		snprintf(path, sizeof(path), "%s/%s", directory, name);
		snprintf(plistPath, sizeof(plistPath), "%s/%.*s.plist", directory, (int)(strlen(name) - 6), name);

		CFStringRef key = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);
		bool seen = CFSetContainsValue(loaded, key);
		CFPropertyListRef plist = seen ? NULL : SLReadPlist(plistPath);
		if (plist != NULL && CFGetTypeID(plist) == CFDictionaryGetTypeID()
				&& SLFilterMatches(CFDictionaryGetValue(plist, CFSTR("Filter")))) {
			CFSetAddValue(loaded, key);
			if (SLDebug)
				fprintf(stderr, "SubstrateLoader: loading %s\n", path);
			if (dlopen(path, RTLD_LAZY | RTLD_GLOBAL) == NULL)
				fprintf(stderr, "SubstrateLoader: %s\n", dlerror());
		} else if (SLDebug && !seen) {
			fprintf(stderr, "SubstrateLoader: skipping %s\n", path);
		}
		if (plist != NULL)
			CFRelease(plist);
		CFRelease(key);
		free(entries[i]);
	}
	free(entries);
}

__attribute__((constructor))
static void SLLoadTweaks(void)
{
	const char *safeMode = getenv("_MSSafeMode");
	if (safeMode != NULL && strcmp(safeMode, "0") != 0)
		return;
	SLDebug = getenv("SUBSTRATE_LOADER_DEBUG") != NULL;

	CFMutableSetRef loaded = CFSetCreateMutable(NULL, 0, &kCFTypeSetCallBacks);
	for (size_t i = 0; i < sizeof(SLDirectories) / sizeof(SLDirectories[0]); i++)
		SLLoadDirectory(SLDirectories[i], loaded);
	CFRelease(loaded);
}
