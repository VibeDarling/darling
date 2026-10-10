#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include "loader.h"

#define SYSTEM_ROOT "/Library/System"
#include "extracted.inc"

// The real 64-bit stack constructor, as in tests/elfcalls-stack-layout.rb.
#define GEN_64BIT
#include "stack.c"
void elfcalls_make(struct elf_calls* calls) { memset(calls, 0, sizeof(*calls)); }
uintptr_t __darling_arm64_tsd_slot_offset(void) { return 0; }

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

// Runs setup_stack64 in a child with a 16 KiB stack mapping; returns its exit status, or -1 on a signal.
static int run_setup_stack(size_t argc, size_t envc) {
	pid_t pid = fork();
	if (pid == 0) {
		char** av = calloc(argc + 1, sizeof(*av));
		char** ev = calloc(envc + 1, sizeof(*ev));
		for (size_t i = 0; i < argc; ++i) av[i] = "a";
		for (size_t i = 0; i < envc; ++i) ev[i] = "E=1";
		unsigned char* memory = malloc(16384);
		struct load_results lr = {
			.mh = 0x1234, .stack_top = (uintptr_t)(memory + 16384), .main_stack_size = 16384,
			.argc = argc, .envc = envc, .argv = av, .envp = ev, .kernfd = 7,
		};
		freopen("/dev/null", "w", stderr);
		setup_stack64("/x", &lr);
		_exit(0);
	}
	int status;
	waitpid(pid, &status, 0);
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

	// stack-fit helper: 64 KiB stack, 8-byte words, 16 fixed words, half reserved => 4096 words
	size_t stack = 16 * 4096;
	EXPECT(mldr_stack_args_fit(stack, 8, 10, 50, 16), "typical argv/envp fits");
	EXPECT(mldr_stack_args_fit(stack, 8, 2000, 2000, 16), "4016 words fits");
	EXPECT(!mldr_stack_args_fit(stack, 8, 2000, 2081, 16), "just over the limit rejected");
	EXPECT(!mldr_stack_args_fit(stack, 8, 300000, 0, 16), "hundreds of thousands of args rejected");
	EXPECT(!mldr_stack_args_fit(stack, 8, (size_t)-1, 5, 16), "overflowing argc rejected");
	EXPECT(!mldr_stack_args_fit(stack, 8, 5, (size_t)-1, 16), "overflowing envc rejected");
	EXPECT(!mldr_stack_args_fit(0, 8, 0, 0, 16), "empty stack rejected");

	// setup_stack64: 16 KiB stack => 1024 words of argument block
	EXPECT(run_setup_stack(3, 3) == 0, "setup_stack64 accepts a small command line");
	EXPECT(run_setup_stack(3000, 0) == 1, "setup_stack64 rejects 3000 arguments");
	EXPECT(run_setup_stack(0, 3000) == 1, "setup_stack64 rejects 3000 environment entries");

	printf(failures ? "FAILED\n" : "PASS\n");
	return failures != 0;
}
