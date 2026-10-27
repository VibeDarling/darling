#!/usr/bin/env python3
"""Exercise the exact Darling startup branch with authored side-effect mocks."""
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
start = source.index('\t// If prefix\'s init is not running, start it up')
end = source.index('\n\telse if (g_nonroot)', start)
branch = source[start:end]
for required in ('if (pidInit == 0)', 'stopPrefixOrphans(&liveServer)', 'unlink(socketPath)', 'spawnInitProcess()', 'putInitPid(pidInit)'):
    if required not in branch:
        raise SystemExit('unsupported source shape: ' + required)
header = r'''
#include <stdio.h>
#include <sys/types.h>
#define SHELLSPAWN_SOCKPATH "/var/run/shellspawn.sock"
#define SHELLSPAWN_WAIT_RETRIES 1
static const char *prefix = "/synthetic-prefix";
static int g_nonroot = 0;
static int scan_result;
static pid_t detected_server;
static int unlinks, setups, spawns, pid_writes;
static int stopPrefixOrphans(pid_t *server) { *server = detected_server; return scan_result; }
static void useOriginalIds(void) {}
static void restoreRootIds(void) {}
static int unlink(const char *path) { (void)path; ++unlinks; return 0; }
static void setupWorkdir(void) { ++setups; }
static pid_t spawnInitProcess(void) { ++spawns; return 8002; }
static void putInitPid(pid_t pid) { (void)pid; ++pid_writes; }
static void spawnShellspawn(void) {}
static int existsAsOriginalUser(const char *path) { (void)path; return 0; }
static int usleep(unsigned usec) { (void)usec; return 0; }
static int startup(pid_t pidInit) {
'''
tail = r'''
return 0;
}
static int check(const char *label, int scan, pid_t live, int expected_rc, int expected_mutations) {
    scan_result = scan; detected_server = live;
    unlinks = setups = spawns = pid_writes = 0;
    int rc = startup(0);
    int mutations = unlinks + setups + spawns + pid_writes;
    int passed = rc == expected_rc && mutations == expected_mutations;
    printf("%s %s rc=%d unlink=%d setup=%d spawn=%d pidwrite=%d\n",
        passed ? "PASS" : "FAIL", label, rc, unlinks, setups, spawns, pid_writes);
    return !passed;
}
int main(void) {
    int failed = 0;
    failed += check("missing-or-invalid-pidfile/live-server", 0, 8001, 1, 0);
    failed += check("inspection-error", -1, 0, 1, 0);
    failed += check("verified-no-server", 0, 0, 0, 5);
    return failed ? 1 : 0;
}
'''
code = header + branch + tail
with tempfile.TemporaryDirectory(prefix='darling-missing-init-') as tmp:
    output = pathlib.Path(tmp) / 'missing-init-generated.c'
    output.write_text(code)
    print('source_sha256=' + hashlib.sha256(args.source.read_bytes()).hexdigest(), flush=True)
    print('branch_sha256=' + hashlib.sha256(branch.encode()).hexdigest(), flush=True)
    print('generated=' + str(output), flush=True)
    if args.run:
        binary = pathlib.Path(tmp) / 'identity-mock'
        subprocess.run(['cc', '-std=c11', '-Wall', '-Werror', str(output), '-o', str(binary)], check=True)
        raise SystemExit(subprocess.run([str(binary)]).returncode)
