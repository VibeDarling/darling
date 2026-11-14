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

// The com.apple.runningboard Mach service, as far as Darling needs it.
//
// Darling has no process-lifecycle management (no suspension, no jetsam-style policy), so the service has nothing to grant
// or enforce. It owns the Mach service name so the launchd lookup succeeds, accepts connections, and answers:
//   - handshakeWithRequest: and acquireAssertionWithDescriptor:error: with replies laid out as observed on macOS 26.1
//     (handshake.c, acquire.c);
//   - every other operation with an explicit error reply (a dictionary with a darling-error string), never silence.
// launchd starts the daemon on the first contact (the plist has no RunAtLoad), so processes that never use the service
// never start it. The daemon keeps no per-client state.
//
// Logging: /var/log/runningboardd.log (launchd's own redirection is unreliable in the prefix). Each operation name that
// gets the error reply is logged, the first 16 times; unexpected events are logged. Nothing else is.

#include <dispatch/dispatch.h>
#include <xpc/xpc.h>
#include <xpc/connection.h>

#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#include "acquire.h"
#include "handshake.h"

#define SERVICE_NAME "com.apple.runningboard"
#define LOG_PATH "/var/log/runningboardd.log"
#define SELECTOR_KEY "rbs_selector"
#define ERROR_REPLY_KEY "darling-error"
#define UNIMPLEMENTED_LOG_LIMIT 16

static unsigned unimplemented_logged = 0;

static void rb_log(const char* format, ...) __attribute__((format(printf, 1, 2)));
static void rb_log(const char* format, ...) {
	char line[512];
	va_list args;
	va_start(args, format);
	vsnprintf(line, sizeof(line), format, args);
	va_end(args);
	struct timeval now;
	gettimeofday(&now, NULL);
	// one fprintf per line so concurrent connection handlers do not interleave
	fprintf(stderr, "%lld.%03d runningboardd: %s\n", (long long)now.tv_sec, (int)(now.tv_usec / 1000), line);
	fflush(stderr);
}

// The operation name is peer-controlled: cap its length and keep identifier characters only.
static void log_unimplemented(xpc_connection_t connection, const char* selector) {
	unsigned seen = __atomic_add_fetch(&unimplemented_logged, 1, __ATOMIC_RELAXED);
	if (seen > UNIMPLEMENTED_LOG_LIMIT) {
		return;
	}
	char clean[97];
	size_t i = 0;
	for (; selector != NULL && selector[i] != '\0' && i < sizeof(clean) - 1; ++i) {
		char c = selector[i];
		clean[i] = (isalnum((unsigned char)c) || c == '_' || c == ':' || c == '.' || c == '$') ? c : '?';
	}
	clean[i] = '\0';
	rb_log("pid %d: unimplemented operation '%s', answered with an error reply%s", (int)xpc_connection_get_pid(connection),
		selector != NULL ? clean : "(no rbs_selector)", seen == UNIMPLEMENTED_LOG_LIMIT ? "; further ones are not logged" : "");
}

static void reply_to(xpc_connection_t connection, xpc_object_t message) {
	xpc_object_t reply = xpc_dictionary_create_reply(message);
	if (reply == NULL) {
		// a send-only message (the client's opening empty dictionary): nobody is waiting for an answer
		return;
	}

	const char* selector = xpc_dictionary_get_string(message, SELECTOR_KEY);
	xpc_object_t value = NULL;
	if (selector != NULL && strcmp(selector, HANDSHAKE_SELECTOR) == 0) {
		value = handshake_response_create(connection);
	} else if (selector != NULL && strcmp(selector, ACQUIRE_SELECTOR) == 0) {
		value = acquire_response_create(connection);
	}

	if (value != NULL) {
		xpc_dictionary_set_value(reply, "return-value", value);
		xpc_release(value);
	} else {
		log_unimplemented(connection, selector);
		xpc_dictionary_set_string(reply, ERROR_REPLY_KEY, "runningboardd stand-in: operation not implemented");
	}
	xpc_connection_send_message(connection, reply);
	xpc_release(reply);
}

static void handle_peer_event(xpc_connection_t connection, xpc_object_t event) {
	xpc_type_t type = xpc_get_type(event);
	if (type == XPC_TYPE_DICTIONARY) {
		reply_to(connection, event);
	} else if (type != XPC_TYPE_ERROR) {
		rb_log("pid %d: unexpected non-dictionary event, ignored", (int)xpc_connection_get_pid(connection));
	}
	// connection errors (the peer went away) need no action: the daemon keeps no per-client state
}

int main(void) {
	freopen(LOG_PATH, "a", stderr);

	dispatch_queue_t queue = dispatch_queue_create("org.darlinghq.runningboardd.connections", DISPATCH_QUEUE_CONCURRENT);
	xpc_connection_t server = xpc_connection_create_mach_service(SERVICE_NAME, queue, XPC_CONNECTION_MACH_SERVICE_LISTENER);
	if (server == NULL) {
		rb_log("could not create the listener for " SERVICE_NAME);
		return 1;
	}

	xpc_connection_set_event_handler(server, ^(xpc_object_t event) {
		if (xpc_get_type(event) == XPC_TYPE_CONNECTION) {
			xpc_connection_t peer = event;
			xpc_connection_set_target_queue(peer, queue);
			xpc_connection_set_event_handler(peer, ^(xpc_object_t peer_event) {
				handle_peer_event(peer, peer_event);
			});
			xpc_connection_resume(peer);
		} else if (event == XPC_ERROR_CONNECTION_INVALID) {
			// the service name is gone (launchd shutting down): nothing left to serve
			rb_log("listener invalidated, exiting");
			exit(0);
		} else {
			rb_log("unexpected event on the listener, ignored");
		}
	});
	xpc_connection_resume(server);

	dispatch_main();
}
