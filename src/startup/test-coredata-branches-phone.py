#!/usr/bin/env python3
"""Check authored store-load outcomes using only the dedicated validated protocol."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base', type=Path, required=True)
parser.add_argument('--report', type=Path, required=True)
parser.add_argument('--reason-events', action='store_true')
parser.add_argument('--overlay-fixtures', action='store_true')
args = parser.parse_args()
base = args.base.resolve()
prefix = base/'prefix'
if not (prefix/'clean-release-control-20261103').is_file():
    raise SystemExit('OWN_PREFIX_MARKER_REQUIRED')
manifest = json.loads((base/'diagnostic-payload/manifest.json').read_text())
for root in (prefix, base/'runtime/libexec/darling'):
    for component in manifest['components'].values():
        with (root/component['relative']).open('rb') as source:
            if hashlib.file_digest(source, 'sha256').hexdigest() != component['sha256']:
                raise SystemExit('COMPONENT_IDENTITY_MISMATCH')
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
ready = 'diag.ready\n'
common = ['coredata.store-description.init.enter\n', 'coredata.store-description.init.ok\n',
          'coredata.container.init.enter\n', 'coredata.context.init.enter\n', 'coredata.context.init.ok\n',
          'coredata.store-description.init.enter\n', 'coredata.store-description.init.ok\n']
cases = [('model', ['model-error']), ('sqlite', ['unsupported-sqlite']), ('unknown', ['unsupported-type']),
         ('nonfile', ['nonfile-url']), ('readonly', ['readonly-missing']), ('directory', ['directory-error']),
         ('memory', ['coordinator-enter']), ('coordinator-error', ['coordinator-enter', 'coordinator-error']),
         ('coordinator-empty', ['coordinator-enter', 'coordinator-empty-error']),
         ('coordinator-exception', ['coordinator-enter', 'coordinator-exception']),
         ('coordinator-success-error', ['coordinator-enter'])]
expected = [ready]
for case, reasons in cases:
    expected += common+['coredata.container.init.'+('model-error' if case == 'model' else 'ok')+'\n',
                        'coredata.container.load.enter\n']
    if args.reason_events:
        expected += ['coredata.container.load.'+reason+'\n' for reason in reasons]
    expected += ['coredata.container.load.'+('success' if case == 'memory' else 'error')+'\n']
reports = []
with tempfile.TemporaryDirectory(prefix='fcb-', dir=Path.home()/'.cache') as temporary:
    endpoint = Path(temporary)/'s'
    mapped = '/Volumes/SystemRoot'+str(endpoint)
    if len(mapped.encode()) > 80:
        raise SystemExit('ENDPOINT_TOO_LONG')
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as receiver:
        receiver.bind(str(endpoint))
        endpoint.chmod(0o600)
        receiver.settimeout(0.02)
        def drain():
            packets = []
            while True:
                try:
                    packet = receiver.recv(1025)
                except socket.timeout:
                    return packets
                if not protocol.permitted(packet):
                    raise RuntimeError('PROTOCOL_REJECTED')
                packets.append(packet.decode('ascii'))
        def run(label, binary, arguments, expected_records):
            process = subprocess.Popen([str(base/'native/libdarling.so'), 'shell', 'env',
                'DARLING_BOUNDARY_SOCKET='+mapped, '/Volumes/SystemRoot'+str(base/'diag-fixtures'/binary), *arguments],
                env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            records = []
            notice = time.monotonic()+60
            while process.poll() is None:
                records += drain()
                if time.monotonic() >= notice:
                    print(json.dumps({'case':label, 'running':True}), flush=True)
                    notice += 60
            records += drain()
            row = {'case':label, 'exit':process.returncode, 'exactRecords':records == expected_records, 'records':records}
            reports.append(row)
            args.report.write_text(json.dumps({'source':manifest['source'], 'reasonEvents':args.reason_events, 'cases':reports}, indent=2)+'\n')
            print(json.dumps({'case':label, 'exit':row['exit'], 'exactRecords':row['exactRecords']}), flush=True)
        run('coredata-load-branches', 'COREDATA_LOAD_BRANCHES', ['all'], expected)
        if args.overlay_fixtures:
            run('overlay-lookup', 'LOOKUP', [], [ready, 'foundation.overlay.lookup.success\n'])
            run('overlay-bridge', 'BRIDGE', [], [ready, 'foundation.overlay.bridge.success\n'])
valid = all(row['exit'] == 0 and row['exactRecords'] for row in reports)
print('PASS_FRAMEWORK_BOUNDARIES' if valid else 'FAIL_FRAMEWORK_BOUNDARIES', flush=True)
raise SystemExit(0 if valid else 1)
