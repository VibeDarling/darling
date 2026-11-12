#if defined(__ANDROID__)
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
static const char* _darling_get_shm_dir(void) {
	// A host directory: TMPDIR may be the guest's.
	const char* dir = getenv("DARLING_SHM_DIR");
	if (dir && dir[0]) return dir;
	const char* tmp = getenv("TMPDIR");
	if (tmp && tmp[0]) return tmp;
	const char* pfx = getenv("TERMUX_PREFIX");
	if (!pfx || !pfx[0]) pfx = getenv("PREFIX");
#ifdef TERMUX_PREFIX
	if (!pfx || !pfx[0]) pfx = TERMUX_PREFIX;
#endif
	if (pfx && pfx[0]) {
		static char buf[PATH_MAX];
		snprintf(buf, sizeof(buf), "%s/tmp", pfx);
		if (access(buf, W_OK) == 0)
			return buf;
	}
	return "/tmp";
}
static int shm_open(const char *name, int oflag, mode_t mode) {
	char path[PATH_MAX];
	if (name[0] == '/') name++;
	snprintf(path, sizeof(path), "%s/shm-%s", _darling_get_shm_dir(), name);
	return open(path, oflag | O_CLOEXEC, mode);
}
static int shm_unlink(const char *name) {
	char path[PATH_MAX];
	if (name[0] == '/') name++;
	snprintf(path, sizeof(path), "%s/shm-%s", _darling_get_shm_dir(), name);
	return unlink(path);
}
#endif
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/mman.h>
#include <semaphore.h>
#include <locale.h>
#include <unistd.h>
#include "elfcalls.h"
#include "threads.h"
#include <sys/un.h>
#include <sys/socket.h>
#include <fcntl.h>

#include <darlingserver/rpc.h>

#if defined(__ANDROID__)
#include <sys/auxv.h>
static const char* getenvTrusted(const char* name)
{
#if defined(AT_SECURE)
	if (getauxval(AT_SECURE))
		return NULL;
#endif
	return getenv(name);
}
#endif

static void* dlopen_simple(const char* name)
{
	if (!name)
		return NULL;

	void* rv = dlopen(name, RTLD_LAZY);
	if (rv)
		return rv;

	char unversioned[512] = {0};
	bool has_unversioned = false;
	const char* so = strstr(name, ".so.");
	if (so)
	{
		size_t base_len = (size_t)(so - name) + 3;
		if (base_len < sizeof(unversioned))
		{
			memcpy(unversioned, name, base_len);
			unversioned[base_len] = '\0';
			has_unversioned = true;
			rv = dlopen(unversioned, RTLD_LAZY);
			if (rv)
				return rv;
		}
	}

#if defined(__ANDROID__)
	const char* pfx = getenvTrusted("TERMUX_PREFIX");
	if (!pfx || !pfx[0]) pfx = getenvTrusted("PREFIX");
	if (!pfx || !pfx[0]) pfx = "/data/data/com.termux/files/usr";

	// If name contains directories, take the basename so we don't produce e.g. /data/.../lib//usr/lib/...
	const char* fname = strrchr(name, '/');
	fname = fname ? fname + 1 : name;

	char path[1024];
	snprintf(path, sizeof(path), "%s/lib/%s", pfx, fname);
	rv = dlopen(path, RTLD_LAZY);
	if (rv)
		return rv;

	if (has_unversioned)
	{
		const char* ufname = strrchr(unversioned, '/');
		ufname = ufname ? ufname + 1 : unversioned;

		snprintf(path, sizeof(path), "%s/lib/%s", pfx, ufname);
		rv = dlopen(path, RTLD_LAZY);
		if (rv)
			return rv;

		// The APK ships its own copies under plain names: libpng16.so is libpng.so there.
		size_t len = strlen(unversioned) - 3;
		size_t end = len;
		while (end > 0 && unversioned[end - 1] >= '0' && unversioned[end - 1] <= '9')
			end--;
		if (end < len && end > 0 && unversioned[end - 1] != '/')
		{
			memcpy(unversioned + end, ".so", 4);
			rv = dlopen(unversioned, RTLD_LAZY);
			if (rv)
				return rv;
		}
	}
#endif

	return NULL;
}

static void* dlopen_fatal(const char* name)
{
	void* rv = dlopen_simple(name);
	if (!rv)
	{
		fprintf(stderr, "Cannot load %s (ELF): %s\n", name, dlerror());
		abort();
	}
	return rv;
}

static void* dlsym_fatal(void* handle, const char* sym)
{
	void* addr = dlsym(handle, sym);
	if (!addr)
	{
		fprintf(stderr, "Failed to lookup symbol %s (ELF): %s\n", sym, dlerror());
		abort();
	}
	return addr;
}

static int dlclose_fatal(void* handle)
{
	if (dlclose(handle) != 0)
	{
		fprintf(stderr, "Cannot dlclose library (ELF): %s\n", dlerror());
		abort();
	}
	return 0;
}

static int get_errno(void)
{
	return errno;
}

extern struct sockaddr_un __dserver_socket_address_data[];

static const void* __dserver_socket_address(void) {
	return &__dserver_socket_address_data;
};

extern void __mldr_close_rpc_socket(int socket);

extern int __mldr_create_process_lifetime_pipe(int* fds);
extern void __mldr_close_process_lifetime_pipe(int fd);
extern int __dserver_process_lifetime_pipe_fd;

static int __dserver_get_process_lifetime_pipe() {
	return __dserver_process_lifetime_pipe_fd;
}

static int __dserver_process_lifetime_pipe_refresh() {
	int pipe[2];

	if (__mldr_create_process_lifetime_pipe(pipe) == -1) {
		fprintf(stderr, "Failed to create process lifetime pipe: %d (%s)\n", errno, strerror(errno));
		abort();
	}

	__dserver_process_lifetime_pipe_fd = pipe[1];
	return pipe[0];
}

extern void __mldr_socket_bitmap_postfork_child(void);
extern void __mldr_socket_bitmap_prefork(void);
extern void __mldr_socket_bitmap_postfork_parent(void);

static int native_fork(void)
{
	__mldr_socket_bitmap_prefork();
	int result = fork();
	int saved_errno = errno;
	if (result == 0) {
		__mldr_thread_postfork_child();
		__mldr_socket_bitmap_postfork_child();
	} else {
		__mldr_socket_bitmap_postfork_parent();
	}
	/* Preserve fork's errno even if lock cleanup changes it. */
	return result < 0 ? -saved_errno : result;
}

static void arm64_thread_bridge_postfork_complete(void)
{
	/* Legacy ABI slot; no native thread broker remains to restart. */
}

void elfcalls_make(struct elf_calls* calls)
{
	calls->native_tsd_base = __darling_native_tsd_base;
	calls->initial_native_tsd_base = __darling_native_tsd_base();
	calls->native_fork = native_fork;
	calls->arm64_thread_bridge_postfork_complete = arm64_thread_bridge_postfork_complete;
	calls->arm64_record_darling_tsd_base = __darling_arm64_record_tsd_base;
	calls->arm64_darling_tsd_base = __darling_arm64_tsd_base;
	calls->dlopen = dlopen_simple;
	calls->dlclose = dlclose;
	calls->dlsym = dlsym;
	calls->dlerror = dlerror;

	calls->dlopen_fatal = dlopen_fatal;
	calls->dlsym_fatal = dlsym_fatal;
	calls->dlclose_fatal = dlclose_fatal;

	calls->darling_thread_create = __darling_thread_create;
	calls->darling_thread_terminate = __darling_thread_terminate;
	calls->darling_thread_get_stack = __darling_thread_get_stack;

	calls->get_errno = get_errno;
	calls->exit = exit;

	calls->malloc = malloc;
	calls->free = free;
	calls->realloc = realloc;

	calls->sysconf = sysconf;

	*((void**)&calls->sem_open) = sem_open;
	*((void**)&calls->sem_wait) = sem_wait;
	*((void**)&calls->sem_trywait) = sem_trywait;
	*((void**)&calls->sem_post) = sem_post;
	*((void**)&calls->sem_close) = sem_close;
	*((void**)&calls->sem_unlink) = sem_unlink;

	*((void**)&calls->shm_open) = shm_open;
	*((void**)&calls->shm_unlink) = shm_unlink;

	calls->dserver_socket_address = __dserver_socket_address;
	calls->dserver_per_thread_socket = __darling_thread_rpc_socket;
	calls->dserver_per_thread_socket_refresh = __darling_thread_rpc_socket_refresh;
	calls->dserver_close_socket = __mldr_close_rpc_socket;

	calls->dserver_get_process_lifetime_pipe = __dserver_get_process_lifetime_pipe;
	calls->dserver_process_lifetime_pipe_refresh = __dserver_process_lifetime_pipe_refresh;
	calls->dserver_close_process_lifetime_pipe = __mldr_close_process_lifetime_pipe;
}
