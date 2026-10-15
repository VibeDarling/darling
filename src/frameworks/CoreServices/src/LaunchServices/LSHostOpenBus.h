/*
This file is part of Darling.

Copyright (C) 2026 Darling developers

Darling is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Darling is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
 * Hands a URL to the host desktop over the user's D-Bus session bus.
 *
 * This part has no Darling or CoreFoundation dependencies: every host
 * function comes from the table below, so it can also be built natively on
 * Linux against libsystemd for testing. Errors are negative Linux errno
 * values as returned by sd-bus.
 */

#ifndef LS_HOST_OPEN_BUS_H_
#define LS_HOST_OPEN_BUS_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LS_HOST_OPEN_MAX_URL_LENGTH 4096

/* Linux errno values; the guest's errno numbering differs. */
#define LS_HOST_LINUX_ENOENT 2
#define LS_HOST_LINUX_EINVAL 22
#define LS_HOST_LINUX_ENOSYS 38
#define LS_HOST_LINUX_ETIMEDOUT 110

/* Layout of sd_bus_error. */
struct ls_host_bus_error
{
	const char* name;
	const char* message;
	int _need_free;
};

struct ls_host_api
{
	/* libsystemd (sd-bus); bus and message objects are opaque */
	int (*sd_bus_new)(void** ret);
	int (*sd_bus_set_address)(void* bus, const char* address);
	int (*sd_bus_set_bus_client)(void* bus, int b);
	int (*sd_bus_start)(void* bus);
	void* (*sd_bus_flush_close_unref)(void* bus);
	int (*sd_bus_message_new_method_call)(void* bus, void** m, const char* destination,
		const char* path, const char* interface, const char* member);
	int (*sd_bus_message_append)(void* m, const char* types, ...);
	int (*sd_bus_message_append_strv)(void* m, char** l);
	int (*sd_bus_message_open_container)(void* m, char type, const char* contents);
	int (*sd_bus_message_close_container)(void* m);
	int (*sd_bus_call)(void* bus, void* m, uint64_t usec, struct ls_host_bus_error* ret_error, void** reply);
	void* (*sd_bus_message_unref)(void* m);
	void (*sd_bus_error_free)(struct ls_host_bus_error* e);

	/* Host process environment */
	char* (*getenv)(const char* name);
	unsigned int (*getuid)(void);
	int (*access)(const char* path, int mode);

	/* Parent of the per-user runtime directories, normally "/run/user" */
	const char* runtime_dir_root;
	/* Per-call timeout; 0 selects the default */
	uint64_t timeout_usec;
};

enum
{
	LS_HOST_OPEN_VIA_PORTAL = 1,
	LS_HOST_OPEN_VIA_SYSTEMD = 2,
};

/* 1 if the URL has a scheme that is handed to the host (http, https, mailto). */
int _LSHostOpenSchemeSupported(const char* url);

/* 0 if the URL may be handed to the host, otherwise -EINVAL. */
int _LSHostOpenValidateURL(const char* url);

/* Host path of xdg-open, or NULL if it is not in the usual locations. */
const char* _LSHostOpenFindOpener(const struct ls_host_api* api);

/*
 * Opens the URL through org.freedesktop.portal.OpenURI, or, if that fails,
 * runs xdg-open in a transient systemd user service. Either way the handler
 * is started by the host session, never as a child of the caller.
 * Returns 0 and stores the method used in *method (may be NULL), or a
 * negative errno.
 */
int _LSHostOpenURL(const struct ls_host_api* api, const char* url, int* method);

#ifdef __cplusplus
}
#endif

#endif
