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

// Guest test for the com.apple.runningboard service. Checks that the service is registered with launchd, answers the
// handshake and acquire requests with every field of the observed reply layout and this process as the caller, and
// answers any other operation with an explicit error reply instead of leaving the caller waiting.
//
// The caller's audit uid: Darling's XPC audit token carries 0 for a non-root caller, and the daemon falls back to the
// effective uid. That path only runs for a non-root caller, so the test insists on one (the guest runs as the invoking
// user; as root the fallback is not exercised and the test fails to say so).
//
// On a prefix without the daemon the lookup fails (bootstrap_look_up returns 1102) and every request below fails.

#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <xpc/xpc.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures = 0;

#define CHECK(condition, ...) do { if (!(condition)) { fprintf(stderr, "FAIL: " __VA_ARGS__); fputc('\n', stderr); ++failures; } } while (0)

static xpc_object_t member(xpc_object_t dictionary, const char* key, xpc_type_t type, const char* where) {
	xpc_object_t value = (dictionary != NULL && xpc_get_type(dictionary) == XPC_TYPE_DICTIONARY) ? xpc_dictionary_get_value(dictionary, key) : NULL;
	if (value == NULL || xpc_get_type(value) != type) {
		fprintf(stderr, "FAIL: %s.%s is missing or has the wrong type\n", where, key);
		++failures;
		return NULL;
	}
	return value;
}

static void check_class(xpc_object_t dictionary, const char* expected, const char* where) {
	xpc_object_t value = member(dictionary, "bsx_class", XPC_TYPE_STRING, where);
	if (value != NULL) {
		CHECK(strcmp(xpc_string_get_string_ptr(value), expected) == 0, "%s.bsx_class is '%s', expected '%s'", where, xpc_string_get_string_ptr(value), expected);
	}
}

static void check_empty_array(xpc_object_t dictionary, const char* key, const char* where) {
	xpc_object_t value = member(dictionary, key, XPC_TYPE_ARRAY, where);
	if (value != NULL) {
		CHECK(xpc_array_get_count(value) == 0, "%s.%s is not empty", where, key);
	}
}

static xpc_object_t ask(xpc_connection_t connection, const char* selector) {
	xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
	if (selector != NULL) {
		xpc_dictionary_set_string(request, "rbs_selector", selector);
	}
	xpc_object_t argument = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(argument, "bsx_class", "RBSRequestForTest");
	xpc_dictionary_set_value(request, "rbs_argument_0", argument);
	xpc_release(argument);
	xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, request);
	xpc_release(request);
	return reply;
}

static void check_error_reply(xpc_object_t reply, const char* what) {
	CHECK(xpc_get_type(reply) == XPC_TYPE_DICTIONARY, "%s: reply is not a dictionary", what);
	if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY) {
		CHECK(xpc_dictionary_get_string(reply, "darling-error") != NULL, "%s: reply has no darling-error string", what);
		CHECK(xpc_dictionary_get_value(reply, "return-value") == NULL, "%s: error reply carries a return-value", what);
	}
}

static int64_t check_acquire(xpc_connection_t connection, const char* where) {
	xpc_object_t reply = ask(connection, "acquireAssertionWithDescriptor:error:");
	int64_t count = 0;
	CHECK(xpc_get_type(reply) == XPC_TYPE_DICTIONARY, "%s: reply is not a dictionary", where);
	if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY) {
		CHECK(xpc_dictionary_get_value(reply, "darling-error") == NULL, "%s: reply carries an error", where);
		xpc_object_t identifier = member(reply, "return-value", XPC_TYPE_DICTIONARY, where);
		if (identifier != NULL) {
			check_class(identifier, "RBSAssertionIdentifier", "acquire.return-value");
			xpc_object_t client = member(identifier, "clientPid", XPC_TYPE_INT64, "acquire.return-value");
			xpc_object_t server = member(identifier, "serverPid", XPC_TYPE_INT64, "acquire.return-value");
			xpc_object_t counter = member(identifier, "count", XPC_TYPE_INT64, "acquire.return-value");
			CHECK(client == NULL || xpc_int64_get_value(client) == getpid(), "acquire.clientPid is not the caller");
			CHECK(server == NULL || (xpc_int64_get_value(server) > 0 && xpc_int64_get_value(server) != getpid()), "acquire.serverPid is not another process");
			if (counter != NULL) count = xpc_int64_get_value(counter);
		}
	}
	xpc_release(reply);
	return count;
}

int main(void) {
	CHECK(getuid() != 0, "run as a non-root user: the audit-uid fallback is only exercised for a non-root caller");

	mach_port_t port = MACH_PORT_NULL;
	kern_return_t status = bootstrap_look_up(bootstrap_port, "com.apple.runningboard", &port);
	CHECK(status == KERN_SUCCESS, "bootstrap_look_up(com.apple.runningboard) returned %d", status);

	// a watchdog turns a silent hang into a failure
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(0, 0), ^{
		fprintf(stderr, "FAIL: no reply from com.apple.runningboard within 30 seconds\n");
		_exit(1);
	});

	xpc_connection_t connection = xpc_connection_create_mach_service("com.apple.runningboard", NULL, 0);
	xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
		(void)event;
	});
	xpc_connection_resume(connection);

	// the client's opening message: an empty dictionary that expects no reply
	xpc_object_t hello = xpc_dictionary_create(NULL, NULL, 0);
	xpc_connection_send_message(connection, hello);
	xpc_release(hello);

	// any other operation, and a request without an operation name: explicit error reply, twice on one connection
	xpc_object_t unknown = ask(connection, "noSuchOperation:");
	check_error_reply(unknown, "unknown selector");
	xpc_release(unknown);
	xpc_object_t nameless = ask(connection, NULL);
	check_error_reply(nameless, "no selector");
	xpc_release(nameless);

	// handshake: every field of the observed layout, with this process as the caller
	xpc_object_t reply = ask(connection, "handshakeWithRequest:");
	CHECK(xpc_get_type(reply) == XPC_TYPE_DICTIONARY, "handshake: reply is not a dictionary");
	CHECK(xpc_get_type(reply) != XPC_TYPE_DICTIONARY || xpc_dictionary_get_value(reply, "darling-error") == NULL, "handshake: reply carries an error");
	xpc_object_t response = member(reply, "return-value", XPC_TYPE_DICTIONARY, "handshake");
	if (response != NULL) {
		check_class(response, "RBSHandshakeResponse", "handshake.return-value");
		check_empty_array(response, "success-keys", "handshake.return-value");
		check_empty_array(response, "success-values", "handshake.return-value");
		check_empty_array(response, "fail-keys", "handshake.return-value");
		check_empty_array(response, "fail-values", "handshake.return-value");
		xpc_object_t handle = member(response, "_handle", XPC_TYPE_DICTIONARY, "handshake.return-value");
		check_class(handle, "RBSProcessHandle", "_handle");
		xpc_object_t coded = member(handle, "_codedHandle", XPC_TYPE_DICTIONARY, "_handle");
		xpc_object_t identity = member(coded, "_identity", XPC_TYPE_DICTIONARY, "_codedHandle");
		check_class(identity, "RBSOpaqueProcessIdentity", "_identity");
		xpc_object_t identity_pid = member(identity, "_pid", XPC_TYPE_INT64, "_identity");
		xpc_object_t identity_auid = member(identity, "_auid", XPC_TYPE_INT64, "_identity");
		xpc_object_t description = member(identity, "_description", XPC_TYPE_STRING, "_identity");
		CHECK(identity_pid == NULL || xpc_int64_get_value(identity_pid) == getpid(), "_identity._pid is not the caller");
		CHECK(identity_auid == NULL || xpc_int64_get_value(identity_auid) == (int64_t)getuid(), "_identity._auid is not the caller's uid");
		if (description != NULL) {
			char suffix[32];
			snprintf(suffix, sizeof(suffix), ">(%u)", (unsigned)getuid());
			const char* text = xpc_string_get_string_ptr(description);
			size_t length = strlen(text), suffix_length = strlen(suffix);
			CHECK(strncmp(text, "anon<", 5) == 0 && length >= 5 + suffix_length && strcmp(text + length - suffix_length, suffix) == 0,
				"_identity._description '%s' is not anon<name>(uid)", text);
		}
		xpc_object_t coded_pid = member(coded, "_pid", XPC_TYPE_UINT64, "_codedHandle");
		CHECK(coded_pid == NULL || xpc_uint64_get_value(coded_pid) == (uint64_t)getpid(), "_codedHandle._pid is not the caller");
		xpc_object_t audit_token = member(coded, "_bsAuditToken", XPC_TYPE_DICTIONARY, "_codedHandle");
		xpc_object_t index = member(audit_token, "bsx_index", XPC_TYPE_STRING, "_bsAuditToken");
		CHECK(index == NULL || xpc_string_get_length(index) > 0, "_bsAuditToken.bsx_index is empty");
		xpc_object_t bundle = member(coded, "_bundle", XPC_TYPE_DICTIONARY, "_codedHandle");
		check_class(bundle, "RBSProcessBundle", "_bundle");
	}
	xpc_release(reply);

	// acquire: the global counter rises by one per call
	int64_t first = check_acquire(connection, "first acquire");
	int64_t second = check_acquire(connection, "second acquire");
	CHECK(first > 0 && second == first + 1, "acquire count must rise by one per call (got %lld then %lld)", (long long)first, (long long)second);

	if (failures == 0) {
		printf("PASS: com.apple.runningboard is registered, answers handshake and acquire with the observed layout, and answers other operations with an error reply\n");
	}
	return failures ? 1 : 0;
}
