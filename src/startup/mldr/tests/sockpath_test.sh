#!/bin/sh
# Extracts process_special_env() and the server address definition from mldr.c and checks that a missing,
# empty or over-long __mldr_sockpath is refused with one error line and that a valid path is used.
# usage: [MLDR_DIR=dir-with-mldr.c] sockpath_test.sh [scratch-dir]
set -e
here=$(cd "$(dirname "$0")" && pwd)
dir=${MLDR_DIR:-$here/..}
src=$dir/mldr.c
out=${1:-${TMPDIR:-.}/sockpath_test}
mkdir -p "$out"
extract() { # $1 = first line pattern, $2 = closing line pattern
	start=$(grep -n "$1" "$src" | head -1 | cut -d: -f1)
	end=$(awk -v s="$start" -v p="$2" 'NR>s && $0 ~ p {print NR; exit}' "$src")
	sed -n "${start},${end}p" "$src"
}
extract '^struct sockaddr_un __dserver_socket_address_data = {' '^};' > "$out/extracted.inc"
extract '^static void process_special_env(struct load_results\* lr) {' '^};' >> "$out/extracted.inc"
${CC:-cc} -O0 -g -Wall -fsanitize=address,undefined -I"$out" -I"$dir" -DINSTALL_PREFIX='"/usr"' -o "$out/test" "$here/sockpath_test.c"
ASAN_OPTIONS=exitcode=99 "$out/test"
