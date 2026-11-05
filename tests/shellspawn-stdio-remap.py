#!/usr/bin/env python3
"""
Host test: the guest shell gets the client's three streams on 0, 1 and 2 even
when shellspawn was started with stdio closed.
usage: python3 tests/shellspawn-stdio-remap.py [REPO_ROOT]
With 0, 1 and 2 closed in the daemon, the listening socket, the accepted
control socket and the descriptors received with SHELLSPAWN_GO take the lowest
free numbers, so they can sit on 0, 1 or 2 themselves. The harness takes the
child branch of spawnShell() (up to and including execv) from shellspawn.c,
puts the control socket and the three streams on chosen numbers, and runs
/bin/sh, which reads a line from stdin, echoes it to stdout and writes a line
to stderr. Each layout must deliver "out:<line>" on the stdout stream and
"err" on the stderr stream, and the exec-error pipe must stay empty.
"""

import os
import re
import shlex
import subprocess
import sys
import tempfile

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(root, "src", "shellspawn", "shellspawn.c"), encoding="utf-8") as f:
    src = f.read()

m_child = re.search(r"\tshell_pid = fork\(\);\n\tif \(shell_pid == 0\)\n\t\{\n(.*?execv\(alloc_exec[^;]*;)", src, re.DOTALL)
if not m_child:
    print("FAIL: spawnShell child branch not found")
    sys.exit(1)
child = m_child.group(1)

# (control socket, stdin stream, stdout stream, stderr stream)
layouts = [
    ("natural", (1, 2, 5, 7)),     # 0 = listening socket, 1 = accepted, then received fds
    ("swapped", (9, 1, 0, 2)),     # streams permuted over 0-2
    ("rotated", (0, 2, 1, 8)),
    ("high", (9, 10, 11, 12)),     # normal case: stdio open, everything above 2
]

probe = r"""#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>

static int report = -1;
#define FAIL(...) do { dprintf(report, "FAIL: " __VA_ARGS__); dprintf(report, "\n"); exit(1); } while (0)

static int high(int fd) {
	int h = fcntl(fd, F_DUPFD, 40);
	if (h < 0) FAIL("F_DUPFD");
	close(fd);
	return h;
}
static int place(int fd, int want) {
	if (fcntl(want, F_GETFD) != -1) FAIL("slot %d taken", want);
	if (dup2(fd, want) != want) FAIL("dup2 %d", want);
	close(fd);
	return want;
}
static void slurp(int fd, char *buf, size_t n) {
	size_t total = 0;
	ssize_t r;
	while (total < n - 1 && (r = read(fd, buf + total, n - 1 - total)) > 0) total += (size_t) r;
	buf[total] = 0;
}

int main(int argc, char **args) {
	int in[2], out[2], err[2], pipefd[2], ctl[2];
	if (argc != 6) return 2;
	report = fcntl(STDOUT_FILENO, F_DUPFD_CLOEXEC, 60);
	if (pipe(in) || pipe(out) || pipe(err) || pipe(pipefd) || pipe(ctl)) return 2;
	int *all[] = { &in[0], &in[1], &out[0], &out[1], &err[0], &err[1], &pipefd[0], &pipefd[1], &ctl[0], &ctl[1] };
	for (unsigned i = 0; i < sizeof(all) / sizeof(all[0]); i++) *all[i] = high(*all[i]);
	close(STDIN_FILENO);
	close(STDOUT_FILENO);
	close(STDERR_FILENO);

	/* the daemon's other descriptors on the low numbers left over */
	int fd = place(ctl[0], atoi(args[1]));
	int shellfd[3] = { place(in[0], atoi(args[2])), place(out[1], atoi(args[3])), place(err[1], atoi(args[4])) };
	for (int i = 0; i <= 2; i++)
		if (fcntl(i, F_GETFD) == -1 && open("/dev/null", O_RDWR) != i) FAIL("filler %d", i);
	int ctty_master = -1, ctty_slave = -1;
	char *alloc_exec = "/bin/sh";
	char *argv[] = { "sh", "-c", "read line; echo \"out:$line\"; echo err >&2", NULL };
	pid_t shell_pid = fork();
	if (shell_pid == 0) {
""" + child + r"""
		_exit(127);
	}
	if (shell_pid < 0) FAIL("fork");
	close(fd);
	for (int i = 0; i < 3; i++) close(shellfd[i]);
	close(pipefd[1]);
	close(ctl[1]);
	if (write(in[1], "hello\n", 6) != 6) FAIL("write stdin");
	close(in[1]);

	char obuf[256], ebuf[256], pbuf[16];
	slurp(out[0], obuf, sizeof(obuf));
	slurp(err[0], ebuf, sizeof(ebuf));
	slurp(pipefd[0], pbuf, sizeof(pbuf));
	int status;
	waitpid(shell_pid, &status, 0);

	if (pbuf[0]) FAIL("the shell child reported an error through the exec pipe");
	if (strcmp(obuf, "out:hello\n") != 0) FAIL("stdout stream got \"%s\", want \"out:hello\\n\"", obuf);
	if (strcmp(ebuf, "err\n") != 0) FAIL("stderr stream got \"%s\", want \"err\\n\"", ebuf);
	dprintf(report, "PASS\n");
	return 0;
}
"""

cc = shlex.split(os.environ.get("CC", "cc"))
failed = False
with tempfile.TemporaryDirectory(prefix="shellspawn-stdio-") as d:
    probe_c = os.path.join(d, "probe.c")
    probe_bin = os.path.join(d, "probe")
    with open(probe_c, "w", encoding="utf-8") as f:
        f.write(probe)
    build = subprocess.run(cc + ["-Wall", "-Wno-unused-result", probe_c, "-o", probe_bin], capture_output=True, text=True)
    if build.returncode != 0:
        sys.stderr.write(build.stdout + build.stderr)
        sys.exit("FAIL: shellspawn stdio probe did not build")
    for name, (ctl, sin, sout, serr) in layouts:
        res = subprocess.run([probe_bin, str(ctl), str(sin), str(sout), str(serr), name],
                             capture_output=True, text=True, timeout=30)
        line = res.stdout.strip() or f"FAIL: exit {res.returncode}"
        print(f"[{name}: socket {ctl}, streams {sin} {sout} {serr}] {line}")
        failed |= res.returncode != 0

if failed:
    print("FAIL: the shell did not get its streams on 0, 1 and 2")
    sys.exit(1)
print("PASS: the shell gets its streams on 0, 1 and 2 in every layout")
