#!/usr/bin/env python3
"""Check a demo's SwiftUI imports against a Darling-built SwiftUI library.

Use only Darling's own build outputs here, never an Apple framework binary.
"""
import argparse
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('app')
parser.add_argument('darling_library')
parser.add_argument('--nm', default='llvm-nm')
args = parser.parse_args()
imports = {line.split()[-1] for line in subprocess.check_output(
    [args.nm, '-u', args.app], text=True).splitlines()
    if line.split() and line.split()[-1].startswith('_$s7SwiftUI')}
if not imports:
    raise SystemExit('FAIL: client has no SwiftUI imports')
exports = set(subprocess.check_output(
    [args.nm, '--defined-only', '--extern-only', '--just-symbol-name', args.darling_library],
    text=True).splitlines())
missing = sorted(imports - exports)
for symbol in missing:
    print('Missing:', symbol)
print(f'SwiftUI ABI: {len(imports) - len(missing)}/{len(imports)} client imports exported')
raise SystemExit(bool(missing))
