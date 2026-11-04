#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description='Build the independent Symbols source candidate without installing it.')
for name in ('swiftc', 'clang', 'sdk', 'resources', 'guest-root', 'target', 'minimum-os', 'module-triple', 'output'):
    parser.add_argument('--' + name, required=True)
parser.add_argument('--enable-testing', action='store_true')
args = parser.parse_args()
for value in (args.swiftc, args.clang, args.sdk, args.resources, args.guest_root):
    if not Path(value).exists():
        parser.error('Required input does not exist: ' + value)
output = Path(args.output).resolve()
if output == Path('/tmp') or Path('/tmp') in output.parents:
    parser.error('Use a durable output directory outside /tmp')
if output.exists():
    parser.error('Output must be a new directory: ' + str(output))
if '/' in args.module_triple or args.module_triple in ('.', '..'):
    parser.error('Invalid module triple')
version = output / 'Symbols.framework/Versions/A'
modules = version / 'Modules/Symbols.swiftmodule'
modules.mkdir(parents=True)
source = Path(__file__).resolve().parent / 'src/Symbols.swift'
obj = output / 'Symbols.o'
compile_command = [args.swiftc, '-frontend', '-c', str(source), '-target', args.target,
    '-sdk', args.sdk, '-resource-dir', args.resources, '-module-cache-path', str(output / 'cache'),
    '-swift-version', '5', '-module-name', 'Symbols', '-enable-library-evolution',
    '-emit-module-path', str(modules / (args.module_triple + '.swiftmodule')),
    '-emit-module-interface-path', str(modules / (args.module_triple + '.swiftinterface')),
    '-o', str(obj)]
if args.enable_testing:
    compile_command.append('-enable-testing')
link_command = [args.clang, '-target', args.target, '-fuse-ld=lld', '-nostdlib', '-dynamiclib',
    '-Wl,-syslibroot,' + args.guest_root, '-Wl,-platform_version,macos,' + args.minimum_os + ',' + args.minimum_os,
    '-Wl,-install_name,/System/Library/Frameworks/Symbols.framework/Versions/A/Symbols',
    '-L' + str(Path(args.guest_root) / 'usr/lib/swift'), '-L' + str(Path(args.guest_root) / 'usr/lib'),
    str(obj), '-lSystem', '-lswiftCore', '-o', str(version / 'Symbols')]
(output / 'commands.json').write_text(json.dumps([compile_command, link_command], indent=2) + '\n')
for index, command in enumerate((compile_command, link_command)):
    with (output / (str(index) + '.log')).open('w') as log:
        subprocess.run(command, check=True, stdout=log, stderr=log)
(version.parent / 'Current').symlink_to('A')
for name in ('Symbols', 'Modules'):
    (version.parent.parent / name).symlink_to('Versions/Current/' + name)
print(version.parent.parent)
