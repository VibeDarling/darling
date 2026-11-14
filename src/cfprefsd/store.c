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


// A bplist00 refers to an object by index, and one object can be referred to many times, so a few bytes can describe a tree that has
// millions of nodes once read (CoreFoundation's reader builds every reference as its own container, and its writer then writes the whole
// tree out again: a 123-byte value of nested arrays that each point twice at the level below became a 13.6 MB file in 1.8 s as root).
// This walks the object table WITHOUT building anything, memoized per object so the walk is linear in the file, and refuses a plist that
// is malformed, has a reference cycle, nests deeper than MAX_BPLIST_DEPTH, or expands to more than MAX_EXPANDED_OBJECTS objects.
// Format from the public bplist00 layout (open-source CFBinaryPList.c, which the repository carries): 8-byte magic, objects, offset table,
// 32-byte trailer {5 unused, sort version, offset size, reference size, object count, top object, offset table start}, all big endian.
#define MAX_EXPANDED_OBJECTS (1u << 20)
#define MAX_BPLIST_DEPTH 64
#define SCAN_BAD UINT64_MAX

typedef struct {
	const uint8_t* bytes;
	size_t table_start;
	unsigned offset_size;
	unsigned ref_size;
	uint64_t objects;
	uint32_t* expanded;
	uint8_t* state; // 0 unvisited, 1 on the walk's path (a cycle if met again), 2 counted
} bplist_scan;

static uint64_t read_big_endian(const uint8_t* at, unsigned size) {
	uint64_t value = 0;
	while (size-- > 0) value = (value << 8) | *at++;
	return value;
}

static uint64_t scan_object(bplist_scan* scan, uint64_t index, int depth) {
	if (index >= scan->objects || depth > MAX_BPLIST_DEPTH) return SCAN_BAD;
	if (scan->state[index] == 2) return scan->expanded[index];
	if (scan->state[index] == 1) return SCAN_BAD;
	uint64_t offset = read_big_endian(scan->bytes + scan->table_start + index * scan->offset_size, scan->offset_size);
	if (offset < 8 || offset >= scan->table_start) return SCAN_BAD;
	unsigned type = scan->bytes[offset] >> 4;
	uint64_t total = 1;
	if (type >= 0xA && type <= 0xD) { // array, ordered set, set (one reference per member), dictionary (a key and a value reference)
		const uint8_t* at = scan->bytes + offset + 1;
		const uint8_t* end = scan->bytes + scan->table_start;
		uint64_t count = scan->bytes[offset] & 0xF;
		if (count == 0xF) {
			if (at >= end || (*at >> 4) != 1) return SCAN_BAD;
			unsigned width = 1u << (*at & 0xF);
			if (width > 8 || (size_t)(end - at) < 1 + width) return SCAN_BAD;
			count = read_big_endian(at + 1, width);
			at += 1 + width;
		}
		uint64_t references = type == 0xD ? count * 2 : count;
		if (count > scan->table_start || (uint64_t)(end - at) / scan->ref_size < references) return SCAN_BAD;
		scan->state[index] = 1;
		for (uint64_t i = 0; i < references; ++i) {
			uint64_t child = scan_object(scan, read_big_endian(at + i * scan->ref_size, scan->ref_size), depth + 1);
			if (child == SCAN_BAD) return SCAN_BAD;
			total += child;
			if (total > MAX_EXPANDED_OBJECTS) return SCAN_BAD;
		}
	}
	scan->expanded[index] = (uint32_t)total;
	scan->state[index] = 2;
	return total;
}

// True when the bytes cannot be a binary plist (the XML and text formats cannot share objects) or are one within the limits above.
// The reader accepts "bplist0" followed by ANY one character as the magic (CFBinaryPList.c, __CFBinaryPlistGetTopLevelInfo: "SnowLeopard
// will parse bplist0?"), so everything that starts with "bplist0" is scanned, and anything else that starts with "bplist" is refused
// rather than waved through as an unknown format.
static bool plist_bytes_within_limits(const uint8_t* bytes, size_t length) {
	if (length < 6 || memcmp(bytes, "bplist", 6) != 0) return true;
	if (length < 7 || bytes[6] != '0') return false;
	if (length < 8 + 32) return false;
	const uint8_t* trailer = bytes + length - 32;
	bplist_scan scan = { bytes, 0, trailer[6], trailer[7], read_big_endian(trailer + 8, 8), NULL, NULL };
	uint64_t top = read_big_endian(trailer + 16, 8);
	uint64_t table = read_big_endian(trailer + 24, 8);
	if (scan.offset_size < 1 || scan.offset_size > 8 || scan.ref_size < 1 || scan.ref_size > 8) return false;
	if (scan.objects == 0 || scan.objects > length || table < 8 || table > length - 32) return false;
	if ((length - 32 - table) / scan.offset_size < scan.objects) return false;
	scan.table_start = (size_t)table;
	scan.expanded = calloc((size_t)scan.objects, sizeof(uint32_t));
	scan.state = calloc((size_t)scan.objects, 1);
	bool ok = scan.expanded != NULL && scan.state != NULL && scan_object(&scan, top, 0) != SCAN_BAD;
	free(scan.expanded);
	free(scan.state);
	return ok;
}

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
	if (!plist_bytes_within_limits(bytes, (size_t)got)) {
		free(bytes);
		*failure = "the preferences file expands to too many objects or is malformed";
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
	// the written file must stay one this daemon can deliver and read back: bounded bytes, and a bounded number of objects once expanded
	if ((uint64_t)CFDataGetLength(data) > PREFS_MAX_LAYER_BYTES || !plist_bytes_within_limits(CFDataGetBytePtr(data), (size_t)CFDataGetLength(data))) {
		CFRelease(data);
		return "the preferences would exceed the size or object limits";
	}
	char temporary[PATH_MAX];
	if (snprintf(temporary, sizeof(temporary), "%s.cfprefsd-%d", path, (int)getpid()) >= (int)sizeof(temporary)) {
		CFRelease(data);
		return "path too long";
	}
	// the replacement keeps the mode of the file it replaces (a new file gets 0600): a rewrite must not change who can read a layer
	mode_t mode = 0600;
	struct stat existing;
	if (lstat(path, &existing) == 0 && S_ISREG(existing.st_mode)) mode = existing.st_mode & 0777;
	// exclusive and not following links: a stale or planted name is an error, never a redirect
	int fd = open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
	const char* failure = NULL;
	if (fd < 0) {
		failure = "cannot create the temporary preferences file";
	} else if (fchmod(fd, mode) != 0) {
		failure = "cannot set the mode of the temporary preferences file";
		close(fd);
		unlink(temporary);
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
	if (!plist_bytes_within_limits(bytes, length)) {
		free(bytes);
		return NULL;
	}
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

bool prefs_store_acting_ids(uid_t uid, gid_t gid, uid_t* acting_uid, gid_t* acting_gid) {
	saved_identity saved;
	bool ok = assume_identity(uid, gid, &saved);
	if (ok) {
		*acting_uid = geteuid();
		*acting_gid = getegid();
	}
	if (!restore_identity(&saved)) {
		fprintf(stderr, "cfprefsd: cannot restore credentials, aborting\n");
		abort();
	}
	return ok;
}

xpc_object_t prefs_store_copy_layer(uid_t uid, gid_t gid, const char* path, size_t* budget) {
	xpc_object_t result = NULL;
	saved_identity saved;
	if (!assume_identity(uid, gid, &saved)) {
		if (!restore_identity(&saved)) {
			fprintf(stderr, "cfprefsd: cannot restore credentials after a failed identity switch, aborting\n");
			abort();
		}
		return NULL;
	}
	struct stat st;
	// absent, empty, not a regular file, or larger than the bytes this reply may still carry: no plist is delivered, and a layer that
	// is too large is not even parsed (the size is checked before the file is loaded)
	if (lstat(path, &st) == 0 && S_ISREG(st.st_mode) && st.st_size > 0 && (uint64_t)st.st_size <= *budget) {
		const char* failure = NULL;
		CFMutableDictionaryRef dictionary = load_dictionary(path, &failure);
		if (dictionary != NULL) {
			CFDataRef data = CFPropertyListCreateData(kCFAllocatorDefault, dictionary, kCFPropertyListBinaryFormat_v1_0, 0, NULL);
			if (data != NULL && (uint64_t)CFDataGetLength(data) <= *budget) {
				result = xpc_data_create(CFDataGetBytePtr(data), (size_t)CFDataGetLength(data));
				*budget -= (size_t)CFDataGetLength(data);
			}
			if (data != NULL) CFRelease(data);
			CFRelease(dictionary);
		}
	}
	if (!restore_identity(&saved)) {
		fprintf(stderr, "cfprefsd: cannot restore credentials, aborting\n");
		abort();
	}
	return result;
}
