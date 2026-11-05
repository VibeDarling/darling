#!/bin/sh
# Extracts vchroot_unexpand_interpreter from mldr.c and checks its path-length bound.
# usage: [MLDR_DIR=dir-with-mldr.c-and-loader.h] startup_bounds_test.sh [scratch-dir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
dir=${MLDR_DIR:-$here/..}
src=$dir/mldr.c
out=${1:-${TMPDIR:-.}/startup_bounds_test}
mkdir -p "$out"
start=$(grep -n '^static void vchroot_unexpand_interpreter(struct load_results\* lr) {' "$src" | cut -d: -f1)
end=$(awk -v s="$start" 'NR>s && /^}/ {print NR; exit}' "$src")
sed -n "${start},${end}p" "$src" > "$out/extracted.inc"
${CC:-cc} -O0 -g -Wall -fsanitize=address,undefined -I"$out" -I"$dir" -o "$out/test" "$here/startup_bounds_test.c"
# ASan exits 1 by default, which the tests would mistake for the loud exit(1) they expect
ASAN_OPTIONS=exitcode=99 "$out/test"
