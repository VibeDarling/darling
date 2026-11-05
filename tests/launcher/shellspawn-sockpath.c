#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>

// The launcher caps DPREFIX at 255 bytes, far more than sun_path holds.
static void build(const char* prefix, char* out, size_t out_size)
{
	struct sockaddr_un addr;
	addr.sun_family = AF_UNIX;
#include "extracted.inc"
	snprintf(out, out_size, "%s", addr.sun_path);
}

static int failures;
#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); ++failures; } } while (0)

// Runs build() in a child so exit(1) and a crash can be told apart from success.
static int run(const char* prefix, char* out, size_t out_size)
{
	fflush(stdout);
	int pipefd[2];
	pipe(pipefd);
	pid_t pid = fork();
	if (pid == 0) {
		freopen("/dev/null", "w", stderr);
		build(prefix, out, out_size);
		write(pipefd[1], out, strlen(out) + 1);
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

int main(void)
{
	char out[512], prefix[512];
	const size_t max = sizeof(((struct sockaddr_un*) 0)->sun_path) - sizeof(SHELLSPAWN_SOCKPATH);

	EXPECT(run("/home/u/.darling", out, sizeof(out)) == 0 && !strcmp(out, "/home/u/.darling" SHELLSPAWN_SOCKPATH), "normal prefix builds the path");

	memset(prefix, 'a', max);
	prefix[max] = '\0';
	EXPECT(run(prefix, out, sizeof(out)) == 0 && strlen(out) == max + strlen(SHELLSPAWN_SOCKPATH), "longest fitting prefix accepted");

	memset(prefix, 'a', max + 1);
	prefix[max + 1] = '\0';
	EXPECT(run(prefix, out, sizeof(out)) == 1, "prefix one byte too long rejected");

	memset(prefix, 'a', 255);
	prefix[255] = '\0';
	EXPECT(run(prefix, out, sizeof(out)) == 1, "255-byte prefix rejected");

	printf(failures ? "FAILED\n" : "PASS\n");
	return failures ? 1 : 0;
}
