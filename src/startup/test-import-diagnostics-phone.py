#!/usr/bin/env python3
"""Validate only the dedicated diagnostic protocol through an owned phone prefix."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('runtime', 'prefix', 'native-dir', 'fixture-dir', 'cache-dir', 'report', 'control-report'):
        parser.add_argument('--'+name, type=Path, required=True)
    parser.add_argument('--case', action='append', default=[])
    args = parser.parse_args()
    protocol_path = Path(__file__).with_name('test-boundary-diagnostics.py')
    spec = importlib.util.spec_from_file_location('owned_diagnostic_protocol', protocol_path)
    protocol = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(protocol)
    if not (args.prefix/'clean-release-control-20261103').is_file():
        raise RuntimeError('OWN_PREFIX_MARKER_REQUIRED')
    launcher = str(args.native_dir/'libdarling.so')
    env = os.environ.copy()
    for key in list(env):
        if key.startswith('DYLD_') or key in ('DARLING_BOUNDARY_SOCKET', 'DARLING_STRICT_LINKING'):
            env.pop(key)
    env.update(DARLING_INSTALL_PREFIX=str(args.runtime), DPREFIX=str(args.prefix),
               DARLING_MLDR_PATH=str(args.native_dir/'libmldr.so'),
               DARLING_SERVER_PATH=str(args.native_dir/'libdarlingserver.so'),
               LD_LIBRARY_PATH=str(args.native_dir), DARLING_SHM_DIR=str(args.cache_dir/'shm'),
               DARLING_NO_CORE_DUMPS='1', TMPDIR=str(args.cache_dir))
    control = json.loads(args.control_report.read_text())
    baselines = {row['case']:row['exit'] for row in control['cases']}
    strict_exit = baselines['released-strict-nonlazy']
    if baselines['released-resolved'] != 0 or not isinstance(strict_exit, int) or strict_exit == 0:
        raise RuntimeError('INVALID_RELEASED_CONTROL_RESULT')
    ready = 'diag.ready\n'
    reports = []

    def receive(receiver):
        records = []
        receiver.settimeout(0.02)
        while True:
            try:
                packet = receiver.recv(1025)
            except socket.timeout:
                return records
            if not protocol.permitted(packet):
                raise RuntimeError('PROTOCOL_REJECTED')
            records.append(packet.decode('ascii'))

    def guest_endpoint(path):
        return '/Volumes/SystemRoot'+str(path)

    def run(label, binary, endpoint, receiver, expected, strict=False, expected_exit=0, extra=(), collect=True, bind_now=False):
        if args.case and label not in args.case:
            return None
        command = [launcher, 'shell', 'env']
        if bind_now:
            command.append('DYLD_BIND_AT_LAUNCH=1')
        if endpoint is not None:
            command.append('DARLING_BOUNDARY_SOCKET='+endpoint)
        if strict:
            command.append('DARLING_STRICT_LINKING=1')
        command.extend(['/Volumes/SystemRoot'+str(args.fixture_dir/binary), *extra])
        process = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        records = []
        notice = time.monotonic()+60
        while process.poll() is None:
            if collect:
                records.extend(receive(receiver))
            else:
                time.sleep(0.02)
            if time.monotonic() >= notice:
                print(json.dumps({'case':label, 'running':True}), flush=True)
                notice += 60
        if collect:
            records.extend(receive(receiver))
        status_ok = process.returncode == expected_exit
        exact = records == expected
        reports.append({'case':label, 'exit':process.returncode, 'exactRecords':exact, 'expectedExit':expected_exit, 'statusMatches':status_ok, 'records':records})
        args.report.write_text(json.dumps(reports, indent=2)+'\n')
        print(json.dumps({'case':label, 'exit':process.returncode, 'exactRecords':exact}), flush=True)
        return status_ok and exact

    api = [ready, 'coredata.store-description.init.enter\n', 'coredata.store-description.init.ok\n',
           'coredata.model.load.enter\n', 'coredata.model.load.error\n', 'coredata.container.init.enter\n',
           'coredata.context.init.enter\n', 'coredata.context.init.ok\n',
           'coredata.store-description.init.enter\n', 'coredata.store-description.init.ok\n',
           'coredata.container.init.model-error\n', 'coredata.container.load.enter\n',
           'coredata.container.load.error\n']
    with tempfile.TemporaryDirectory(prefix='fcd-', dir=Path.home()/'.cache') as temporary:
        directory = Path(temporary)
        endpoint = directory/'s'
        mapped = guest_endpoint(endpoint)
        if len(mapped.encode()) > 80:
            raise RuntimeError('ENDPOINT_TOO_LONG')
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as receiver:
            receiver.bind(str(endpoint))
            endpoint.chmod(0o600)
            run('resolved', 'RESOLVED', mapped, receiver, [ready])
            run('strong-permissive', 'STRONG', mapped, receiver, [ready, 'missing-import:_authored_missing_import\n'])
            run('weak', 'WEAK', mapped, receiver, [ready, 'missing-import:_authored_weak_import\n'])
            run('missing-dependency', 'DEPENDENCY', mapped, receiver, [ready, 'missing-import:_authored_missing_dependency\n'])
            run('swift-import', 'SWIFT', mapped, receiver,
                [ready, 'missing-import:_$s24AuthoredImportDependency15authoredMissingSiyF\n'], bind_now=True)
            run('nonmain-import-excluded', 'SCOPE_NEGATIVE', mapped, receiver, [ready])
            run('coredata-api', 'COREDATA_API', mapped, receiver, api)
            run('automatic-exception-output', 'AUTOMATIC_EXCEPTION_OUTPUT', mapped, receiver, [ready])
            run('disabled', 'RESOLVED', None, receiver, [])
            regular = directory/'regular'
            regular.write_text('unchanged')
            for label, invalid in [('relative', 'relative'), ('regular', guest_endpoint(regular)),
                                   ('absent', guest_endpoint(directory/'absent')), ('overlong', '/'+('x'*81))]:
                run('invalid-'+label, 'RESOLVED', invalid, receiver, [])
            if regular.read_text() != 'unchanged':
                raise RuntimeError('FALLBACK_FILE_CHANGED')
            directory.chmod(0o755)
            run('nonprivate', 'RESOLVED', mapped, receiver, [])
            directory.chmod(0o700)
            run('invalid-name', 'boundary-diagnostics-guest', mapped, receiver, [ready, ready], extra=('authored invalid name',))
            run('overlong-name', 'boundary-diagnostics-guest', mapped, receiver, [ready, ready], extra=('x'*201,))
            fillers = []
            try:
                fill_count = 0
                for attempt in range(32):
                    filler = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
                    fillers.append(filler)
                    filler.setblocking(False)
                    from_this_sender = 0
                    while fill_count < 10000:
                        try:
                            filler.sendto(ready.encode(), str(endpoint))
                            fill_count += 1
                            from_this_sender += 1
                        except BlockingIOError:
                            break
                    if from_this_sender == 0:
                        break
                else:
                    raise RuntimeError('DESTINATION_SATURATION_NOT_REACHED')
                if fill_count == 10000:
                    raise RuntimeError('DESTINATION_SATURATION_NOT_REACHED')
                run('saturated', 'RESOLVED', mapped, receiver, [], collect=False)
                drained = receive(receiver)
                print(json.dumps({'saturationInjected':fill_count, 'saturationDrained':len(drained), 'saturationExact':drained == [ready]*fill_count}), flush=True)
                if drained != [ready]*fill_count:
                    raise RuntimeError('SATURATED_CHANNEL_CHANGED')
            finally:
                for filler in fillers:
                    filler.close()
            with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as closed_receiver:
                closed_receiver.bind(str(directory/'closed'))
            run('closed', 'RESOLVED', guest_endpoint(directory/'closed'), receiver, [], collect=False)
            permissive_valid = all(row['statusMatches'] and row['exactRecords'] for row in reports)
            if not args.case:
                print('PASS_PERMISSIVE_DIAGNOSTIC_GATES' if permissive_valid else 'FAIL_PERMISSIVE_DIAGNOSTIC_GATES', flush=True)
            run('strong-strict', 'STRONG', mapped, receiver,
                [ready, 'missing-import:_authored_missing_import\n'], strict=True, expected_exit=strict_exit)
            run('weak-strict', 'WEAK', mapped, receiver,
                [ready, 'missing-import:_authored_weak_import\n'], strict=True)
    if args.case and set(args.case) != {row['case'] for row in reports}:
        raise RuntimeError('SELECTED_CASE_NOT_RUN')
    valid = all(row['statusMatches'] and row['exactRecords'] for row in reports)
    print(('PASS_SELECTED_DIAGNOSTIC_CASES' if valid else 'FAIL_SELECTED_DIAGNOSTIC_CASES') if args.case else ('PASS_IMPORT_DIAGNOSTIC_PHONE_MATRIX' if valid else 'FAIL_IMPORT_DIAGNOSTIC_PHONE_MATRIX'), flush=True)
    return 0 if valid else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError):
        print('FAIL_IMPORT_DIAGNOSTIC_PHONE_MATRIX', flush=True)
        raise SystemExit(1)
