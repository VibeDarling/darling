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

// MSHookMessageEx: replacing Objective-C methods.

#include <substrate.h>
#include <stdlib.h>

#include "internal.h"

static bool MSClassOwnsMethod(Class _class, Method method)
{
	unsigned int count;
	Method *methods = class_copyMethodList(_class, &count);
	bool owns = false;
	for (unsigned int i = 0; i < count && !owns; i++)
		owns = methods[i] == method;
	free(methods);
	return owns;
}

void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result)
{
	if (MSDebug)
		MSLog("MSHookMessageEx(%s, %s)", _class ? class_getName(_class) : "nil", sel ? sel_getName(sel) : "nil");

	Method method = _class && sel ? class_getInstanceMethod(_class, sel) : NULL;
	if (method == NULL) {
		MSLog("MSHookMessageEx: %s has no method %s", _class ? class_getName(_class) : "nil", sel ? sel_getName(sel) : "nil");
		if (result != NULL)
			*result = NULL;
		return;
	}

	// The original is set before the hook goes in, which may run at once.
	IMP original = method_getImplementation(method);
	if (result != NULL)
		*result = original;

	// An inherited method is overridden in _class, so the superclass keeps
	// its own. The override calls what the superclass had when it was
	// hooked, as Substrate's does not: hook superclasses first.
	if (MSClassOwnsMethod(_class, method))
		method_setImplementation(method, imp);
	else
		class_addMethod(_class, sel, imp, method_getTypeEncoding(method));
}
