#!/usr/bin/env python3
"""
Host test: the sandbox stubs fail honestly and tolerate a NULL errorbuf.
usage: python3 tests/sandbox-honest-failure.py [REPO_ROOT]
libsandbox's sandbox.c and the sandbox library's sandbox.c are built unmodified.
Compiling or applying a profile must report failure with a message; the
*_init entry points must not crash on a NULL errorbuf and must set *errorbuf = NULL
on success; sandbox_free_params stays exported. A stand-in mach/message.h supplies audit_token_t.
"""

import os
import sys
import tempfile
import subprocess

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with tempfile.TemporaryDirectory(prefix="sandbox-") as tmpdir:
    mach_dir = os.path.join(tmpdir, "mach")
    os.makedirs(mach_dir, exist_ok=True)
    with open(os.path.join(mach_dir, "message.h"), "w") as f:
        f.write("typedef struct { unsigned int val[8]; } audit_token_t;\n")

    probe_c = os.path.join(tmpdir, "probe.c")
    with open(probe_c, "w") as f:
        f.write(r"""#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* the two libraries declare overlapping names; declare only what is used */
int sandbox_init(const char *, uint64_t, char **);
int sandbox_init_with_parameters(const char *, uint64_t, const char *const[], char **);
int sandbox_init_with_extensions(const char *, uint64_t, const char *const[], char **);
int sandbox_wakeup_daemon(char **);
void sandbox_free_error(char *);
void *sandbox_compile_string(const char *, void *, char **);
void *sandbox_compile_file(const char *, void *, char **);
int sandbox_apply(void *);
void sandbox_free_params(void *);
void sandbox_free_profile(void *);

int main(void) {
    char *err = NULL;

    /* a NULL errorbuf used to be dereferenced */
    /* return 0 is deliberate: guest helpers that ignore the error must keep running */
    assert(sandbox_init("p", 0, NULL) == 0);
    assert(sandbox_init_with_parameters("p", 0, NULL, NULL) == 0);
    assert(sandbox_init_with_extensions("p", 0, NULL, NULL) == 0);
    assert(sandbox_wakeup_daemon(NULL) == -1);

    /* on success (return 0), *errorbuf must be set to NULL (no leak, no misleading error) */
    /* set err to a sentinel non-NULL pointer to verify that *errorbuf is actively cleared */
    err = (char *)0x1234;
    assert(sandbox_init("p", 0, &err) == 0);
    assert(err == NULL);

    err = (char *)0x1234;
    assert(sandbox_init_with_parameters("p", 0, NULL, &err) == 0);
    assert(err == NULL);

    err = (char *)0x1234;
    assert(sandbox_init_with_extensions("p", 0, NULL, &err) == 0);
    assert(err == NULL);

    /* on failure (return -1), sandbox_wakeup_daemon sets an error string */
    assert(sandbox_wakeup_daemon(&err) == -1);
    assert(err != NULL && !strcmp(err, "Not implemented"));
    sandbox_free_error(err);
    err = NULL;

    /* compiling reports failure and why; the caller's params are never written */
    void *params = (void *)0x1234;
    assert(sandbox_compile_string("(version 1)", params, &err) == NULL);
    assert(err && strstr(err, "not supported"));
    free(err);
    err = NULL;

    assert(sandbox_compile_file("/nonexistent", params, &err) == NULL);
    assert(err && strstr(err, "not supported"));
    free(err);
    err = NULL;

    assert(sandbox_compile_string("(version 1)", NULL, NULL) == NULL);

    /* applying never claims a sandbox is in force */
    assert(sandbox_apply(NULL) != 0);
    sandbox_free_params(NULL);
    sandbox_free_profile(NULL);

    puts("PASS: sandbox stubs fail honestly");
    return 0;
}
""")

    probe_bin = os.path.join(tmpdir, "probe")
    compile_cmd = [
        "clang",
        "-fsanitize=address,undefined",
        "-fno-sanitize-recover=undefined",
        "-w",
        "-D_GNU_SOURCE",
        "-D__APPLE_API_PRIVATE",
        f"-I{tmpdir}",
        f"-I{root}/src/libsandbox/include",
        probe_c,
        f"{root}/src/libsandbox/src/sandbox.c",
        f"{root}/src/sandbox/sandbox.c",
        f"-I{root}/src/sandbox",
        "-o",
        probe_bin,
    ]
    res = subprocess.run(compile_cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stderr, file=sys.stderr)
        sys.exit(1)

    run_res = subprocess.run([probe_bin], capture_output=True, text=True)
    if run_res.returncode != 0:
        if run_res.stdout:
            print(run_res.stdout, file=sys.stderr)
        if run_res.stderr:
            print(run_res.stderr, file=sys.stderr)
        sys.exit(1)

    print(run_res.stdout.strip())
