#!/usr/bin/env python3
"""Own isolated CoreData fixture prefix; never expose guest standard streams."""
import argparse
import hashlib
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base', required=True, type=Path)
parser.add_argument('--prepare-from', type=Path)
parser.add_argument('--case', choices=['bootstrap', 'shutdown', 'swift', 'memory', 'protocol', 'inherited', 'create', 'reopen', 'integrity', 'readonly', 'change', 'changed', 'retry', 'retried', 'errors', 'stale-delete', 'writers'])
parser.add_argument('--data-name', default='durability.sqlite')
args = parser.parse_args()
base = args.base.resolve()
if base.name != 'feather-sqlite-impl-20261103' or not re.fullmatch(r'[a-zA-Z0-9_.-]+', args.data_name):
    raise SystemExit('OWN_BASE_OR_DATA_NAME_REQUIRED')
marker = base/'sqlite-worker-control-20261103'
overlay_hash = 'aebf3c00041c5e27b2a8620b4f8fa840fc5af2edb109b356a546c5596d083b98'

def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

if args.prepare_from:
    source = args.prepare_from.resolve()
    if source.name != 'feather-clean-impl-20261103' or base.exists():
        raise SystemExit('FRESH_OWN_COPY_REQUIRED')
    base.mkdir(mode=0o700)
    for name in ('runtime', 'native'):
        shutil.copytree(source/name, base/name, symlinks=True)
        print(json.dumps({'copy': name, 'complete': True}), flush=True)
    (base/'diagnostic-payload').mkdir()
    shutil.copyfile(source/'diagnostic-payload/manifest.json', base/'diagnostic-payload/manifest.json')
    (base/'cache/shm').mkdir(parents=True)
    (base/'fixtures').mkdir()
    (base/'data').mkdir()
    temporary = base/'runtime/libexec/darling/private/tmp'
    if not temporary.is_symlink():
        raise SystemExit('EXPECTED_PRIVATE_TMP_SYMLINK')
    temporary.unlink()
    temporary.symlink_to(base/'cache')
    marker.write_text('owned CoreData fixture prefix\n')
    print('OWN_RUNTIME_COPY_READY', flush=True)
if not marker.is_file():
    raise SystemExit('OWN_BASE_MARKER_REQUIRED')
operator_lock = (base/'.coredata-operator.lock').open('a')
fcntl.flock(operator_lock, fcntl.LOCK_EX)
active = base/'active-fixture.json'
if active.exists():
    raise SystemExit('ACTIVE_FIXTURE_REQUIRES_EXACT_HANDLE_AUDIT')
manifest = json.loads((base/'diagnostic-payload/manifest.json').read_text())
components = manifest['components']
for component in components.values():
    relative = Path(component['relative'])
    if relative.is_absolute() or '..' in relative.parts or not re.fullmatch(r'[a-f0-9]{64}', component['sha256']):
        raise SystemExit('COMPONENT_MANIFEST_REJECTED')

def verify(root):
    for component in components.values():
        if digest(root/component['relative']) != component['sha256']:
            raise SystemExit('COMPONENT_IDENTITY_MISMATCH')
    if digest(root/'usr/lib/swift/libswiftFoundation.dylib') != overlay_hash:
        raise SystemExit('OVERLAY_IDENTITY_MISMATCH')

verify(base/'runtime/libexec/darling')
if not args.case:
    raise SystemExit(0)
environment = os.environ.copy()
for key in list(environment):
    if key.startswith('DYLD_') or key in ('DARLING_BOUNDARY_SOCKET', 'DARLING_STRICT_LINKING'):
        environment.pop(key)
environment.update(DARLING_INSTALL_PREFIX=str(base/'runtime'), DPREFIX=str(base/'prefix'),
    DARLING_MLDR_PATH=str(base/'native/libmldr.so'), DARLING_SERVER_PATH=str(base/'native/libdarlingserver.so'),
    LD_LIBRARY_PATH=str(base/'native'), DARLING_SHM_DIR=str(base/'cache/shm'),
    DARLING_NO_CORE_DUMPS='1', TMPDIR=str(base/'cache'))
if args.case == 'bootstrap':
    if (base/'prefix').exists():
        raise SystemExit('FRESH_PREFIX_REQUIRED')
    command = [str(base/'native/libdarling.so'), 'shell', '/bin/test', '-f', '/clean-release-control-20261103']
elif args.case == 'shutdown':
    if not (base/'prefix/clean-release-control-20261103').is_file():
        raise SystemExit('OWN_PREFIX_MARKER_REQUIRED')
    verify(base/'prefix')
    command = [str(base/'native/libdarling.so'), 'shutdown']
else:
    if not (base/'prefix/clean-release-control-20261103').is_file():
        raise SystemExit('OWN_PREFIX_MARKER_REQUIRED')
    verify(base/'prefix')
    data = '/Volumes/SystemRoot'+str(base/'data'/args.data_name)
    binary = {'protocol': 'COREDATA_FETCH_RESULT_PROTOCOL', 'swift': 'COREDATA_MANAGED_SWIFT', 'memory': 'COREDATA_MEMORY_NIL', 'inherited': 'COREDATA_INHERITED_ACCESSORS', 'errors': 'COREDATA_STORE_ERRORS', 'writers': 'COREDATA_WRITERS', 'stale-delete': 'COREDATA_WRITERS'}.get(args.case, 'COREDATA_DURABILITY_STAGED')
    parameters = [] if args.case in ('swift', 'inherited', 'protocol') else ([data] if args.case in ('errors', 'memory') else [args.case, data])
    command = [str(base/'native/libdarling.so'), 'shell', '/Volumes/SystemRoot'+str(base/'fixtures'/binary), *parameters]
active.write_text(json.dumps({'case': args.case, 'launcherPid': None})+'\n')
process = subprocess.Popen(command, env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
active.write_text(json.dumps({'case': args.case, 'launcherPid': process.pid})+'\n')
print(json.dumps({'case': args.case, 'launcherPid': process.pid, 'phase': 'launched'}), flush=True)
notice = time.monotonic()+30
while process.poll() is None:
    time.sleep(0.1)
    if time.monotonic() >= notice:
        print(json.dumps({'case': args.case, 'launcherPid': process.pid, 'running': True}), flush=True)
        notice += 30
if args.case == 'bootstrap' and process.returncode == 0:
    verify(base/'prefix')
report = {'case': args.case, 'exit': process.returncode, 'source': manifest['source'], 'components': components}
report_text = json.dumps(report, indent=2)+'\n'
(base/('result-'+args.case+'-'+str(process.pid)+'.json')).write_text(report_text)
(base/('result-'+args.case+'.json')).write_text(report_text)
active.unlink()
print(json.dumps({'case': args.case, 'exit': process.returncode, 'identityVerified': True}), flush=True)
raise SystemExit(0 if process.returncode == 0 else 1)
