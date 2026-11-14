#ifndef CFPREFSD_STORE_H
#define CFPREFSD_STORE_H

#include <sys/types.h>
#include <xpc/xpc.h>

// Applies the write a request carries (a string key and an optional value; no value, or null, removes the key) to the plist file at
// path, as the requesting user. Returns NULL on success or a static, explicit failure text.
const char* prefs_store_write(xpc_object_t request, uid_t uid, gid_t gid, const char* path, const char* key_name, const char* value_name);

#endif
