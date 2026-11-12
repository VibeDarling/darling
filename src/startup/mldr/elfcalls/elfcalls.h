#ifndef _ELFCALLS_H_
#define _ELFCALLS_H_

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

struct darling_thread_create_callbacks {
	unsigned int (*thread_self_trap)(void);
	void (*thread_set_tsd_base)(void*, int);
	void (*rpc_guard)(int);
	void (*rpc_unguard)(int);
};

typedef const struct darling_thread_create_callbacks* darling_thread_create_callbacks_t;

struct elf_calls
{
	// ELF dynamic loader access
	void* (*dlopen)(const char* name);
	int (*dlclose)(void* lib);
	void* (*dlsym)(void* lib, const char* name);
	char* (*dlerror)(void);

	// pthread wrapping
	void* (*darling_thread_create)(unsigned long stack_size, unsigned long pthobj_size,
                void* entry_point, uintptr_t arg3,
                uintptr_t arg4, uintptr_t arg5, uintptr_t arg6,
                darling_thread_create_callbacks_t callbacks, void* dthread);
	int (*darling_thread_terminate)(void* stackaddr,
				unsigned long freesize, unsigned long pthobj_size);

	// this returns the address of the main thread's stack
	void* (*darling_thread_get_stack)(void);

	// The same as above, except they abort() in case of failure
	void* (*dlopen_fatal)(const char* name);
	int (*dlclose_fatal)(void* lib);
	void* (*dlsym_fatal)(void* lib, const char* name);

	// POSIX semaphore APIs
	int (*get_errno)(void);
	int* (*sem_open)(const char* name, int oflag, unsigned short mode, unsigned int value);
	int (*sem_wait)(int* sem);
	int (*sem_trywait)(int* sem);
	int (*sem_post)(int* sem);
	int (*sem_close)(int* sem);
	int (*sem_unlink)(const char* name);

	// POSIX SHM APIs
	int (*shm_open)(const char* name, int oflag, unsigned short mode);
	int (*shm_unlink)(const char* name);

	void (*exit)(int ec);

	// Memory allocation
	void* (*malloc)(size_t size);
	void (*free)(void *ptr);
	void* (*realloc)(void *ptr, size_t size);

	// POSIX sysconf
	long (*sysconf)(int name);

	// darlingserver RPC info
	const void* (*dserver_socket_address)(void);
	int (*dserver_per_thread_socket)(void);
	void (*dserver_per_thread_socket_refresh)(void);
	void (*dserver_close_socket)(int socket);

	// darlingserver process lifetime pipe info
	int (*dserver_get_process_lifetime_pipe)(void);
	int (*dserver_process_lifetime_pipe_refresh)(void);
	void (*dserver_close_process_lifetime_pipe)(int fd);

	// Preserve the appended layout used by existing ARM64 integration builds.
	void* (*native_tsd_base)(void);
	void* initial_native_tsd_base;
	int (*native_fork)(void);
	void (*arm64_thread_bridge_postfork_complete)(void);
	void (*arm64_record_darling_tsd_base)(void* base);
	void* (*arm64_darling_tsd_base)(void);
};

/* Table entries and dlsym results are raw host addresses, but arm64e
 * callers authenticate function pointers before calling. ELFCALL signs
 * a table member for a call, ELFCALLS_SIGN signs a dlsym result before
 * it is stored in a typed pointer, ELFCALLS_STRIP hands an arm64e
 * callback to host code. All three are the identity on arm64 and ELF.
 * They assume discriminator 0 (Apple's default arm64e C ABI), so
 * -fptrauth-function-pointer-type-discrimination would break them. */
#if defined(__has_feature)
# if __has_feature(ptrauth_calls)
#  define ELFCALL(tbl, member) ((__typeof__((tbl)->member)) \
	__builtin_ptrauth_sign_unauthenticated( \
		*(void* const*)&(tbl)->member, 0, 0))
#  define ELFCALLS_SIGN(raw) \
	__builtin_ptrauth_sign_unauthenticated((void*)(raw), 0, 0)
#  define ELFCALLS_STRIP(fn) \
	((__typeof__(&*(fn)))__builtin_ptrauth_strip((void*)(fn), 0))
# endif
#endif
#ifndef ELFCALL
# define ELFCALL(tbl, member) ((tbl)->member)
# define ELFCALLS_SIGN(raw)   ((void*)(raw))
# define ELFCALLS_STRIP(fn)   (fn)
#endif

#endif
