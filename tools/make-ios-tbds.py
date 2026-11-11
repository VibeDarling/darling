#!/usr/bin/env python3
"""make-ios-tbds.py ROOT SDK: text stubs (.tbd) of a Darling install's libraries, for linking iOS
code against Darling with an iOS deployment target.

ROOT is Darling's installed tree (.../libexec/darling). Every Mach-O library under usr/lib and every
framework's binary gets a .tbd at the same path under SDK, with its macOS targets also offered as iOS
ones: Darling serves iOS apps from these same images, but ld64.lld refuses to link an iOS target
against a library built for macOS.
"""
import json, os, subprocess, sys, tempfile

root, sdk = sys.argv[1:3]
MACHO = (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca')

def is_dylib(path):
    try:
        with open(path, 'rb') as f:
            return f.read(4) in MACHO
    except OSError:
        return False

def candidates():
    for top in ('usr/lib', 'System/Library/Frameworks', 'System/Library/PrivateFrameworks',
                'System/iOSSupport/System/Library/Frameworks'):
        base = os.path.join(root, top)
        for dirpath, dirs, files in os.walk(base):
            # A framework's binary is in Versions/<v>/; the top-level names are symlinks.
            dirs[:] = [d for d in dirs if not d.endswith(('.app', '.bundle', '.plugin', 'Resources', 'Headers'))]
            for name in files:
                path = os.path.join(dirpath, name)
                if os.path.islink(path) or os.path.splitext(name)[1] not in ('', '.dylib'):
                    continue
                if is_dylib(path):
                    yield path

def ios(target):
    arch, _, platform = target.partition('-')
    return f'{arch}-ios' if platform == 'macos' else None

def real_dirs(path):
    """Make every directory from SDK down to PATH a real one: the SDK links to the macOS SDK's
    directories, which must not be written into. A linked directory becomes a directory of links
    to its entries."""
    rel = os.path.relpath(path, sdk)
    cur = sdk
    for part in [] if rel == '.' else rel.split(os.sep):
        cur = os.path.join(cur, part)
        if os.path.islink(cur):
            target = os.path.realpath(cur)
            os.unlink(cur)
            os.mkdir(cur)
            if os.path.isdir(target):
                for entry in os.listdir(target):
                    if not is_dylib(os.path.join(target, entry)):  # macOS binaries: stubs instead
                        os.symlink(os.path.join(target, entry), os.path.join(cur, entry))
        elif not os.path.exists(cur):
            os.mkdir(cur)

made = failed = 0
with tempfile.TemporaryDirectory() as tmp:
    out = os.path.join(tmp, 'x.tbd')
    for path in candidates():
        r = subprocess.run(['llvm-readtapi', '--stubify', '--filetype=tbd-v5', path, '-o', out],
                           capture_output=True)
        if r.returncode != 0:
            failed += 1
            continue
        data = json.load(open(out))
        if data.get('main_library', {}).get('install_names') is None:
            continue
        for lib in [data['main_library']] + data.get('libraries', []):
            extra = []
            for t in lib.get('target_info', []):
                if ios(t['target']):
                    extra.append(dict(t, target=ios(t['target']), min_deployment='9.0'))
            lib['target_info'] = lib.get('target_info', []) + extra
            # Symbols and re-exports name their targets; offer the iOS ones the same.
            for key in ('exported_symbols', 'reexported_symbols', 'undefined_symbols',
                        'reexported_libraries', 'allowable_clients', 'parent_umbrellas', 'rpaths'):
                for entry in lib.get(key, []):
                    if 'targets' in entry:
                        entry['targets'] += [ios(t) for t in entry['targets'] if ios(t)]
        name = data['main_library']['install_names'][0]['name']
        if not name.startswith('/'):
            name = '/usr/lib/' + os.path.basename(name)  # @rpath Swift libraries
        dest = sdk + os.path.splitext(name)[0] + '.tbd'
        real_dirs(os.path.dirname(dest))
        # The linker would take the macOS binary (or the SDK's link to one) over the stub.
        for other in (os.path.splitext(dest)[0], os.path.splitext(dest)[0] + '.dylib'):
            if os.path.lexists(other):
                os.unlink(other)
        json.dump(data, open(dest, 'w'))
        made += 1
# Libraries that are links to others (libm, libc, libpthread -> libSystem.B on Darwin): the same stub
# under the link's name.
links = 0
for dirpath, dirs, files in os.walk(os.path.join(root, 'usr/lib')):
    for name in files:
        path = os.path.join(dirpath, name)
        if not os.path.islink(path) or not name.endswith('.dylib'):
            continue
        target = os.path.realpath(path)
        if not target.startswith(os.path.realpath(root)) or not is_dylib(target):
            continue
        rel_link = os.path.relpath(path, root)
        rel_target = os.path.relpath(target, os.path.realpath(root))
        stub = os.path.join(sdk, os.path.splitext(rel_target)[0] + '.tbd')
        alias = os.path.join(sdk, os.path.splitext(rel_link)[0] + '.tbd')
        if os.path.exists(stub) and not os.path.lexists(alias):
            real_dirs(os.path.dirname(alias))
            os.symlink(os.path.relpath(stub, os.path.dirname(alias)), alias)
            links += 1
print(f'{links} linked library names')

# The names the linker looks up: -lX finds libX.tbd (libSystem.B -> libSystem, libc++.1 -> libc++),
# -framework X finds X.framework/X.tbd (the binary is in Versions/<v>/).
aliases = 0
for dirpath, dirs, files in os.walk(sdk):
    for name in files:
        if not name.endswith('.tbd'):
            continue
        stem = name[:-4]
        short = None
        if name.startswith('lib') and '.' in stem:
            short = stem.split('.')[0] + '.tbd'
        parts = dirpath.split(os.sep)
        if len(parts) >= 3 and parts[-2] == 'Versions' and parts[-3] == stem + '.framework':
            short = os.path.join('..', '..', name)
        if short:
            link = os.path.normpath(os.path.join(dirpath, short))
            if not os.path.lexists(link):
                os.symlink(os.path.relpath(os.path.join(dirpath, name), os.path.dirname(link)), link)
                aliases += 1
print(f'{made} library stubs, {aliases} short names ({failed} images not readable)')
