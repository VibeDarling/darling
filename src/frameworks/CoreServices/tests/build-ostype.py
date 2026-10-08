"""Build actual OSType conversion definitions without the unrelated FMDB stack.

Run under the shared heavy-build flock. Requires pinned Darling headers and an
immutable guest runtime. Only generated extraction/object/executable files go
in build-dir; nothing is installed. Run ostype with create, decode, indirect.
"""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--source-root', required=True, type=Path)
parser.add_argument('--runtime-root', required=True, type=Path)
parser.add_argument('--build-dir', required=True, type=Path)
parser.add_argument('--linker', required=True, type=Path)
args = parser.parse_args()
source = args.source_root.resolve()
runtime = args.runtime_root.resolve()
output = args.build_dir.resolve()
output.mkdir(parents=True, exist_ok=True)
component = source / 'src/frameworks/CoreServices'
text = (component / 'src/LaunchServices/UTType.m').read_text()
start = text.index('CFStringRef\nUTCreateStringForOSType(')
functions = text[start:]
if functions.count('\nUTCreateStringForOSType(') != 1 or functions.count('\nUTGetOSTypeFromString(') != 1:
    raise SystemExit('unexpected OSType source layout')
(output / 'ostype-functions.c').write_text('#include <CoreFoundation/CFURL.h>\n#include <LaunchServices/UTType.h>\n' + functions)
resource = subprocess.check_output(['clang', '-print-resource-dir'], text=True).strip()
flags = ['clang', '-target', 'aarch64-apple-darwin20', '-nostdinc',
         '-isystem', resource + '/include', '-D__APPLE__', '-D__MACH__',
         '-D_DARWIN_C_SOURCE', '-DTARGET_OS_MAC=1', '-DDARWIN', '-DDARLING',
         '-D_LIBC_NO_FEATURE_VERIFICATION', '-fblocks', '-Wno-nullability-completeness']
for directory in ('basic-headers',
                  'Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include',
                  'framework-include', 'src/external/corefoundation/include'):
    flags += ['-I' + str(source / directory)]
commands = []


def run(command):
    command = [str(value) for value in command]
    commands.append(command)
    (output / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    subprocess.run(command, check=True)


for name, path in [('functions', output / 'ostype-functions.c'), ('test', component / 'tests/ostype.c')]:
    run(flags + ['-MD', '-MF', output / (name + '.d'), '-c', path, '-o', output / (name + '.o')])
run(flags + ['-I' + str(source / 'src/external/foundation/include'),
             '-I' + str(source / 'src/external/fmdb/src'),
             '-MD', '-MF', output / 'UTType.d', '-c',
             component / 'src/LaunchServices/UTType.m', '-o', output / 'UTType.o'])
link = ['clang', '-target', 'aarch64-apple-darwin20', '-nostdlib',
        '-fuse-ld=' + str(args.linker.resolve()), '-Wl,-platform_version,macos,11.0,11.0']
for path in sorted(runtime.rglob('*')):
    if path.is_file() and (path.suffix == '.dylib' or path.name + '.framework' in path.parts):
        guest = '/' + str(path.relative_to(runtime))
        link += ['-Wl,-dylib_file,' + guest + ':' + str(path)]
run(link + ['-o', output / 'ostype', output / 'functions.o', output / 'test.o',
            runtime / 'System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation',
            runtime / 'usr/lib/libSystem.B.dylib'])
