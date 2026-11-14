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

// The reply to acquireAssertionWithDescriptor:error:. Layout as observed on macOS 26.1 with our own client program (probe
// source in the pull request description): return-value is a dictionary of class RBSAssertionIdentifier with clientPid,
// serverPid and count, and no error key. The request is not inspected: nothing in the observed request changes the reply.
//
// count is a global counter that rose by one per acquire in the observation. Its starting value is not meaningful here
// (GUESS: 1 for the first acquire after the daemon starts). The daemon keeps no assertion state: nothing in Darling
// suspends or terminates a process, so there is nothing for an assertion to hold back.

#include "acquire.h"

#include <unistd.h>

static int64_t acquire_count = 0;

xpc_object_t acquire_response_create(xpc_connection_t caller) {
	xpc_object_t identifier = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(identifier, "bsx_class", "RBSAssertionIdentifier");
	xpc_dictionary_set_int64(identifier, "clientPid", xpc_connection_get_pid(caller));
	xpc_dictionary_set_int64(identifier, "serverPid", getpid());
	xpc_dictionary_set_int64(identifier, "count", __atomic_add_fetch(&acquire_count, 1, __ATOMIC_RELAXED));
	return identifier;
}
