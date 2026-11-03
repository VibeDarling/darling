#!/usr/bin/env python3
"""Verify effective Foundation reexport and typed bridging on an owned prefix."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base', type=Path, required=True)
parser.add_argument('--control', type=Path, required=True)
parser.add_argument('--control-sha256', required=True)
parser.add_argument('--report', type=Path, required=True)
args = parser.parse_args()
base = args.base.resolve()
prefix = base/'prefix'
manifest = json.loads((base/'diagnostic-payload/manifest.json').read_text())
component = manifest['components']['Foundation']
target = prefix/component['relative']
def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()
for root in (prefix, base/'runtime/libexec/darling'):
    if not (root/'clean-release-control-20261103').is_file():
        raise SystemExit('OWN_ROOT_MARKER_REQUIRED')
    for item in manifest['components'].values():
        if digest(root/item['relative']) != item['sha256']:
            raise SystemExit('COMPONENT_IDENTITY_MISMATCH')
    if digest(root/'usr/lib/swift/libswiftFoundation.dylib') != manifest['swift_foundation_overlay_sha256']:
        raise SystemExit('OVERLAY_IDENTITY_MISMATCH')
if digest(args.control) != args.control_sha256:
    raise SystemExit('CONTROL_IDENTITY_MISMATCH')
spec = importlib.util.spec_from_file_location('owned_protocol', Path(__file__).with_name('test-boundary-diagnostics.py'))
protocol = importlib.util.module_from_spec(spec)
spec.loader.exec_module(protocol)
env = os.environ.copy()
for key in list(env):
    if key.startswith('DYLD_') or key in ('DARLING_BOUNDARY_SOCKET', 'DARLING_STRICT_LINKING'):
        env.pop(key)
env.update(DARLING_INSTALL_PREFIX=str(base/'runtime'), DPREFIX=str(prefix),
           DARLING_MLDR_PATH=str(base/'native/libmldr.so'), DARLING_SERVER_PATH=str(base/'native/libdarlingserver.so'),
           LD_LIBRARY_PATH=str(base/'native'), DARLING_SHM_DIR=str(base/'cache/shm'),
           DARLING_NO_CORE_DUMPS='1', TMPDIR=str(base/'cache'))
reports = []
with tempfile.TemporaryDirectory(prefix='fcl-', dir=Path.home()/'.cache') as temporary:
    directory = Path(temporary)
    original = directory/'original'
    shutil.copyfile(target, original)
    def install(source, expected):
        stage = target.with_name('Foundation.authored-reexport-stage')
        shutil.copyfile(source, stage)
        stage.chmod(0o755)
        if digest(stage) != expected:
            raise RuntimeError('STAGE_IDENTITY_MISMATCH')
        os.replace(stage, target)
        if digest(target) != expected:
            raise RuntimeError('SELECTED_IDENTITY_MISMATCH')
    endpoint = directory/'s'
    mapped = '/Volumes/SystemRoot'+str(endpoint)
    if len(mapped.encode()) > 80:
        raise SystemExit('ENDPOINT_TOO_LONG')
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as receiver:
        receiver.bind(str(endpoint))
        endpoint.chmod(0o600)
        receiver.settimeout(0.02)
        def drain():
            values = []
            for batch_index in range(256):
                try:
                    packet = receiver.recv(1025)
                except socket.timeout:
                    return values
                if not protocol.permitted(packet):
                    raise RuntimeError('PROTOCOL_REJECTED')
                values.append(packet.decode('ascii'))
            return values
        def run(label, binary, expected_exit, expected_records, selected_hash):
            if digest(target) != selected_hash:
                raise RuntimeError('SELECTED_IDENTITY_MISMATCH')
            process = subprocess.Popen([str(base/'native/libdarling.so'), 'shell', 'env',
                'DARLING_BOUNDARY_SOCKET='+mapped, '/Volumes/SystemRoot'+str(base/'diag-fixtures'/binary)],
                env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(json.dumps({'case':label, 'launcherPid':process.pid}), flush=True)
            records = []
            notice = time.monotonic()+60
            while process.poll() is None:
                records += drain()
                if time.monotonic() >= notice:
                    print(json.dumps({'case':label, 'running':True, 'recordsReceived':len(records)}), flush=True)
                    notice += 60
            records += drain()
            row = {'case':label, 'selectedFoundationSha256':selected_hash, 'exit':process.returncode,
                   'expectedExit':expected_exit, 'exactRecords':records == expected_records, 'records':records}
            reports.append(row)
            args.report.write_text(json.dumps({'source':manifest['source'], 'overlaySha256':manifest['swift_foundation_overlay_sha256'], 'cases':reports}, indent=2)+'\n')
            print(json.dumps({'case':label, 'exit':row['exit'], 'exactRecords':row['exactRecords']}), flush=True)
        try:
            install(args.control, args.control_sha256)
            run('lookup-no-reexport', 'LOOKUP', 96, ['diag.ready\n'], args.control_sha256)
            install(original, component['sha256'])
            run('lookup-reexport', 'LOOKUP', 0, ['diag.ready\n', 'foundation.overlay.lookup.success\n'], component['sha256'])
            run('typed-swift-bridge', 'BRIDGE', 0, ['diag.ready\n', 'foundation.overlay.bridge.success\n'], component['sha256'])
        finally:
            install(original, component['sha256'])
            print('OWN_PREFIX_FOUNDATION_RESTORED', flush=True)
valid = all(row['exit'] == row['expectedExit'] and row['exactRecords'] for row in reports)
print('PASS_FOUNDATION_REEXPORT_RUNTIME' if valid else 'FAIL_FOUNDATION_REEXPORT_RUNTIME', flush=True)
raise SystemExit(0 if valid else 1)
