#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include "loader.h"

#define SYSTEM_ROOT "/Library/System"
#include "extracted.inc"

static int failures;
#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); ++failures; } } while (0)

// Runs the extracted function in a child so a loud exit(1) can be observed.
static int run_unexpand(const char* root, const char* path, char* out, size_t out_size) {
	int pipefd[2];
	pipe(pipefd);
	pid_t pid = fork();
	if (pid == 0) {
		struct load_results lr = {0};
		char* argv0 = strdup(path);
		lr.root_path = (char*)root;
		lr.root_path_length = strlen(root);
		lr.argv = &argv0;
		freopen("/dev/null", "w", stderr);
		vchroot_unexpand_interpreter(&lr);
		write(pipefd[1], argv0, strlen(argv0) + 1);
		_exit(0);
	}
	close(pipefd[1]);
	int status;
	waitpid(pid, &status, 0);
	ssize_t n = read(pipefd[0], out, out_size - 1);
	out[n > 0 ? n : 0] = '\0';
	close(pipefd[0]);
	return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

int main(void) {
	static char out[1 << 20], big[1 << 17];
	const char* root = "/home/u/.darling";

	// normal input is unchanged
	EXPECT(run_unexpand(root, "/home/u/.darling/usr/bin/perl", out, sizeof(out)) == 0 && !strcmp(out, "/usr/bin/perl"), "normal path is unexpanded");

	// 4095 bytes after the prefix is the longest accepted path
	strcpy(big, root);
	memset(big + strlen(root), 'a', 4095);
	big[strlen(root) + 4095] = 0;
	EXPECT(run_unexpand(root, big, out, sizeof(out)) == 0 && strlen(out) == 4095, "4095-byte path accepted");

	// 4096 bytes and a 128 KiB path are rejected with a non-zero exit
	big[strlen(root) + 4095] = 'a';
	big[strlen(root) + 4096] = 0;
	EXPECT(run_unexpand(root, big, out, sizeof(out)) == 1, "4096-byte path rejected");
	memset(big + strlen(root), 'a', sizeof(big) - strlen(root) - 1);
	big[sizeof(big) - 1] = 0;
	EXPECT(run_unexpand(root, big, out, sizeof(out)) == 1, "128 KiB path rejected");

	printf(failures ? "FAILED\n" : "PASS\n");
	return failures != 0;
}
