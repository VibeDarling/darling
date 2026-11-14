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

// The reply to handshakeWithRequest:. Layout (every key, type and nesting) as observed on macOS 26.1 with our own client
// program, which sent the same request and recorded the reply. The probe source is in the pull request description.
//
// The caller's own pid and audit uid are filled in from the XPC connection, Darling-side. The success and fail arrays
// are empty, as observed. What the observation could not show is marked GUESS.

#include "handshake.h"

#include <libproc.h>
#include <mach/message.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>

// declared in xpc/private.h, which the plain C build of this daemon does not include
void xpc_connection_get_audit_token(xpc_connection_t connection, audit_token_t* token);

static xpc_object_t class_only(const char* name) {
	xpc_object_t dictionary = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(dictionary, "bsx_class", name);
	return dictionary;
}

static void set_and_release(xpc_object_t dictionary, const char* key, xpc_object_t value) {
	xpc_dictionary_set_value(dictionary, key, value);
	xpc_release(value);
}

xpc_object_t handshake_response_create(xpc_connection_t caller) {
	audit_token_t token;
	memset(&token, 0, sizeof(token));
	xpc_connection_get_audit_token(caller, &token);
	pid_t pid = xpc_connection_get_pid(caller);
	// The audit token's first value is the audit user id. Darling does not fill it (observed: 0 for a non-root caller), and
	// -1 means "none", so both fall back to the connection's effective uid. GUESS: on a login session the two are equal.
	uid_t euid = xpc_connection_get_euid(caller);
	uid_t auid = (uid_t)token.val[0];
	if (auid == (uid_t)-1 || (auid == 0 && euid != 0)) {
		auid = euid;
	}

	// Observed description of an unbundled command-line caller: "anon<darling_probe>(501)", process name then audit uid.
	// Under Darling the process name is the kernel's name for the guest process (the loader's, "mldr").
	char name[64] = "unknown";
	proc_name(pid, name, sizeof(name));
	char description[160];
	snprintf(description, sizeof(description), "anon<%s>(%u)", name, (unsigned)auid);

	xpc_object_t identity = class_only("RBSOpaqueProcessIdentity");
	xpc_dictionary_set_int64(identity, "_pid", pid);
	xpc_dictionary_set_int64(identity, "_auid", auid);
	xpc_dictionary_set_string(identity, "_description", description);

	xpc_object_t coded = xpc_dictionary_create(NULL, NULL, 0);
	set_and_release(coded, "_identity", identity);
	xpc_dictionary_set_uint64(coded, "_pid", (uint64_t)pid);
	set_and_release(coded, "_bundle", class_only("RBSProcessBundle"));
	// The observed reply also carries bsx_archive (data), _data (uint64) and a decimal bsx_index whose values mean nothing
	// to this daemon. Measured with Stocks: the client aborts with "Decoded object class __NSDictionaryI does not match
	// expected class BSAuditToken" unless _bsAuditToken.bsx_index is present, and then accepts any string; bsx_archive and
	// _data may be left out. GUESS: bsx_index "0".
	xpc_object_t audit_token_dictionary = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(audit_token_dictionary, "bsx_index", "0");
	set_and_release(coded, "_bsAuditToken", audit_token_dictionary);

	xpc_object_t handle = class_only("RBSProcessHandle");
	set_and_release(handle, "_codedHandle", coded);

	xpc_object_t response = class_only("RBSHandshakeResponse");
	static const char* const empty_arrays[] = { "success-keys", "success-values", "fail-keys", "fail-values" };
	for (size_t i = 0; i < sizeof(empty_arrays) / sizeof(empty_arrays[0]); ++i) {
		set_and_release(response, empty_arrays[i], xpc_array_create(NULL, 0));
	}
	set_and_release(response, "_handle", handle);
	return response;
}
