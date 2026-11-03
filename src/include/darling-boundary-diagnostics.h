#ifndef DARLING_BOUNDARY_DIAGNOSTICS_H
#define DARLING_BOUNDARY_DIAGNOSTICS_H

#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

enum darling_boundary_event {
    DARLING_DIAG_READY,
    DARLING_DIAG_CONTAINER_INIT_ENTER,
    DARLING_DIAG_CONTAINER_INIT_OK,
    DARLING_DIAG_CONTAINER_INIT_MODEL_ERROR,
    DARLING_DIAG_CONTAINER_LOAD_ENTER,
    DARLING_DIAG_CONTAINER_LOAD_SUCCESS,
    DARLING_DIAG_CONTAINER_LOAD_ERROR,
    DARLING_DIAG_DESCRIPTION_INIT_ENTER,
    DARLING_DIAG_DESCRIPTION_INIT_OK,
};

static inline void darling_diagnostic_send(const char *endpoint, const char *record, size_t length) {
    int saved_errno = errno, descriptor = -1, flags;
    char parent[81];
    size_t size = 0, last_slash = 0, component = 1;
    struct stat metadata;
    struct sockaddr_un address;
    if (!endpoint || endpoint[0] != '/' || length > 1024)
        goto done;
    while (size < 81 && endpoint[size])
        size++;
    if (size < 2 || size > 80 || size >= sizeof(address.sun_path))
        goto done;
    for (size_t index = 1; index <= size; index++) {
        if (endpoint[index] == '/' || index == size) {
            size_t count = index - component;
            if (!count || (count == 1 && endpoint[component] == '.') ||
                (count == 2 && endpoint[component] == '.' && endpoint[component + 1] == '.'))
                goto done;
            if (index < size)
                last_slash = index;
            component = index + 1;
        }
    }
    if (!last_slash || getuid() != geteuid() || getgid() != getegid())
        goto done;
    if (lstat(endpoint, &metadata) || !S_ISSOCK(metadata.st_mode) || metadata.st_uid != geteuid())
        goto done;
    memcpy(parent, endpoint, last_slash);
    parent[last_slash] = 0;
    if (lstat(parent, &metadata) || !S_ISDIR(metadata.st_mode) ||
        metadata.st_uid != geteuid() || (metadata.st_mode & 0077))
        goto done;
    descriptor = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (descriptor < 0)
        goto done;
    flags = fcntl(descriptor, F_GETFL, 0);
    if (flags < 0 || fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) < 0 ||
        fcntl(descriptor, F_SETFD, FD_CLOEXEC) < 0)
        goto done;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
#ifdef __APPLE__
    address.sun_len = sizeof(address);
#endif
    memcpy(address.sun_path, endpoint, size + 1);
    sendto(descriptor, record, length, MSG_DONTWAIT | MSG_NOSIGNAL,
           (struct sockaddr *)&address, sizeof(address));
done:
    if (descriptor >= 0)
        close(descriptor);
    errno = saved_errno;
}

static inline void darling_boundary_emit(const char *endpoint, enum darling_boundary_event event) {
    static const char *const records[] = {
        "diag.ready\n",
        "coredata.container.init.enter\n",
        "coredata.container.init.ok\n",
        "coredata.container.init.model-error\n",
        "coredata.container.load.enter\n",
        "coredata.container.load.success\n",
        "coredata.container.load.error\n",
        "coredata.store-description.init.enter\n",
        "coredata.store-description.init.ok\n",
    };
    if ((unsigned)event < sizeof(records) / sizeof(records[0]))
        darling_diagnostic_send(endpoint, records[event], strlen(records[event]));
}

static inline void darling_missing_import_emit(const char *endpoint, const char *name) {
    char record[256] = "missing-import:";
    size_t size = 0;
    if (!endpoint || !name)
        return;
    while (size < 201 && name[size]) {
        unsigned char c = (unsigned char)name[size];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '_' || c == '.' || c == '$'))
            return;
        size++;
    }
    if (!size || size > 200)
        return;
    memcpy(record + 15, name, size);
    record[15 + size] = '\n';
    darling_diagnostic_send(endpoint, record, 16 + size);
}

#endif
