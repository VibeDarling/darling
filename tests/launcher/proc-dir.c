#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "../../src/startup/proc-dir.h"

static char root[] = "/tmp/darling-proc-dir-test.XXXXXX";

static void makePrefix(const char* name, char* prefix)
{
	snprintf(prefix, 128, "%s/%s", root, name);
	assert(mkdir(prefix, 0755) == 0);
}

static void procPath(const char* prefix, char* path)
{
	snprintf(path, 256, "%s/proc", prefix);
}

static void assertSymlinkKept(const char* name, const char* target)
{
	char prefix[128], path[256], actual[256];
	makePrefix(name, prefix);
	procPath(prefix, path);
	assert(symlink(target, path) == 0);
	assert(darlingEnsureProcDir(prefix));
	ssize_t length = readlink(path, actual, sizeof(actual) - 1);
	assert(length >= 0);
	actual[length] = '\0';
	assert(strcmp(actual, target) == 0);
}

int main(void)
{
	assert(mkdtemp(root));
	char prefix[128], path[256];
	struct stat st;

	makePrefix("symlink", prefix);
	procPath(prefix, path);
	assert(symlink(DARLING_PROC_SYMLINK_TARGET, path) == 0);
	assert(darlingEnsureProcDir(prefix));
	assert(lstat(path, &st) == 0 && S_ISDIR(st.st_mode));
	assert(darlingEnsureProcDir(prefix));

	assertSymlinkKept("other-target", "/etc");
	assertSymlinkKept("trailing-slash", DARLING_PROC_SYMLINK_TARGET "/");
	assertSymlinkKept("longer-target", DARLING_PROC_SYMLINK_TARGET "x");
	assertSymlinkKept("shorter-target", "/Volumes/SystemRoot/pro");
	assertSymlinkKept("relative-target", "Volumes/SystemRoot/proc");

	makePrefix("directory", prefix);
	procPath(prefix, path);
	assert(mkdir(path, 0700) == 0);
	char entry[512];
	snprintf(entry, sizeof(entry), "%s/keep", path);
	assert(mkdir(entry, 0700) == 0);
	assert(darlingEnsureProcDir(prefix));
	assert(stat(entry, &st) == 0);

	makePrefix("file", prefix);
	procPath(prefix, path);
	FILE* f = fopen(path, "w");
	assert(f && fclose(f) == 0);
	assert(darlingEnsureProcDir(prefix));
	assert(lstat(path, &st) == 0 && S_ISREG(st.st_mode));

	makePrefix("missing", prefix);
	procPath(prefix, path);
	assert(darlingEnsureProcDir(prefix));
	assert(lstat(path, &st) != 0 && errno == ENOENT);

	// A prefix reached through a symlink is refused, and the /proc symlink behind it is kept.
	makePrefix("real", prefix);
	procPath(prefix, path);
	assert(symlink(DARLING_PROC_SYMLINK_TARGET, path) == 0);
	char link[128];
	snprintf(link, sizeof(link), "%s/link", root);
	assert(symlink(prefix, link) == 0);
	assert(!darlingEnsureProcDir(link) && errno == ENOTDIR);
	assert(lstat(path, &st) == 0 && S_ISLNK(st.st_mode));

	snprintf(prefix, sizeof(prefix), "%s/absent", root);
	assert(!darlingEnsureProcDir(prefix) && errno == ENOENT);

	char cmd[128];
	snprintf(cmd, sizeof(cmd), "rm -rf '%s'", root);
	assert(system(cmd) == 0);
	puts("PASS: only the exact non-root /proc symlink becomes a directory; other entries and symlinked prefixes are left alone");
	return 0;
}
