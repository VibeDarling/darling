/* The prefix's /proc across non-root and root runs. */
#ifndef DARLING_PROC_DIR_H
#define DARLING_PROC_DIR_H

#include <fcntl.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#define DARLING_PROC_SYMLINK_TARGET "/Volumes/SystemRoot/proc"

/*
 * Root mode mounts procfs on the prefix's /proc, which must be a directory, so undo a non-root run's
 * /proc symlink. Anything other than that exact symlink is left alone. Returns false with errno set.
 */
static inline bool darlingEnsureProcDir(const char* prefix)
{
	int prefixFD = open(prefix, O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
	if (prefixFD < 0)
		return false;

	char target[sizeof(DARLING_PROC_SYMLINK_TARGET)];
	ssize_t length = readlinkat(prefixFD, "proc", target, sizeof(target));
	bool ok = length != sizeof(target) - 1 || memcmp(target, DARLING_PROC_SYMLINK_TARGET, length) != 0
		|| (unlinkat(prefixFD, "proc", 0) == 0 && mkdirat(prefixFD, "proc", 0755) == 0);

	int savedErrno = errno;
	close(prefixFD);
	errno = savedErrno;
	return ok;
}

#endif
