#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include "loader.h"

#define SYSTEM_ROOT "/Library/System"
#include "extracted.inc"

static int failures;
#define EXPECT(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); ++failures; } } while (0)

// Runs the extracted function in a child so a loud exit(1) can be observed.
// `value` NULL leaves the variable unset. Returns the exit status; the accepted path goes to `out`.
static int run_env(const char* value, char* out, size_t out_size) {
	fflush(stdout);
	int pipefd[2];
	pipe(pipefd);
	pid_t pid = fork();
	if (pid == 0) {
		struct load_results lr = {0};
		freopen("/dev/null", "w", stderr);
		unsetenv("__mldr_sockpath");
		if (value != NULL) {
			setenv("__mldr_sockpath", value, 1);
		}
		process_special_env(&lr);
		write(pipefd[1], __dserver_socket_address_data.sun_path, strlen(__dserver_socket_address_data.sun_path) + 1);
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
	char out[256], path[256];
	const size_t max = sizeof(__dserver_socket_address_data.sun_path) - 1;

	EXPECT(run_env("/home/u/.darling/.darlingserver.sock", out, sizeof(out)) == 0 && !strcmp(out, "/home/u/.darling/.darlingserver.sock"), "normal path is used");

	memset(path, 'a', max);
	path[0] = '/';
	path[max] = '\0';
	EXPECT(run_env(path, out, sizeof(out)) == 0 && strlen(out) == max, "longest fitting path accepted");

	path[max] = 'a';
	path[max + 1] = '\0';
	EXPECT(run_env(path, out, sizeof(out)) == 1, "over-long path rejected");

	EXPECT(run_env(NULL, out, sizeof(out)) == 1, "unset path rejected");
	EXPECT(run_env("", out, sizeof(out)) == 1, "empty path rejected");

	printf(failures ? "FAILED\n" : "PASS\n");
	return failures ? 1 : 0;
}
