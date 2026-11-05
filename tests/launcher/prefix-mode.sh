#!/bin/sh
# Extracts createDir(), setupPrefix() and checkPrefixOwner() from darling.c and checks the mode of the
# prefix root they create and accept. The ensure*() helpers are stubbed; everything runs unprivileged.
# usage: [DARLING_C=path/to/darling.c] prefix-mode.sh [scratch-dir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
src=${DARLING_C:-$here/../../src/startup/darling.c}
out=${1:-${TMPDIR:-.}/prefix-mode}
mkdir -p "$out"
fn() {
	start=$(grep -n "^$1" "$src" | grep -v ";\$" | head -1 | cut -d: -f1)
	[ -n "$start" ] || { echo "missing $1 in $src" >&2; exit 2; }
	awk -v s="$start" 'NR>=s {print} NR>s && /^}/ {exit}' "$src"
}
{ fn 'void createDir'; fn 'void setupPrefix'; fn 'void checkPrefixOwner'; } > "$out/funcs.inc"
${CC:-cc} -O0 -g -Wall -Wextra -Wno-unused-parameter -fsanitize=address,undefined -I"$out" \
	-o "$out/test" "$here/prefix-mode.c"
# a fresh work dir per run: a leftover prefix would make setupPrefix() skip the chmod
work=$(mktemp -d "$out/work.XXXXXX")
ASAN_OPTIONS=exitcode=99 "$out/test" "$work"
