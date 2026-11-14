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

// Stand-in for the preferences daemon that CoreFoundation clients from a macOS dyld cache look up as
// "com.apple.cfprefsd.daemon". Darling's own CF-Lite never talks to it (it reads and writes the plist files itself), so a
// process on the cache's CoreFoundation could not store a preference: no daemon, no write. This service stores what such a
// client writes in the ordinary plist files Darling's own CFPreferences and `defaults` already use, and tells the client
// where those files are. It is on demand (see the launchd plist): processes that never ask for it never start it.
//
// Where each statement comes from (OBSERVED.md in the PR notes has the same list):
//   [real-Mac]  output of our own client program on a real Mac (reply key names and types of operations 1, 5 and 9)
//   [observed]  what the cache's CoreFoundation sends to THIS listener, logged by our own test programs (keys, xpc types)
//   [open-src]  open-source CF (src/external/corefoundation, CFPreferences.c): where preference files live
//   GUESS / NEEDS-REAL-MAC: no permitted source; the choice is ours and only its effect on the client was observed.
//
// Reads: a client of the cache's CoreFoundation never asks for values separately. It sends operation 1 without Key (alone or as items of
// a batch) and takes the layer's dictionary from the reply key CFPreferencesPropertyList (a bplist00 in xpc data), together with the
// slot triple whose state tells it when its copy is out of date (observed on macOS 26.1 with our own client program, see the PR notes).
// A real daemon refused our hand-built write requests ("Path not accessible"); the requests the cache's CoreFoundation itself sends are
// accepted here.

#include "paths.h"
#include "store.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <xpc/xpc.h>

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <pwd.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define SERVICE_NAME "com.apple.cfprefsd.daemon"
#define LOG_PATH "/var/log/cfprefsd.log"
#define LOG_ENV "DARLING_CFPREFSD_LOG"

// [real-Mac] request keys
#define KEY_OPERATION "CFPreferencesOperation"
#define KEY_MESSAGES "CFPreferencesMessages"
// [real-Mac] reply keys
#define KEY_SHMEM_NAME "CFPreferencesShmemName"
#define KEY_SHMEM_INDEX "CFPreferencesShmemIndex"
#define KEY_SHMEM_STATE "CFPreferencesShmemState"
#define KEY_PATH "CFPreferencesUncanonicalizedPath"
// [observed] the two keys a write adds to an operation-1 request
#define KEY_WRITE_KEY "Key"
#define KEY_WRITE_VALUE "Value"
// [real-Mac, macOS 26.1, our own client program] the reply to a request the daemon refused is the triple plus these two keys
// (CFPreferencesErrorType int64 0, CFPreferencesErrorDescription "Path not accessible"). NEEDS-REAL-MAC: the type values for other
// refusals (this stand-in always sends 0) and the exact texts. Never silence, never a cancelled connection (clients retry hot).
#define KEY_ERROR_TYPE "CFPreferencesErrorType"
#define KEY_ERROR_DESCRIPTION "CFPreferencesErrorDescription"
// Darling-only: a request carrying this bool true is answered with the caller identity the daemon holds (for tests)
#define KEY_WHOAMI "darling-whoami"

// [real-Mac] the shared region is 16384 bytes and is named "apple.cfprefs.daemonv1". [observed] the cache's CoreFoundation opens the name the
// REPLY carries (host strace of a client with a daemon that replied with another name: it opened that name and read through it), so this
// stand-in names its region "apple.cfprefs.daemonv1-<inode of the container's root>": shm names are one host-wide namespace and every
// container runs its own daemon, so a fixed name would let each daemon start take the region from another container's daemon.
#define SHMEM_NAME_PREFIX "apple.cfprefs.daemonv1"
static char shmem_name[128];
#define SHMEM_SIZE 16384
// [real-Mac, observed on macOS 26.1 with our own client program] slots are 4-byte units addressed by the reply's index (index*4), each
// layer has its own index, and CFPreferencesShmemState equals the uint32 in that slot: a per-layer generation counter.
#define SHMEM_SLOTS (SHMEM_SIZE / 4)
// [real-Mac, same source] an extra reply key holding the layer's current dictionary as a bplist00 in xpc data; omitted for a layer with no file
#define KEY_PLIST "CFPreferencesPropertyList"

enum {
	// [real-Mac] with no extra keys: reply is the shared-region triple; [observed] with Key (+ Value): a write
	OP_SLOT_OR_WRITE = 1,
	// [real-Mac] a batch: CFPreferencesMessages holds the requests, the reply holds one reply per item
	OP_BATCH = 5,
	// [real-Mac] the plist path of the layer the request names
	OP_PATH = 9,
};

// exported by libxpc but missing from its public header
extern const char* xpc_type_get_name(xpc_type_t type);

// A batch holds the requests of one CFPreferences call: 13 items were observed. The cap bounds the work one message can cause.
#define MAX_BATCH_ITEMS 64
// The bytes of layer plists one request (a single operation or a whole batch) may put into its reply. Once spent, further items are
// answered without CFPreferencesPropertyList, so the client sees no values for them. The limits of a real daemon are unknown (NEEDS-REAL-MAC).
#define REPLY_BYTE_BUDGET PREFS_MAX_LAYER_BYTES

static bool verbose = false;

static void daemon_log(const char* format, ...) __attribute__((format(printf, 1, 2)));
static void daemon_log(const char* format, ...) {
	char line[512];
	va_list args;
	va_start(args, format);
	vsnprintf(line, sizeof(line), format, args);
	va_end(args);
	fprintf(stderr, "%lld cfprefsd: %s\n", (long long)time(NULL), line);
	fflush(stderr);
}

// Names and types only: key names are peer-controlled (length-capped, unprintable bytes shown as '?'); values are never logged.
static void log_request(uid_t uid, xpc_object_t message, const char* tag) {
	struct { char text[400]; size_t used; } acc = { "", 0 };
	typeof(acc)* keys_acc = &acc;
	xpc_dictionary_apply(message, ^bool(const char* key, xpc_object_t value) {
		char clean[49];
		size_t i = 0;
		for (; key[i] != '\0' && i < sizeof(clean) - 1; ++i) {
			clean[i] = (key[i] >= 0x20 && key[i] < 0x7f) ? key[i] : '?';
		}
		clean[i] = '\0';
		int n = snprintf(keys_acc->text + keys_acc->used, sizeof(keys_acc->text) - keys_acc->used, " %s:%s", clean, xpc_type_get_name(xpc_get_type(value)));
		if (n > 0) keys_acc->used = keys_acc->used + (size_t)n < sizeof(keys_acc->text) ? keys_acc->used + (size_t)n : sizeof(keys_acc->text) - 1;
		return true;
	});
	const char* keys = acc.text;
	xpc_object_t operation = xpc_dictionary_get_value(message, KEY_OPERATION);
	if (operation != NULL && xpc_get_type(operation) == XPC_TYPE_INT64) {
		daemon_log("%s uid %u: operation %lld,%s", tag, (unsigned)uid, (long long)xpc_int64_get_value(operation), keys);
	} else {
		daemon_log("%s uid %u: no int64 operation,%s", tag, (unsigned)uid, keys);
	}
}

static int shmem_fd = -1;
static volatile uint32_t* slots = NULL; // the region mapped read-write by the daemon only; NULL when it could not be mapped

// Creates the shared region afresh: another process on the host may have made /dev/shm/apple.cfprefs.daemonv1 first (owned by someone
// else, too small, or still mapped writable), so an existing one is never reused. Unlink, create exclusively (so the object is ours),
// size it, and check the size and the owner before mapping. False means the daemon must not run.
static bool shmem_create(void) {
	// the inode of the container's root directory: different for every prefix, the same for every start of one prefix (so a restart
	// replaces its own region instead of leaving a new object behind)
	struct stat root;
	if (stat("/", &root) != 0) {
		daemon_log("cannot identify the container (errno %d)", errno);
		return false;
	}
	snprintf(shmem_name, sizeof(shmem_name), SHMEM_NAME_PREFIX "-%llx", (unsigned long long)root.st_ino);
	// Clients map the region by name, read-only ([observed] a reading client opens it O_RDONLY, a writing client does not open it), and only
	// read the slot the reply names. So only the daemon may write it: mode 0644, set explicitly because the creation mask would otherwise decide.
	if (shm_unlink(shmem_name) != 0 && errno != ENOENT) {
		daemon_log("cannot remove an existing %s (errno %d)", shmem_name, errno);
		return false;
	}
	shmem_fd = shm_open(shmem_name, O_RDWR | O_CREAT | O_EXCL, 0644);
	if (shmem_fd < 0) {
		daemon_log("cannot create %s exclusively (errno %d)", shmem_name, errno);
		return false;
	}
	struct stat st;
	if (fchmod(shmem_fd, 0644) != 0 || ftruncate(shmem_fd, SHMEM_SIZE) != 0 || fstat(shmem_fd, &st) != 0) {
		daemon_log("cannot size or restrict %s (errno %d)", shmem_name, errno);
		return false;
	}
	if (st.st_size != SHMEM_SIZE || st.st_uid != geteuid()) {
		daemon_log("%s has size %lld owner %u, expected %d and %u", shmem_name, (long long)st.st_size, (unsigned)st.st_uid, SHMEM_SIZE, (unsigned)geteuid());
		return false;
	}
	void* mapped = mmap(NULL, SHMEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, shmem_fd, 0);
	if (mapped == MAP_FAILED) {
		daemon_log("cannot map %s (errno %d)", shmem_name, errno);
		return false;
	}
	slots = mapped;
	return true;
}

// GUESS: a stable slot per plist path (FNV-1a), so the same layer always gets the same index. The real numbering is unknown. Two layers
// can share a slot: that only makes a client reload a layer that did not change.
static int64_t slot_index_for(const char* path) {
	uint32_t hash = 2166136261u;
	for (; *path != '\0'; ++path) {
		hash = (hash ^ (uint8_t)*path) * 16777619u;
	}
	return (int64_t)(hash % SHMEM_SLOTS);
}

static uint32_t slot_value(int64_t index) {
	return slots != NULL && index >= 0 && index < SHMEM_SLOTS ? __atomic_load_n(&slots[index], __ATOMIC_ACQUIRE) : 0;
}

// the layer's generation counter goes up on every write to it
static void slot_bump(int64_t index) {
	if (slots != NULL && index >= 0 && index < SHMEM_SLOTS) __atomic_add_fetch(&slots[index], 1, __ATOMIC_RELEASE);
}

static void reply_error(xpc_object_t reply, const char* text) {
	xpc_dictionary_set_int64(reply, KEY_ERROR_TYPE, 0);
	xpc_dictionary_set_string(reply, KEY_ERROR_DESCRIPTION, text);
}

// Who is asking. uid and gid are the connection's effective ids from libxpc (xpc_connection_get_euid/egid). libxpc fills them only
// from the audit trailer of a message it received (src/external/libxpc connection.m: remote_credentials starts as all 0xff and is set
// from get_audit_token(header), the trailer the Mach layer attaches), never from anything inside the message, so a client cannot
// choose them. Darling's audit-token "auid" is 0 for every guest process, which is why only the effective ids are read. A caller whose
// credentials were never set (all ones, or no pid) is not verified and gets an error for every request; a zeroed field cannot pass for
// root that way because unset reads as all ones, not zero. tests/cfprefsd-service.c compares the ids the daemon holds (request key
// "darling-whoami") with the client's own getuid, getgid and getpid.
// Not available under Darling: a cross-check against the kernel's process table (the emulated table reports uid 0 and no groups for
// every process), so none is done.
typedef struct {
	uid_t uid;
	gid_t gid;
	pid_t pid;
	bool verified;
} caller_t;

static bool credentials_present(pid_t pid, uid_t uid, gid_t gid) {
	return pid > 0 && uid != (uid_t)-1 && gid != (gid_t)-1;
}

static xpc_object_t handle_one(const caller_t* caller, xpc_object_t request, bool in_batch, size_t* budget);
static void reply_slot(xpc_object_t reply, const char* path);

// op 5: reply holds one reply per request item. [observed] items can be null (the client leaves a slot empty): answered with null.
// A batch cannot hold a batch (the recursion would be unbounded) and holds at most MAX_BATCH_ITEMS items.
static void handle_batch(const caller_t* caller, xpc_object_t request, xpc_object_t reply, size_t* budget) {
	xpc_object_t items = xpc_dictionary_get_value(request, KEY_MESSAGES);
	if (items == NULL || xpc_get_type(items) != XPC_TYPE_ARRAY) {
		reply_error(reply, "cfprefsd stand-in: batch without CFPreferencesMessages");
		return;
	}
	if (xpc_array_get_count(items) > MAX_BATCH_ITEMS) {
		reply_error(reply, "cfprefsd stand-in: batch has too many items");
		return;
	}
	xpc_object_t replies = xpc_array_create(NULL, 0);
	xpc_array_apply(items, ^bool(size_t index, xpc_object_t item) {
		(void)index;
		xpc_object_t one = xpc_get_type(item) == XPC_TYPE_DICTIONARY ? handle_one(caller, item, true, budget) : xpc_null_create();
		xpc_array_append_value(replies, one);
		xpc_release(one);
		return true;
	});
	xpc_dictionary_set_value(reply, KEY_MESSAGES, replies);
	xpc_release(replies);
}

// [real-Mac] the triple; the state is the value of the layer's slot in the shared region
static void reply_slot(xpc_object_t reply, const char* path) {
	int64_t index = slot_index_for(path);
	xpc_dictionary_set_string(reply, KEY_SHMEM_NAME, shmem_name);
	xpc_dictionary_set_int64(reply, KEY_SHMEM_INDEX, index);
	xpc_dictionary_set_uint64(reply, KEY_SHMEM_STATE, slot_value(index));
}

static xpc_object_t handle_one(const caller_t* caller, xpc_object_t request, bool in_batch, size_t* budget) {
	xpc_object_t reply = xpc_dictionary_create(NULL, NULL, 0);
	if (!caller->verified) {
		reply_error(reply, "cfprefsd stand-in: the caller's identity could not be verified");
		return reply;
	}
	xpc_object_t operation = xpc_dictionary_get_value(request, KEY_OPERATION);
	if (operation == NULL || xpc_get_type(operation) != XPC_TYPE_INT64) {
		reply_error(reply, "cfprefsd stand-in: request without an int64 CFPreferencesOperation");
		return reply;
	}
	int64_t op = xpc_int64_get_value(operation);
	if (op == OP_BATCH) {
		if (in_batch) {
			reply_error(reply, "cfprefsd stand-in: a batch cannot contain a batch");
		} else {
			handle_batch(caller, request, reply, budget);
		}
		return reply;
	}
	if (op != OP_SLOT_OR_WRITE && op != OP_PATH) {
		reply_error(reply, "cfprefsd stand-in: operation not implemented");
		return reply;
	}
	char path[PREFS_PATH_MAX];
	if (!prefs_layer_path(request, caller->uid, path, sizeof(path))) {
		reply_error(reply, "cfprefsd stand-in: request does not name a valid preferences layer");
		return reply;
	}
	if (op == OP_PATH) {
		xpc_dictionary_set_string(reply, KEY_PATH, path);
		return reply;
	}
	if (xpc_dictionary_get_value(request, KEY_WRITE_KEY) != NULL) {
		// The any-user and managed layers are shared by every user: only a verified root may change them.
		if (prefs_layer_is_shared(request) && caller->uid != 0) {
			reply_slot(reply, path);
			reply_error(reply, "cfprefsd stand-in: only root may write the any-user and managed layers");
			return reply;
		}
		const char* failure = prefs_store_write(request, caller->uid, caller->gid, path, KEY_WRITE_KEY, KEY_WRITE_VALUE);
		if (failure != NULL) {
			daemon_log("write failed: %s", failure);
			reply_slot(reply, path);
			reply_error(reply, failure);
			return reply;
		}
		slot_bump(slot_index_for(path));
		reply_slot(reply, path);
		return reply;
	}
	// [real-Mac] a read: the triple plus the layer's dictionary as a bplist00 in xpc data, left out for a layer with no file
	reply_slot(reply, path);
	xpc_object_t plist = prefs_store_copy_layer(caller->uid, caller->gid, path, budget);
	if (plist != NULL) {
		xpc_dictionary_set_value(reply, KEY_PLIST, plist);
		xpc_release(plist);
	}
	return reply;
}

int main(void) {
	verbose = getenv(LOG_ENV) != NULL && strcmp(getenv(LOG_ENV), "0") != 0;
	// launchd's stdout/stderr redirection is unreliable in the prefix, so own the log file (as the libxpc test service does)
	freopen(LOG_PATH, "a", stderr);
	if (!shmem_create()) {
		return 1; // fail loud: a daemon without a trustworthy region must not answer
	}
	daemon_log("started as euid %u egid %u", (unsigned)geteuid(), (unsigned)getegid());

	// One serial queue: writes are read-modify-write on files and run under the caller's identity, which is process-wide.
	dispatch_queue_t queue = dispatch_queue_create("org.darlinghq.cfprefsd.requests", DISPATCH_QUEUE_SERIAL);
	xpc_connection_t server = xpc_connection_create_mach_service(SERVICE_NAME, queue, XPC_CONNECTION_MACH_SERVICE_LISTENER);
	if (server == NULL) {
		daemon_log("could not create the listener for " SERVICE_NAME);
		return 1;
	}
	xpc_connection_set_event_handler(server, ^(xpc_object_t event) {
		if (xpc_get_type(event) == XPC_TYPE_CONNECTION) {
			xpc_connection_t connection = event;
			xpc_connection_set_target_queue(connection, queue);
			xpc_connection_set_event_handler(connection, ^(xpc_object_t message) {
				if (xpc_get_type(message) != XPC_TYPE_DICTIONARY) return;
				xpc_object_t reply = xpc_dictionary_create_reply(message);
				if (reply == NULL) return; // a send-only message: nobody is waiting
				caller_t caller;
				caller.uid = xpc_connection_get_euid(connection);
				caller.gid = xpc_connection_get_egid(connection);
				caller.pid = xpc_connection_get_pid(connection);
				caller.verified = credentials_present(caller.pid, caller.uid, caller.gid);
				if (verbose) log_request(caller.uid, message, caller.verified ? "request" : "unverified request");
				size_t budget = REPLY_BYTE_BUDGET;
				xpc_object_t answer = handle_one(&caller, message, false, &budget);
				xpc_dictionary_apply(answer, ^bool(const char* key, xpc_object_t value) {
					xpc_dictionary_set_value(reply, key, value);
					return true;
				});
				xpc_release(answer);
				if (xpc_dictionary_get_bool(message, KEY_WHOAMI)) {
					// Darling-only diagnostic, never sent by a real client: the identity this daemon holds for the caller.
					xpc_dictionary_set_int64(reply, "darling-caller-uid", (int64_t)caller.uid);
					xpc_dictionary_set_int64(reply, "darling-caller-gid", (int64_t)caller.gid);
					xpc_dictionary_set_int64(reply, "darling-caller-pid", (int64_t)caller.pid);
					// the ids this process held in its last file work for a caller, and its own now (a test checks they differ)
					uid_t work_uid, work_gid;
					prefs_store_last_work_ids(&work_uid, &work_gid);
					xpc_dictionary_set_int64(reply, "darling-work-uid", (int64_t)work_uid);
					xpc_dictionary_set_int64(reply, "darling-work-gid", (int64_t)work_gid);
					xpc_dictionary_set_int64(reply, "darling-daemon-uid", (int64_t)geteuid());
				}
				xpc_connection_send_message(connection, reply);
				xpc_release(reply);
			});
			xpc_connection_resume(connection);
		} else if (event == XPC_ERROR_CONNECTION_INVALID) {
			daemon_log("listener invalidated, exiting");
			exit(0);
		}
	});
	xpc_connection_resume(server);
	dispatch_main();
}
