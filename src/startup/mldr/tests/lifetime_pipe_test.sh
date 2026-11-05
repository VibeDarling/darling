#!/bin/sh
# Extracts the socket bitmap, __mldr_create_process_lifetime_pipe and the lifetime-pipe branch of
# setup_space from mldr.c, then runs them with pipe() and getrlimit() failing.
# usage: lifetime_pipe_test.sh [mldr.c] [scratch-dir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
src=${1:-$here/../mldr.c}
out=${2:-${TMPDIR:-.}/lifetime_pipe_test}
mkdir -p "$out"
a=$(grep -n '^typedef struct socket_bitmap' "$src" | cut -d: -f1)
b=$(grep -n '^int __mldr_create_rpc_socket' "$src" | cut -d: -f1)
c=$(grep -n '^int __mldr_create_process_lifetime_pipe' "$src" | cut -d: -f1)
d=$(grep -n '^void __mldr_close_process_lifetime_pipe' "$src" | cut -d: -f1)
{ sed -n "${a},$((b-1))p" "$src"; sed -n "${c},$((d-1))p" "$src"; } > "$out/extracted.inc"
s=$(grep -n 'if (lr->lifetime_pipe != -1) {' "$src" | head -n 1 | cut -d: -f1)
e=$(awk -v s="$s" 'NR>s && /lifetime_pipe\[0\] = -1;/ {print NR; exit}' "$src")
{ sed -n "${s},${e}p" "$src"; echo "}"; } > "$out/branch.inc"
# zero-init makes the uninitialised pre_fds[] read as descriptor 0 (stdin), deterministically.
${CC:-cc} -O0 -g -Wall -fsanitize=address,undefined -ftrivial-auto-var-init=zero \
	-I"$out" -o "$out/test" "$here/lifetime_pipe_test.c"
"$out/test"
