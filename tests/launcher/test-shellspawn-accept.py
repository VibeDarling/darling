#!/usr/bin/env python3
"""Exercise shellspawn's accept loop with mocked accept, usleep, perror and fork."""
import argparse
import hashlib
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('source', type=pathlib.Path)
parser.add_argument('--run', action='store_true', help='compile and run the generated harness')
args = parser.parse_args()
source = args.source.read_text()
start = source.index('int listenForConnections(void)\n{')
end = source.index('\n}\n', start) + 3
function = source[start:end]
for required in ('accept(g_serverSocket', 'usleep(', 'perror("shellspawn: accept")', 'fork() == 0', 'return -1;'):
    if required not in function:
        raise SystemExit('unsupported source shape: ' + required)
header = r'''
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
static int g_serverSocket = 3;
static int seq[64], nseq, pos, accepts, sleeps, perrors, forks, closes;
static long slept_us;
static int mock_accept(void)
{
    ++accepts;
    if (accepts > nseq + 8)
    {
        printf("FAIL runaway: accept called %d times past the scripted results\n", accepts - nseq);
        fflush(stdout);
        _exit(1);
    }
    if (pos >= nseq) { errno = EBADF; return -1; }
    int v = seq[pos++];
    if (v > 0) return v;
    errno = -v;
    return -1;
}
#define accept(a, b, c) ((void)(a), (void)(b), (void)(c), mock_accept())
#define usleep(x) (++sleeps, slept_us += (x), 0)
#define perror(x) (++perrors)
#define fork() (++forks)
#define close(x) (++closes)
#define exit(x) ((void)(x))
static void restoreSigchild(void) {}
static void spawnShell(int fd) { (void)fd; }
'''
tail = r'''
static int run(const char *label, const int *s, int n, int rc_exp, int acc, int slp, int per, int frk)
{
    nseq = n; memcpy(seq, s, n * sizeof(int));
    pos = accepts = sleeps = perrors = forks = closes = 0;
    slept_us = 0;
    int rc = listenForConnections();
    int ok = rc == rc_exp && accepts == acc && sleeps == slp && slept_us == 100000L * slp && perrors == per && forks == frk;
    printf("%s %s rc=%d accepts=%d sleeps=%d slept_us=%ld perror=%d forks=%d\n",
        ok ? "PASS" : "FAIL", label, rc, accepts, sleeps, slept_us, perrors, forks);
    return !ok;
}
int main(void)
{
    int f = 0;
    { int s[] = { -EINTR, -EAGAIN, -ECONNABORTED, 7 }; f += run("retry-no-sleep", s, 4, -1, 5, 0, 1, 1); }
    { int s[] = { -EMFILE, -EMFILE, -EMFILE, 7 }; f += run("emfile-streak-logs-once", s, 4, -1, 5, 3, 2, 1); }
    { int s[] = { -ENFILE, -ENOBUFS, -ENOMEM, 7, -EMFILE, 7 }; f += run("streak-reset-logs-twice", s, 6, -1, 7, 4, 3, 2); }
    { int s[] = { -EINVAL }; f += run("einval-fatal", s, 1, -1, 1, 0, 1, 0); }
    { int s[] = { -ENOTSOCK }; f += run("enotsock-fatal", s, 1, -1, 1, 0, 1, 0); }
    return f ? 1 : 0;
}
'''
code = header + function + tail
with tempfile.TemporaryDirectory(prefix='darling-shellspawn-accept-') as tmp:
    output = pathlib.Path(tmp) / 'shellspawn-accept-generated.c'
    output.write_text(code)
    print('source_sha256=' + hashlib.sha256(args.source.read_bytes()).hexdigest(), flush=True)
    print('function_sha256=' + hashlib.sha256(function.encode()).hexdigest(), flush=True)
    print('generated=' + str(output), flush=True)
    if args.run:
        binary = pathlib.Path(tmp) / 'accept-mock'
        subprocess.run(['cc', '-std=c11', '-Wall', '-Werror', str(output), '-o', str(binary)], check=True, timeout=30)
        raise SystemExit(subprocess.run([str(binary)], timeout=30).returncode)
