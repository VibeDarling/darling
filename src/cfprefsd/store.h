#ifndef CFPREFSD_STORE_H
#define CFPREFSD_STORE_H

#include <sys/types.h>
#include <xpc/xpc.h>

// Applies the write a request carries (a string key and an optional value; no value, or null, removes the key) to the plist file at
// path, as the requesting user. Returns NULL on success or a static, explicit failure text.
// The most bytes one layer's plist may have: what the daemon writes and what one reply may carry. A write that would exceed it is refused.
#define PREFS_MAX_LAYER_BYTES (8u * 1024 * 1024)

const char* prefs_store_write(xpc_object_t request, uid_t uid, gid_t gid, const char* path, const char* key_name, const char* value_name);

// The layer's current dictionary as xpc data holding a bplist00, read as the requesting user; NULL when the layer has no plist (absent,
// empty or unreadable) or when it does not fit in *budget, the number of bytes the current request may still put into its reply (the
// file size is checked before the file is parsed; delivered bytes are subtracted from *budget).
xpc_object_t prefs_store_copy_layer(uid_t uid, gid_t gid, const char* path, size_t* budget);

#endif
