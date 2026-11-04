#!/bin/sh
# Extracts the id-handling code of the launcher from darling.c and runs it against a simulated
# setuid-root process (no root needed): getenvTrusted, dropPrivilegesPermanently, useOriginalIds,
# restoreRootIds, the g_nonroot/setuid(0) block at the top of main(), and the block after the mount
# namespace join. Syscalls are replaced by an id-state simulation with injectable failures.
# usage: [SIM_IDS=uid:gid] [DARLING_C=path/to/darling.c] privilege-drop.sh [scratch-dir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
src=${DARLING_C:-$here/../../src/startup/darling.c}
out=${1:-${TMPDIR:-.}/privilege-drop}
mkdir -p "$out"
fn() { # extract a top-level function by its signature line
	start=$(grep -n "^$1" "$src" | head -1 | cut -d: -f1)
	[ -n "$start" ] || { echo "missing $1 in $src" >&2; exit 2; }
	awk -v s="$start" 'NR>=s {print} NR>s && /^}/ {exit}' "$src"
}
{
	fn 'static const char\* getenvTrusted'
	fn 'static bool dropPrivilegesPermanently'
	fn 'static void useOriginalIds'
	fn 'static void restoreRootIds'
} > "$out/funcs.inc"
a=$(grep -n 'g_nonroot = (' "$src" | head -1 | cut -d: -f1)
b=$(awk -v s="$a" 'NR>s && /g_rootless = \(geteuid\(\) != 0\);/ {print NR+1; exit}' "$src")
sed -n "${a},${b}p" "$src" > "$out/startup.inc"
j=$(grep -n 'joinNamespace(pidInit, CLONE_NEWNS' "$src" | cut -d: -f1)
c=$(awk -v s="$j" 'NR>s && /^#endif/ {print NR+1; exit}' "$src")
d=$(awk -v s="$c" 'NR>s && /strcmp\(argv\[1\], "toolchain"\)/ {print NR-1; exit}' "$src")
sed -n "${c},${d}p" "$src" > "$out/afterjoin.inc"
${CC:-cc} -O0 -g -Wall -Wextra -Wno-unused-function -fsanitize=address,undefined ${SIM_IDS:+-DUSER_UID=${SIM_IDS%:*} -DUSER_GID=${SIM_IDS#*:}} -I"$out" \
	-o "$out/test" "$here/privilege-drop.c"
ASAN_OPTIONS=exitcode=99 "$out/test"
