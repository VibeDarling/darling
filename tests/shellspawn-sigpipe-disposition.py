#!/usr/bin/env python3
"""
Host test: a shell started by shellspawn gets the default SIGPIPE.
usage: python3 tests/shellspawn-sigpipe-disposition.py [REPO_ROOT]
shellspawn ignores SIGPIPE in its own process, and an ignored signal stays
ignored across fork and exec. The harness takes the signal() call from main()
and the child branch of spawnShell() (up to and including execv) from
shellspawn.c, runs them as daemon -> fork -> exec of /bin/sh, and reads
the SigIgn mask of the exec'd program from /proc. SIGPIPE (bit 13) must not
be set, SIGPIPE must not be blocked either (SigBlk), and `yes | head` must die
silently from SIGPIPE (no "Broken pipe"). It runs twice: with an explicit shell
(alloc_exec set) and with the default shell path (alloc_exec NULL, "/bin/zsh"
replaced by /bin/sh because zsh may not exist on the host).
"""

import os
import re
import sys
import tempfile
import subprocess

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src_path = os.path.join(root, "src", "shellspawn", "shellspawn.c")

if not os.path.exists("/proc/self/status"):
    print("SKIP: /proc/self/status not available on this host")
    sys.exit(0)

with open(src_path, "r", encoding="utf-8") as f:
    src = f.read()

m_ignore = re.search(r"^\s*signal\(SIGPIPE, SIG_IGN\);$", src, re.MULTILINE)
if not m_ignore:
    print("FAIL: main() no longer ignores SIGPIPE", file=sys.stderr)
    sys.exit(1)
ignore = m_ignore.group(0).strip()

m_child = re.search(r"\tshell_pid = fork\(\);\n\tif \(shell_pid == 0\)\n\t\{\n(.*?execv\(alloc_exec[^;]*;)", src, re.DOTALL)
if not m_child:
    print("FAIL: spawnShell child branch not found", file=sys.stderr)
    sys.exit(1)
child = m_child.group(1)

cc = os.environ.get("CC", "clang")

for mode in ["explicit", "default"]:
    with tempfile.TemporaryDirectory(prefix="shellspawn-sigpipe-") as d:
        probe_child = child.replace('"/bin/zsh"', '"/bin/sh"') if mode == "default" else child
        probe_c = os.path.join(d, "probe.c")
        with open(probe_c, "w", encoding="utf-8") as f:
            f.write(f"""#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void) {{
    {ignore}
    int out[2], pipefd[2];
    if (pipe(out) || pipe(pipefd)) return 2;
    int shellfd[3] = {{ open("/dev/null", O_RDONLY), out[1], dup(out[1]) }};
    int fd = open("/dev/null", O_RDONLY);
    int ctty_master = -1, ctty_slave = -1;
    char *alloc_exec = { "NULL" if mode == "default" else '"/bin/sh"' };
    char *argv[] = {{ "sh", "-c", "grep '^Sig[IB][gl][nk]' /proc/self/status; yes | head -c1 >/dev/null; exit 0", NULL }};
    if (fork() == 0) {{            /* the per-connection child */
{probe_child}
        _exit(1);
    }}
    close(out[1]);
    close(shellfd[0]);
    close(shellfd[2]);
    close(fd);
    close(pipefd[0]);
    close(pipefd[1]);

    char buf[512] = {{0}};
    size_t total = 0;
    ssize_t n;
    while ((n = read(out[0], buf + total, sizeof(buf) - 1 - total)) > 0) {{
        total += (size_t)n;
    }}
    close(out[0]);
    wait(NULL);

    fputs(buf, stdout);
    unsigned long mask = 0;
    char *p = strstr(buf, "SigIgn:");
    if (!p || sscanf(p, "SigIgn: %lx", &mask) != 1) return 3;
    if (mask & (1UL << (SIGPIPE - 1))) {{ puts("FAIL: SIGPIPE is ignored in the shell"); return 1; }}
    unsigned long blk = 0;
    p = strstr(buf, "SigBlk:");
    if (!p || sscanf(p, "SigBlk: %lx", &blk) != 1) return 3;
    if (blk & (1UL << (SIGPIPE - 1))) {{ puts("FAIL: SIGPIPE is blocked in the shell"); return 1; }}
    if (strstr(buf, "Broken pipe")) {{ puts("FAIL: yes reported a write error instead of dying from SIGPIPE"); return 1; }}
    puts("PASS: the shell starts with the default SIGPIPE");
    return 0;
}}
""")
        probe_bin = os.path.join(d, "probe")
        subprocess.check_call([cc, "-Wall", probe_c, "-o", probe_bin])
        res = subprocess.run([probe_bin], capture_output=True, text=True)
        print(f"[{mode}] {res.stdout.strip()}")
        if res.returncode != 0:
            print(f"FAIL: shellspawn SIGPIPE regression ({mode})", file=sys.stderr)
            sys.exit(1)

print("PASS: all shellspawn SIGPIPE disposition tests succeeded")
