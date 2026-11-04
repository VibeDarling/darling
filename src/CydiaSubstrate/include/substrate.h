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

/*
 * The Cydia Substrate API that jailbreak tweaks are built against.
 * Darling implements it in /Library/Frameworks/CydiaSubstrate.framework.
 */

#ifndef SUBSTRATE_H_
#define SUBSTRATE_H_

#include <stdbool.h>
#include <stddef.h>
#include <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef const void *MSImageRef;

/* Logs every hook to stderr when set. */
extern bool MSDebug;

/* A loaded image by its path, or NULL. Images are never loaded by this. */
MSImageRef MSGetImageByName(const char *file);

/* The address of a symbol in an image (or in any image, when NULL),
 * local symbols included. Names are mangled: "_malloc", not "malloc". */
void *MSFindSymbol(MSImageRef image, const char *name);

/* Redirects symbol to replace. *result, when result is not NULL, is set to
 * a function that runs the original. */
void MSHookFunction(void *symbol, void *replace, void **result);

/* Writes data over code or read-only memory. */
void MSHookMemory(void *target, const void *data, size_t size);

/* Replaces a method of _class. *result is set to the implementation that
 * was in effect, inherited ones included. */
void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);

#ifdef __cplusplus
}

template <typename Type_>
static inline void MSHookFunction(Type_ *symbol, Type_ *replace, Type_ **result) {
	MSHookFunction(reinterpret_cast<void *>(symbol), reinterpret_cast<void *>(replace), reinterpret_cast<void **>(result));
}

template <typename Type_>
static inline void MSHookFunction(Type_ *symbol, Type_ *replace) {
	MSHookFunction(symbol, replace, reinterpret_cast<Type_ **>(NULL));
}

template <typename Type_>
static inline void MSHookMessage(Class _class, SEL sel, Type_ *imp, Type_ **result) {
	MSHookMessageEx(_class, sel, reinterpret_cast<IMP>(imp), reinterpret_cast<IMP *>(result));
}
#endif

#endif
