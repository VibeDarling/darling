#define _GNU_SOURCE
#include <stdio.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdbool.h>
#include <sys/poll.h>
#include <sys/wait.h>
#include <sys/prctl.h>
#include <sys/sendfile.h>
#include <assert.h>
#include <stdarg.h>

int __real_open(const char *path, int flags, ...);

static pid_t s_fail_cmdline_pid = 0;
static int s_fail_errno = EACCES;

int __wrap_open(const char *path, int flags, ...)
{
	mode_t mode = 0;
	if (flags & O_CREAT) {
		va_list args;
		va_start(args, flags);
		mode = (mode_t)va_arg(args, mode_t);
		va_end(args);
	}

	if (s_fail_cmdline_pid > 0) {
		char target[64];
		snprintf(target, sizeof(target), "/proc/%d/cmdline", s_fail_cmdline_pid);
		if (!strcmp(path, target)) {
			errno = s_fail_errno;
			return -1;
		}
	}

	return __real_open(path, flags, mode);
}

#include "../../src/startup/container-shutdown.h"

static void report(int fd)
{
	pid_t p = getpid();
	assert(write(fd, &p, sizeof(p)) == sizeof(p));
}

static void forever(void)
{
	for (;;) pause();
}

static void copy(const char *from, const char *to)
{
	int in = open(from, O_RDONLY);
	int out = open(to, O_WRONLY | O_CREAT | O_TRUNC, 0755);
	struct stat st;
	assert(in >= 0 && out >= 0 && fstat(in, &st) == 0 && sendfile(out, in, NULL, st.st_size) == st.st_size);
	close(in);
	close(out);
}

static pid_t spawnGuest(const char *exe, char **env, int fd)
{
	pid_t c = fork();
	assert(c >= 0);
	if (!c) {
		char f[16];
		snprintf(f, sizeof(f), "%d", fd);
		char *argv[] = {"child", "plain", f, NULL};
		execve(exe, argv, env);
		_exit(99);
	}
	return c;
}

static pid_t readPid(int fd)
{
	pid_t p;
	assert(read(fd, &p, sizeof(p)) == sizeof(p));
	return p;
}

static bool isAlive(pid_t p)
{
	char s[64];
	snprintf(s, sizeof(s), "/proc/%d/stat", p);
	FILE *f = fopen(s, "r");
	if (!f) return false;
	char b[512];
	char *r = fgets(b, sizeof(b), f);
	fclose(f);
	char *e = r ? strrchr(b, ')') : NULL;
	return e && e[2] != 'Z';
}

int main(int argc, char **argv)
{
	if (!strcmp(argv[0], "darlingserver")) {
		prctl(PR_SET_PDEATHSIG, SIGKILL);
		forever();
	}
	if (argc == 3) {
		int fd = atoi(argv[2]);
		signal(SIGTERM, SIG_IGN);
		prctl(PR_SET_PDEATHSIG, SIGKILL);
		report(fd);
		forever();
	}

	prctl(PR_SET_CHILD_SUBREAPER, 1);

	// Unit tests for shutdownServerMatches
	char self[4096];
	ssize_t n = readlink("/proc/self/exe", self, sizeof(self) - 1);
	assert(n > 0);
	self[n] = 0;

	pid_t server = fork();
	assert(server >= 0);
	if (!server) {
		execl(self, "darlingserver", "/test-prefix", NULL);
		_exit(99);
	}

	for (int i = 0; i < 50 && shutdownServerMatches(server, "/test-prefix") != 1; i++) {
		usleep(20000);
	}

	// 1. Matches expected prefix
	assert(shutdownServerMatches(server, "/test-prefix") == 1);

	// 2. Mismatched prefix returns 0
	assert(shutdownServerMatches(server, "/different-prefix") == 0);

	// 3. Process that has died returns 0 (not an error)
	assert(shutdownServerMatches(999999, "/test-prefix") == 0);

	// 4. Inspection failure on cmdline (EACCES) returns -1
	s_fail_cmdline_pid = server;
	s_fail_errno = EACCES;
	assert(shutdownServerMatches(server, "/test-prefix") == -1);
	assert(errno == EACCES);

	// 5. Inspection failure on cmdline (EPERM) returns -1
	s_fail_errno = EPERM;
	assert(shutdownServerMatches(server, "/test-prefix") == -1);
	assert(errno == EPERM);

	s_fail_cmdline_pid = 0;
	kill(server, SIGKILL);
	waitpid(server, NULL, 0);

	// Integration test for shutdownOrphans with cmdline inspection failure
	const char *base = getenv("TMPDIR");
	char tmpl[4096], dir[4096];
	snprintf(tmpl, sizeof(tmpl), "%s/proc-perm-test-XXXXXX", base ? base : "/tmp");
	assert(mkdtemp(tmpl) && realpath(tmpl, dir));

	char dirMldr[4096 + 16], mldrBin[4096 + 32];
	snprintf(dirMldr, sizeof(dirMldr), "%s/bin", dir);
	assert(mkdir(dirMldr, 0700) == 0);
	snprintf(mldrBin, sizeof(mldrBin), "%s/mldr", dirMldr);
	copy(self, mldrBin);
	const char *const mldr[2] = {mldrBin, mldrBin};

	char sockEnv[4096 + 64];
	snprintf(sockEnv, sizeof(sockEnv), "__mldr_sockpath=%s/.darlingserver.sock", dir);
	char *envGuest[] = {sockEnv, NULL};

	int p[2];
	assert(pipe(p) == 0);
	spawnGuest(mldrBin, envGuest, p[1]);
	pid_t guest = readPid(p[0]);
	close(p[1]);
	close(p[0]);
	assert(isAlive(guest));

	pid_t liveServer = fork();
	assert(liveServer >= 0);
	if (!liveServer) {
		execl(self, "darlingserver", dir, NULL);
		_exit(99);
	}
	for (int i = 0; i < 50 && shutdownServerMatches(liveServer, dir) != 1; i++) {
		usleep(20000);
	}
	assert(shutdownServerMatches(liveServer, dir) == 1);

	// When server's cmdline cannot be read due to permission error:
	// shutdownOrphans must fail (-1), report no liveServer, and MUST NOT kill the guest!
	s_fail_cmdline_pid = liveServer;
	s_fail_errno = EACCES;
	pid_t live = 0;
	int stopped = shutdownOrphans(dir, getuid(), mldr, &live);
	assert(stopped == -1);
	assert(live == 0);
	assert(isAlive(guest)); // Guest process survives!

	// When inspection error is cleared:
	s_fail_cmdline_pid = 0;
	stopped = shutdownOrphans(dir, getuid(), mldr, &live);
	assert(stopped == 0);
	assert(live == liveServer);
	assert(isAlive(guest)); // Live server protects guest!

	// When server is actually dead:
	kill(liveServer, SIGKILL);
	waitpid(liveServer, NULL, 0);

	stopped = shutdownOrphans(dir, getuid(), mldr, &live);
	assert(stopped == 1);
	assert(live == 0);
	while (waitpid(-1, NULL, WNOHANG) > 0) {}
	assert(!isAlive(guest)); // Orphan is cleaned up!

	unlink(mldrBin);
	rmdir(dirMldr);
	rmdir(dir);

	puts("PASS: permission errors on cmdline return -1 and prevent orphan reaping; real darlingserver matches return 1; mismatches and dead processes return 0");
	return 0;
}
