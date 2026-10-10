#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

extern int lkm_call(int nr, ...);
extern int __darling_vchroot(int dfd);
#ifdef DARLING_DEBUG
extern void darling_kprintf(const char* format, ...);
#define DLOG(...) darling_kprintf(__VA_ARGS__)
#else
#define DLOG(...) ((void)0)
#endif

int main(int argc, const char** argv)
{
    if (argc < 3)
	{
		DLOG("vchroot: argc < 3\n");
		fprintf(stderr, "vchroot <dir> <binary> [args...]\n");
		return 1;
	}
	DLOG("VCHROOT MAIN ENTERED! argc=%d argv[0]=%s argv[1]=%s argv[2]=%s\n",
		argc, argv[0] ? argv[0] : "(null)", argv[1] ? argv[1] : "(null)", argv[2] ? argv[2] : "(null)");

	// In nonroot mode there is no mount namespace, so the prefix is a plain
	// host directory and must be opened directly. In root/rootless mode we
	// are already inside a mount namespace where the host root is visible
	// under /Volumes/SystemRoot, so try that path first.
	int dfd = -1;
	if (getenv("DARLING_NONROOT")) {
		dfd = open(argv[1], O_RDONLY | O_DIRECTORY);
	} else {
		char host_path[4096];
		if (snprintf(host_path, sizeof(host_path), "/Volumes/SystemRoot%s", argv[1])
		    < (int)sizeof(host_path))
			dfd = open(host_path, O_RDONLY | O_DIRECTORY);
		if (dfd == -1)
			dfd = open(argv[1], O_RDONLY | O_DIRECTORY);
	}
	if (dfd == -1)
	{
		DLOG("vchroot: open prefix failed errno=%d\n", errno);
		perror("open");
		return 1;
	}
	DLOG("vchroot: open prefix OK (dfd=%d)\n", dfd);

	if (fchdir(dfd) == -1)
	{
		DLOG("vchroot: fchdir failed errno=%d\n", errno);
		perror("fchdir");
		return 2;
	}
	DLOG("vchroot: fchdir OK, calling __darling_vchroot\n");

	if (__darling_vchroot(dfd) < 0)
	{
		DLOG("vchroot: __darling_vchroot failed errno=%d\n", errno);
		perror("vchroot");
		return 3;
	}
	DLOG("vchroot: __darling_vchroot OK, calling execv %s\n", argv[2]);

	close(dfd);

	// This is only needed for this binary and shouldn't be passed down
	unsetenv("DYLD_ROOT_PATH");

	// printf("Will execv %s\n", argv[2]);
	execv(argv[2], (char * const *) argv+2);
	DLOG("vchroot: execv returned (FAILED errno=%d)!\n", errno);
	perror("execv");

	return 4;
}
