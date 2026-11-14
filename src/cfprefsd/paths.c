/**
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

#include "paths.h"

#include <ctype.h>
#include <pwd.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <uuid/uuid.h>

// [real-Mac] request keys
#define KEY_DOMAIN "CFPreferencesDomain"
#define KEY_USER "CFPreferencesUser"
#define KEY_BY_HOST "CFPreferencesIsByHost"
#define KEY_MANAGED "CFPreferencesIsManaged"

// [open-src] CFPreferences.c: the global domain's file is ".GlobalPreferences"
#define ANY_APPLICATION "kCFPreferencesAnyApplication"
#define GLOBAL_FILE_NAME ".GlobalPreferences"

static bool flag(xpc_object_t request, const char* key) {
	xpc_object_t value = xpc_dictionary_get_value(request, key);
	return value != NULL && xpc_get_type(value) == XPC_TYPE_BOOL && xpc_bool_get_value(value);
}

// [open-src] _CFPreferencesGetByHostIdentifierString: a compatible host UUID contributes only its last (MAC) field, lowercased;
// any other UUID is used whole.
static bool by_host_identifier(char* out, size_t size) {
	uuid_t uuid;
	struct timespec wait = {1, 0};
	if (gethostuuid(uuid, &wait) != 0) return false;
	uuid_string_t text;
	uuid_unparse_lower(uuid, text);
	const char* compatible = "00000000-0000-1000-8000-";
	if (strncmp(text, compatible, strlen(compatible)) == 0) {
		snprintf(out, size, "%s", text + strlen(compatible));
	} else {
		snprintf(out, size, "%s", text);
	}
	return true;
}

bool prefs_layer_is_shared(xpc_object_t request) {
	return xpc_dictionary_get_value(request, KEY_USER) == NULL || flag(request, KEY_MANAGED);
}

bool prefs_layer_path(xpc_object_t request, uid_t uid, char* out, size_t size) {
	const char* domain = xpc_dictionary_get_string(request, KEY_DOMAIN);
	if (domain == NULL || domain[0] == '\0' || strchr(domain, '/') != NULL || strcmp(domain, ".") == 0 || strcmp(domain, "..") == 0) {
		return false;
	}
	const char* file = strcmp(domain, ANY_APPLICATION) == 0 ? GLOBAL_FILE_NAME : domain;
	bool any_user = xpc_dictionary_get_value(request, KEY_USER) == NULL;
	bool by_host = flag(request, KEY_BY_HOST);
	int n;
	if (flag(request, KEY_MANAGED)) {
		// NEEDS-REAL-MAC: where managed preferences live. GUESS: the conventional "Managed Preferences" tree, which Darling does not
		// populate, so the layer reads as empty.
		struct passwd* pw = any_user ? NULL : getpwuid(uid);
		if (!any_user && pw == NULL) return false;
		if (any_user) {
			n = snprintf(out, size, "/Library/Managed Preferences/%s.plist", file);
		} else {
			n = snprintf(out, size, "/Library/Managed Preferences/%s/%s.plist", pw->pw_name, file);
		}
	} else if (any_user) {
		// [open-src] "any user" preferences live in /Library/Preferences, without a host suffix
		n = snprintf(out, size, "/Library/Preferences/%s.plist", file);
	} else {
		struct passwd* pw = getpwuid(uid);
		if (pw == NULL || pw->pw_dir == NULL) return false;
		if (by_host) {
			char host[64];
			if (!by_host_identifier(host, sizeof(host))) return false;
			n = snprintf(out, size, "%s/Library/Preferences/ByHost/%s.%s.plist", pw->pw_dir, file, host);
		} else {
			n = snprintf(out, size, "%s/Library/Preferences/%s.plist", pw->pw_dir, file);
		}
	}
	return n > 0 && (size_t)n < size;
}
