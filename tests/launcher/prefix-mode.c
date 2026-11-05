// Runs the launcher's prefix creation and owner check (extracted by prefix-mode.sh) on real
// directories under a scratch dir. Cases that end in exit(1) run in a child process.
#define _GNU_SOURCE
#include <errno.h>
#include <pwd.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

char* prefix;
uid_t g_originalUid;
bool g_nonroot = true;

static void useOriginalIds(void) {}
static void restoreRootIds(void) {}
static void ensureProcSymlink(const char* p) { (void) p; }
static void ensureHostRootSymlinks(const char* p) { (void) p; }
static void ensureShSymlink(const char* p) { (void) p; }
static void ensureHomebrewSymlinks(const char* p) { (void) p; }
static void ensureSystemVolumesDataSymlink(const char* p) { (void) p; }
static void ensureCupsSymlink(const char* p) { (void) p; }
static void ensureKeychains(const char* p) { (void) p; }

#include "funcs.inc"

static int failures;
#define CHECK(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); failures++; } } while (0)

// Runs fn in a child and returns its exit status (or -1 if killed).
static int inChild(void (*fn)(void))
{
	fflush(NULL);
	pid_t pid = fork();
	if (pid == 0) {
		freopen("/dev/null", "w", stderr);
		fn();
		_exit(0);
	}
	int status;
	waitpid(pid, &status, 0);
	return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

static void doSetup(void) { setupPrefix(); }
static void doCheck(void) { checkPrefixOwner(); }

static mode_t modeOf(const char* p)
{
	struct stat st;
	return stat(p, &st) == 0 ? (st.st_mode & 07777) : (mode_t) -1;
}

int main(int argc, char** argv)
{
	if (argc < 2) return 2;
	const char* work = argv[1];
	char path[4096];
	g_originalUid = getuid();
	prefix = path;
	mkdir(work, 0700);

	// A new prefix root is owner-only whatever the umask.
	mode_t umasks[] = { 0000, 0022, 0002 };
	for (size_t i = 0; i < sizeof(umasks) / sizeof(umasks[0]); i++) {
		snprintf(path, sizeof(path), "%s/new-%03o/prefix", work, umasks[i]);
		mode_t old = umask(umasks[i]);
		int rc = inChild(doSetup);
		umask(old);
		char msg[128];
		snprintf(msg, sizeof(msg), "setupPrefix exit status %d under umask %03o", rc, umasks[i]);
		CHECK(rc == 0, msg);
		snprintf(msg, sizeof(msg), "new prefix mode %04o under umask %03o, want 0700", modeOf(path), umasks[i]);
		CHECK(modeOf(path) == 0700, msg);
	}

	// An existing directory keeps its mode when setupPrefix() fills it.
	snprintf(path, sizeof(path), "%s/existing", work);
	mkdir(path, 0750);
	chmod(path, 0750);
	CHECK(inChild(doSetup) == 0 && modeOf(path) == 0750, "setupPrefix changed the mode of an existing directory");

	// checkPrefixOwner(): world-writable refused, the modes earlier versions created accepted.
	struct { mode_t mode; int want; } cases[] = {
		{ 0777, 1 }, { 0757, 1 }, { 01777, 1 }, { 0755, 0 }, { 0775, 0 }, { 0700, 0 },
	};
	for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
		snprintf(path, sizeof(path), "%s/check-%o", work, cases[i].mode);
		mkdir(path, 0700);
		chmod(path, cases[i].mode);
		int rc = inChild(doCheck);
		char msg[128];
		snprintf(msg, sizeof(msg), "checkPrefixOwner on mode %04o exit %d, want %d", cases[i].mode, rc, cases[i].want);
		CHECK(rc == cases[i].want, msg);
	}

	if (failures) {
		printf("%d check(s) failed\n", failures);
		return 1;
	}
	puts("prefix-mode: all checks passed");
	return 0;
}
