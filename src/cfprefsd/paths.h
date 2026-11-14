#ifndef CFPREFSD_PATHS_H
#define CFPREFSD_PATHS_H

#include <stdbool.h>
#include <stddef.h>
#include <sys/types.h>
#include <xpc/xpc.h>

#define PREFS_PATH_MAX 1024

// Writes the plist path of the layer a request names (domain, user or any user, by-host, managed) into out.
// False when the request has no usable domain (missing, empty, "." / "..", or containing '/').
bool prefs_layer_path(xpc_object_t request, uid_t uid, char* out, size_t size);

// True for the layers every user shares: the any-user layer (no CFPreferencesUser key) and the managed layer.
bool prefs_layer_is_shared(xpc_object_t request);

#endif
