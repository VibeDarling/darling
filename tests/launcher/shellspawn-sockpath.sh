#!/bin/sh
# Extracts the USE_LINUX_4_11_HACK branch of connectToShellspawn() from darling.c and checks how it builds
# the shellspawn socket path in sun_path for long prefixes.
# usage: [DARLING_C=path/to/darling.c] shellspawn-sockpath.sh [scratch-dir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
src=${DARLING_C:-$here/../../src/startup/darling.c}
out=${1:-${TMPDIR:-.}/shellspawn-sockpath}
mkdir -p "$out"
fn=$(grep -n '^int connectToShellspawn(void)' "$src" | cut -d: -f1)
start=$(awk -v s="$fn" 'NR>s && /^#if USE_LINUX_4_11_HACK/ {print NR; exit}' "$src")
end=$(awk -v s="$start" 'NR>s && /^#else/ {print NR; exit}' "$src")
sed -n "$((start + 1)),$((end - 1))p" "$src" > "$out/extracted.inc"
${CC:-cc} -O0 -g -Wall -fsanitize=address,undefined -DSHELLSPAWN_SOCKPATH='"/var/run/shellspawn.sock"' -I"$out" \
	-o "$out/test" "$here/shellspawn-sockpath.c"
# ASan exits 1 by default, which the test would mistake for the loud exit(1) it expects
ASAN_OPTIONS=exitcode=99 "$out/test"
