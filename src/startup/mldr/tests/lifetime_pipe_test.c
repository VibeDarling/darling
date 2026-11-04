// Runs the real __mldr_create_process_lifetime_pipe and the lifetime-pipe branch of setup_space
// (both extracted from mldr.c) with pipe() and getrlimit() forced to fail.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>

#define MAX_CLOSES 16
static int closed[MAX_CLOSES];
static int close_count;

static int harness_close(int fd) {
	if (close_count < MAX_CLOSES) {
		closed[close_count] = fd;
	}
	++close_count;
	return 0;
}

static int harness_pipe(int fds[2]) {
	errno = EMFILE;
	return -1;
}

static int harness_getrlimit(int resource, struct rlimit* limit) {
	errno = EPERM;
	return -1;
}

static bool is_kernel_at_least(int major, int minor) {
	return false;
}

#define close harness_close
#define pipe harness_pipe
#define getrlimit harness_getrlimit
#include "extracted.inc"
#undef close
#undef pipe
#undef getrlimit

struct fake_lr {
	int lifetime_pipe;
};

static void setup_space_branch(struct fake_lr* lr, int* lifetime_pipe) {
#include "branch.inc"
}

int main(void) {
	// The caller's array is uninitialised in setup_space; 0 stands in for stale stack contents.
	int fds[2] = { 0, 0 };
	int rc = __mldr_create_process_lifetime_pipe(fds);
	int failed = 0;

	if (rc != -1) {
		printf("FAIL: pipe() failure returned %d, expected -1\n", rc);
		failed = 1;
	}
	if (close_count != 0) {
		printf("FAIL: error path closed %d descriptor(s) it never opened (first: %d)\n", close_count, closed[0]);
		failed = 1;
	}
	if (fds[0] != -1 || fds[1] != -1) {
		printf("FAIL: fds left as {%d, %d}, expected {-1, -1}\n", fds[0], fds[1]);
		failed = 1;
	}

	// setup_space with a failing socket_bitmap_get must say so and exit(1).
	int errpipe[2];
	if (pipe(errpipe) == -1) {
		perror("pipe");
		return 2;
	}
	pid_t pid = fork();
	if (pid == 0) {
		dup2(errpipe[1], 2);
		close(errpipe[0]);
		socket_bitmap.highest = -1;
		struct fake_lr lr = { .lifetime_pipe = 5 };
		int lp[2];
		setup_space_branch(&lr, lp);
		_exit(77);
	}
	close(errpipe[1]);
	char msg[256] = { 0 };
	read(errpipe[0], msg, sizeof(msg) - 1);
	int status = 0;
	waitpid(pid, &status, 0);
	if (!WIFEXITED(status) || WEXITSTATUS(status) != 1) {
		printf("FAIL: setup_space branch exit status %d, expected exit(1)\n", status);
		failed = 1;
	}
	if (!strstr(msg, "allocate a descriptor")) {
		printf("FAIL: setup_space branch did not diagnose the allocation failure, stderr: %s", msg);
		failed = 1;
	}

	if (failed) {
		return 1;
	}
	printf("PASS\n");
	return 0;
}
