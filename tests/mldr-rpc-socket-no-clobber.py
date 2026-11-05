#!/usr/bin/env python3
# Host test: mldr never replaces another owner's descriptor with an RPC socket
# or a lifetime pipe.
# usage: python3 tests/mldr-rpc-socket-no-clobber.py [REPO_ROOT]
# The socket bitmap, __mldr_create_rpc_socket, __mldr_create_process_lifetime_pipe,
# their close helpers and the block of setup_space that adopts an inherited
# lifetime pipe are cut out of mldr.c and built on the host. The soft
# RLIMIT_NOFILE is 64, so the slots count down from 63. A descriptor the test
# opens on a free slot stands in for a native library's fd (the kernel hands
# out the lowest free number, so a process with many fds reaches the slots);
# after each RPC socket or pipe is created it must still be the same file.
# realloc and free are wrapped with a guard after the bitmap so an
# out-of-bounds bit clear is caught without AddressSanitizer.

import os
import re
import shlex
import subprocess
import sys
import tempfile

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(root, "src/startup/mldr/mldr.c"), encoding="utf-8") as f:
    loader = f.read()

def cut(pattern, what):
    m = re.search(pattern, loader, re.M | re.S)
    if not m:
        sys.exit(f"{what} not found in mldr.c")
    return m.group(1)

types = cut(r"(typedef struct socket_bitmap \{.*?)(?=void __mldr_socket_bitmap_prefork)", "bitmap types")
funcs = cut(r"(static int socket_bitmap_get.*?^void __mldr_close_process_lifetime_pipe\(int fd\) \{.*?^\}\n)", "socket helpers")
adopt = cut(r"^\tif \(lr->lifetime_pipe != -1\) \{\n(.*?)\n\t\} else \{", "inherited lifetime pipe block")

probe = r"""#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

#define FAIL(...) do { printf("FAIL: " __VA_ARGS__); putchar('\n'); exit(1); } while (0)
#define GUARD 64
static void guard_check(void *p) {
	if (!p) return;
	unsigned char *b = p;
	size_t n = ((size_t *) b)[-2];
	for (size_t i = 0; i < GUARD; i++)
		if (b[n + i] != 0xff) FAIL("bit cleared %zu bytes past the %zu-byte bitmap", i, n);
}
static void *probe_realloc(void *p, size_t n) {
	guard_check(p);
	unsigned char *b = malloc(16 + n + GUARD);
	if (!b) return NULL;
	((size_t *) b)[0] = n;
	if (p) { size_t old = ((size_t *) p)[-2]; memcpy(b + 16, p, old < n ? old : n); free((unsigned char *) p - 16); }
	memset(b + 16 + n, 0xff, GUARD);
	return b + 16;
}
static void probe_free(void *p) { guard_check(p); if (p) free((unsigned char *) p - 16); }
#define realloc probe_realloc
#define free probe_free
static bool is_kernel_at_least(int major, int minor) { (void) major; (void) minor; return false; }
""" + types + funcs + r"""
struct load_results { int lifetime_pipe; };
static int adopt_inherited_pipe(struct load_results *lr) {
	int lifetime_pipe[2] = { -1, -1 };
""" + adopt + r"""
	return lifetime_pipe[1];
}
#undef free

static ino_t ino(int fd) { struct stat st; return fstat(fd, &st) == 0 ? st.st_ino : 0; }
static int kind(int fd) { struct stat st; return fstat(fd, &st) == 0 ? (int) (st.st_mode & S_IFMT) : -1; }
/* a descriptor owned by someone else, on exactly `slot` */
static int foreign_on(int slot) {
	int fd = open("/dev/null", O_RDONLY);
	int moved = fcntl(fd, F_DUPFD, slot);
	close(fd);
	if (moved != slot) FAIL("test setup: could not open a descriptor on %d", slot);
	return moved;
}
static void foreign_intact(int fd, const char *what) {
	if (kind(fd) != S_IFCHR) FAIL("%s replaced the descriptor held on slot %d", what, fd);
}
static void set_soft_limit(rlim_t soft) {
	struct rlimit l;
	getrlimit(RLIMIT_NOFILE, &l);
	l.rlim_cur = soft;
	if (setrlimit(RLIMIT_NOFILE, &l) != 0) FAIL("test setup: setrlimit(%lu)", (unsigned long) soft);
}

int main(void) {
	set_soft_limit(64);
	int a = __mldr_create_rpc_socket(), b = __mldr_create_rpc_socket();
	if (a != 63 || b != 62) FAIL("first sockets are %d and %d, expected 63 and 62", a, b);
	__mldr_close_rpc_socket(b); /* a thread exits: slot 62 is free again */

	/* 1. the next thread's socket must not take slot 62 from its new owner; at the
	 * 64 limit there is no free number above it, so the socket stays where it was */
	int other = foreign_on(62);
	int c = __mldr_create_rpc_socket();
	foreign_intact(other, "a new RPC socket");
	if (c < 0 || c == other || kind(c) != S_IFSOCK || !(fcntl(c, F_GETFD) & FD_CLOEXEC)) FAIL("RPC socket %d unusable", c);
	__mldr_close_rpc_socket(c);
	guard_check(socket_bitmap.bits);

	/* 2. with a raised limit it lands above the slots, and closing it leaves the bitmap alone */
	set_soft_limit(128);
	int d = __mldr_create_rpc_socket();
	foreign_intact(other, "a new RPC socket");
	if (d <= 63 || kind(d) != S_IFSOCK) FAIL("RPC socket at %d, expected above the slots", d);
	__mldr_close_rpc_socket(d);
	guard_check(socket_bitmap.bits);

	/* 3. the process lifetime pipe gets the same treatment */
	int fds[2] = { -1, -1 };
	if (__mldr_create_process_lifetime_pipe(fds) != 0) FAIL("lifetime pipe: %s", strerror(errno));
	foreign_intact(other, "the lifetime pipe");
	char ch = 'x';
	if (write(fds[1], &ch, 1) != 1 || read(fds[0], &ch, 1) != 1) FAIL("lifetime pipe %d/%d unusable", fds[0], fds[1]);
	__mldr_close_process_lifetime_pipe(fds[0]);
	__mldr_close_process_lifetime_pipe(fds[1]);

	/* 4. a lifetime pipe inherited across exec, slot held by a descriptor that survived the exec */
	int p[2];
	if (pipe(p) != 0) FAIL("pipe");
	ino_t pipe_ino = ino(p[1]);
	struct load_results lr = { p[1] };
	int adopted = adopt_inherited_pipe(&lr);
	foreign_intact(other, "the inherited lifetime pipe");
	if (adopted < 0 || ino(adopted) != pipe_ino) FAIL("inherited lifetime pipe lost (%d)", adopted);
	if (adopted != p[1] && kind(p[1]) != -1) FAIL("old lifetime pipe descriptor %d left open", p[1]);
	__mldr_close_process_lifetime_pipe(adopted);
	close(p[0]);

	/* once the owner closes it, slot 62 is used again */
	close(other);
	int e = __mldr_create_rpc_socket();
	if (e != 62) FAIL("free slot 62 not reused (got %d)", e);
	__mldr_close_rpc_socket(e);

	/* 5. a descriptor already on its slot stays there and keeps the slot */
	if (pipe(p) != 0) FAIL("pipe");
	int on_slot = fcntl(p[1], F_DUPFD, 62);
	close(p[1]);
	lr.lifetime_pipe = on_slot;
	adopted = adopt_inherited_pipe(&lr);
	if (adopted != 62 || kind(62) != S_IFIFO) FAIL("lifetime pipe on its slot moved to %d or closed", adopted);
	int f = __mldr_create_rpc_socket();
	if (f == 62 || kind(62) != S_IFIFO) FAIL("slot 62 handed out while the lifetime pipe holds it");
	__mldr_close_rpc_socket(f);
	__mldr_close_process_lifetime_pipe(adopted);
	close(p[0]);

	/* 6. a new socket whose own number is the free slot keeps working (dup2(fd, fd)
	 * returned it and the close that followed closed the socket) */
	int filler[64], n = 0, lowest;
	while ((lowest = open("/dev/null", O_RDONLY)) < 62) filler[n++] = lowest;
	close(lowest);
	int g = __mldr_create_rpc_socket();
	if (g < 0 || kind(g) != S_IFSOCK) FAIL("RPC socket created on its own slot is unusable (%d)", g);
	__mldr_close_rpc_socket(g);
	while (n) close(filler[--n]);

	__mldr_close_rpc_socket(a);
	guard_check(socket_bitmap.bits);
	puts("PASS: RPC sockets and lifetime pipes leave other descriptors alone");
	return 0;
}
"""

with tempfile.TemporaryDirectory(prefix="mldr-no-clobber-") as tmp:
    src, exe = os.path.join(tmp, "probe.c"), os.path.join(tmp, "probe")
    with open(src, "w", encoding="utf-8") as f:
        f.write(probe)
    cc = shlex.split(os.environ.get("CC", "clang"))
    subprocess.check_call(cc + ["-pthread", "-fsanitize=undefined", "-fno-sanitize-recover=undefined", "-w", src, "-o", exe])
    run = subprocess.run([exe], stdout=subprocess.PIPE, text=True)
    print(run.stdout.strip() or f"probe died with status {run.returncode}")
    if run.returncode != 0:
        sys.exit("mldr RPC socket clobber regression")
