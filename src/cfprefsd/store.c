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

#include "store.h"

#include <CoreFoundation/CoreFoundation.h>

#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define MAX_FILE_SIZE (64 * 1024 * 1024)
#define MAX_DEPTH 32

// The xpc value of a write converted to the property-list type it stands for. [observed] strings arrive as xpc strings; the other
// type mappings are the natural ones and are NEEDS-REAL-MAC until each is observed (see OBSERVED.md for which were).
static CFTypeRef convert_value(xpc_object_t value, int depth) {
	if (depth > MAX_DEPTH) return NULL;
	xpc_type_t type = xpc_get_type(value);
	if (type == XPC_TYPE_STRING) {
		return CFStringCreateWithCString(kCFAllocatorDefault, xpc_string_get_string_ptr(value), kCFStringEncodingUTF8);
	} else if (type == XPC_TYPE_INT64) {
		int64_t number = xpc_int64_get_value(value);
		return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &number);
	} else if (type == XPC_TYPE_UINT64) {
		uint64_t big = xpc_uint64_get_value(value);
		if (big > INT64_MAX) return NULL;
		int64_t number = (int64_t)big;
		return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &number);
	} else if (type == XPC_TYPE_DOUBLE) {
		double number = xpc_double_get_value(value);
		return CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &number);
	} else if (type == XPC_TYPE_BOOL) {
		return CFRetain(xpc_bool_get_value(value) ? kCFBooleanTrue : kCFBooleanFalse);
	} else if (type == XPC_TYPE_DATA) {
		size_t length = xpc_data_get_length(value);
		uint8_t* bytes = malloc(length > 0 ? length : 1);
		if (bytes == NULL) return NULL;
		xpc_data_get_bytes(value, bytes, 0, length);
		CFDataRef data = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
		free(bytes);
		return data;
	} else if (type == XPC_TYPE_DATE) {
		// xpc dates count nanoseconds from 1970 (public xpc.h); CFAbsoluteTime counts seconds from 2001
		CFAbsoluteTime seconds = (CFAbsoluteTime)xpc_date_get_value(value) / 1e9 - kCFAbsoluteTimeIntervalSince1970;
		return CFDateCreate(kCFAllocatorDefault, seconds);
	} else if (type == XPC_TYPE_ARRAY) {
		CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
		__block bool ok = true;
		xpc_array_apply(value, ^bool(size_t index, xpc_object_t item) {
			(void)index;
			CFTypeRef converted = convert_value(item, depth + 1);
			if (converted == NULL) {
				ok = false;
				return false;
			}
			CFArrayAppendValue(array, converted);
			CFRelease(converted);
			return true;
		});
		if (!ok) {
			CFRelease(array);
			return NULL;
		}
		return array;
	} else if (type == XPC_TYPE_DICTIONARY) {
		CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		__block bool ok = true;
		xpc_dictionary_apply(value, ^bool(const char* name, xpc_object_t item) {
			CFTypeRef converted = convert_value(item, depth + 1);
			CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingUTF8);
			if (converted == NULL || key == NULL) {
				ok = false;
			} else {
				CFDictionarySetValue(dictionary, key, converted);
			}
			if (converted != NULL) CFRelease(converted);
			if (key != NULL) CFRelease(key);
			return ok;
		});
		if (!ok) {
			CFRelease(dictionary);
			return NULL;
		}
		return dictionary;
	}
	return NULL;
}

static bool make_parent_directories(const char* path) {
	char dir[PATH_MAX];
	snprintf(dir, sizeof(dir), "%s", path);
	char* slash = strrchr(dir, '/');
	if (slash == NULL || slash == dir) return false;
	*slash = '\0';
	for (char* cursor = dir + 1; ; ++cursor) {
		if (*cursor == '/' || *cursor == '\0') {
			char saved = *cursor;
			*cursor = '\0';
			if (mkdir(dir, 0700) != 0 && errno != EEXIST) return false;
			*cursor = saved;
			if (saved == '\0') break;
		}
	}
	return true;
}

// Reads the plist at path as a mutable dictionary: an empty one when the file is absent or empty. NULL (and *failure set) when the
// file exists but is not a plist dictionary: it is never overwritten.
static CFMutableDictionaryRef load_dictionary(const char* path, const char** failure) {
	int fd = open(path, O_RDONLY | O_NOFOLLOW);
	if (fd < 0) {
		if (errno == ENOENT) return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		*failure = "cannot open the preferences file";
		return NULL;
	}
	struct stat st;
	if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_size > MAX_FILE_SIZE) {
		close(fd);
		*failure = "the preferences file is not a regular file of acceptable size";
		return NULL;
	}
	if (st.st_size == 0) {
		close(fd);
		return CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	}
	uint8_t* bytes = malloc((size_t)st.st_size);
	ssize_t got = bytes != NULL ? read(fd, bytes, (size_t)st.st_size) : -1;
	close(fd);
	if (got != st.st_size) {
		free(bytes);
		*failure = "cannot read the preferences file";
		return NULL;
	}
	CFDataRef data = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)got);
	free(bytes);
	CFTypeRef plist = CFPropertyListCreateWithData(kCFAllocatorDefault, data, kCFPropertyListMutableContainersAndLeaves, NULL, NULL);
	CFRelease(data);
	if (plist == NULL || CFGetTypeID(plist) != CFDictionaryGetTypeID()) {
		if (plist != NULL) CFRelease(plist);
		*failure = "the preferences file is not a property-list dictionary";
		return NULL;
	}
	return (CFMutableDictionaryRef)plist;
}

static const char* save_dictionary(const char* path, CFDictionaryRef dictionary) {
	CFDataRef data = CFPropertyListCreateData(kCFAllocatorDefault, dictionary, kCFPropertyListBinaryFormat_v1_0, 0, NULL);
	if (data == NULL) return "cannot serialize the preferences";
	char temporary[PATH_MAX];
	if (snprintf(temporary, sizeof(temporary), "%s.cfprefsd-%d", path, (int)getpid()) >= (int)sizeof(temporary)) {
		CFRelease(data);
		return "path too long";
	}
	// exclusive and not following links: a stale or planted name is an error, never a redirect
	int fd = open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
	const char* failure = NULL;
	if (fd < 0) {
		failure = "cannot create the temporary preferences file";
	} else {
		const uint8_t* bytes = CFDataGetBytePtr(data);
		CFIndex remaining = CFDataGetLength(data);
		while (remaining > 0) {
			ssize_t written = write(fd, bytes, (size_t)remaining);
			if (written <= 0) {
				failure = "cannot write the preferences file";
				break;
			}
			bytes += written;
			remaining -= written;
		}
		if (failure == NULL && fsync(fd) != 0) failure = "cannot flush the preferences file";
		close(fd);
		if (failure == NULL && rename(temporary, path) != 0) failure = "cannot replace the preferences file";
		if (failure != NULL) unlink(temporary);
	}
	CFRelease(data);
	return failure;
}

// Which uid is trusted: the peer's effective uid and gid as libxpc reports them for the connection
// (xpc_connection_get_euid/egid, read in cfprefsd.c), never a number the request carries. Darling's audit-token uid is 0 for every
// guest process (the RunningBoard stand-in's agent found the same), which is why the audit-token uid is not used.
//
// The daemon runs as root under launchd and does the file work as the client, so the kernel, not our path checks, decides what the
// client may touch. Root's supplementary groups are dropped for the duration (a client must not get root's group access). The
// switch fails closed: any step that fails is undone and no file is opened. If undoing fails the credentials are half-switched and
// the daemon aborts rather than carry on. Called on the daemon's serial queue only (credentials are process-wide).
typedef struct {
	uid_t euid;
	gid_t egid;
	gid_t groups[NGROUPS_MAX];
	int group_count;
	bool switched;
} saved_identity;

static bool assume_identity(uid_t uid, gid_t gid, saved_identity* saved) {
	saved->euid = geteuid();
	saved->egid = getegid();
	saved->switched = false;
	if (uid == saved->euid && gid == saved->egid) return true; // already that user: nothing to switch
	if (saved->euid != 0) return false; // only root may become somebody else
	saved->group_count = getgroups(NGROUPS_MAX, saved->groups);
	if (saved->group_count < 0) return false;
	saved->switched = true;
	// order matters: supplementary groups and the gid need root's euid, so the uid comes last
	if (setgroups(1, &gid) == 0 && setegid(gid) == 0 && seteuid(uid) == 0 && geteuid() == uid && getegid() == gid) return true;
	return false;
}

// Undo in reverse order. Returns false when the original credentials could not be restored.
static bool restore_identity(const saved_identity* saved) {
	if (!saved->switched) return true;
	return seteuid(saved->euid) == 0 && setegid(saved->egid) == 0 && setgroups(saved->group_count, saved->groups) == 0 &&
		geteuid() == saved->euid && getegid() == saved->egid;
}

// [observed] a value that is not a string or a boolean arrives as xpc data holding a property list in the public bplist00 format
// whose top-level object is the value (an integer 4242 arrived as 44 bytes of bplist00). Anything else is converted natively.
static CFTypeRef decode_write_value(xpc_object_t value) {
	if (xpc_get_type(value) != XPC_TYPE_DATA) return convert_value(value, 0);
	size_t length = xpc_data_get_length(value);
	if (length == 0 || length > MAX_FILE_SIZE) return NULL;
	uint8_t* bytes = malloc(length);
	if (bytes == NULL) return NULL;
	xpc_data_get_bytes(value, bytes, 0, length);
	CFDataRef data = CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
	free(bytes);
	CFTypeRef plist = CFPropertyListCreateWithData(kCFAllocatorDefault, data, kCFPropertyListImmutable, NULL, NULL);
	CFRelease(data);
	return plist;
}

const char* prefs_store_write(xpc_object_t request, uid_t uid, gid_t gid, const char* path, const char* key_name, const char* value_name) {
	const char* key = xpc_dictionary_get_string(request, key_name);
	if (key == NULL || key[0] == '\0') return "the write has no string key";
	xpc_object_t value = xpc_dictionary_get_value(request, value_name);
	CFTypeRef converted = NULL;
	if (value != NULL && xpc_get_type(value) != XPC_TYPE_NULL) {
		converted = decode_write_value(value);
		if (converted == NULL) return "the value is of a type this stand-in does not store";
	}
	CFStringRef cf_key = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
	if (cf_key == NULL) {
		if (converted != NULL) CFRelease(converted);
		return "the key is not valid UTF-8";
	}

	saved_identity saved;
	const char* failure = NULL;
	if (!assume_identity(uid, gid, &saved)) {
		failure = "cannot act as the requesting user";
		if (!restore_identity(&saved)) {
			fprintf(stderr, "cfprefsd: cannot restore credentials after a failed identity switch, aborting\n");
			abort();
		}
	} else {
		if (!make_parent_directories(path)) {
			failure = "cannot create the preferences directory";
		} else {
			CFMutableDictionaryRef dictionary = load_dictionary(path, &failure);
			if (dictionary != NULL) {
				if (converted != NULL) {
					CFDictionarySetValue(dictionary, cf_key, converted);
				} else {
					CFDictionaryRemoveValue(dictionary, cf_key);
				}
				failure = save_dictionary(path, dictionary);
				CFRelease(dictionary);
			}
		}
		if (!restore_identity(&saved)) {
			fprintf(stderr, "cfprefsd: cannot restore credentials, aborting\n");
			abort();
		}
	}
	CFRelease(cf_key);
	if (converted != NULL) CFRelease(converted);
	return failure;
}
