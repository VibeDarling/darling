#!/usr/bin/env python3
"""Exercise the committed diagnostic fixture through an isolated phone launcher."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile


def packets(receiver):
    result = []
    receiver.settimeout(0.02)
    while True:
        try:
            packet = receiver.recv(1025)
        except socket.timeout:
            return result
        if packet not in (b'diag.ready\n', b'missing-import:_authored.$9\n'):
            raise RuntimeError('PROTOCOL_REJECTED')
        result.append(packet)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('runtime', 'prefix', 'native-dir', 'fixture', 'cache-dir'):
        parser.add_argument('--'+name, type=Path, required=True)
    args = parser.parse_args()
    if args.prefix.exists():
        raise RuntimeError('FRESH_PREFIX_REQUIRED')
    launcher = str(args.native_dir/'libdarling.so')
    env = os.environ.copy()
    env.pop('DARLING_BOUNDARY_SOCKET', None)
    env.update(DARLING_INSTALL_PREFIX=str(args.runtime), DPREFIX=str(args.prefix),
               DARLING_MLDR_PATH=str(args.native_dir/'libmldr.so'),
               DARLING_SERVER_PATH=str(args.native_dir/'libdarlingserver.so'),
               LD_LIBRARY_PATH=str(args.native_dir), DARLING_SHM_DIR=str(args.cache_dir/'shm'),
               DARLING_NO_CORE_DUMPS='1', TMPDIR=str(args.cache_dir))
    guest_fixture = '/Volumes/SystemRoot'+str(args.fixture)
    expected = [b'diag.ready\n', b'missing-import:_authored.$9\n']

    def run(endpoint, receiver):
        guest_endpoint = '/Volumes/SystemRoot'+str(endpoint)
        if len(guest_endpoint.encode()) > 80:
            raise RuntimeError('ENDPOINT_TOO_LONG')
        command = [launcher, 'shell', 'env', 'DARLING_BOUNDARY_SOCKET='+guest_endpoint,
                   guest_fixture, '_authored.$9']
        process = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        records = []
        while process.poll() is None:
            records.extend(packets(receiver))
        records.extend(packets(receiver))
        return process.returncode, records == expected

    with tempfile.TemporaryDirectory(prefix='fcd-', dir=Path.home()/'.cache') as temporary:
        directory = Path(temporary)
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as first:
            with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as second:
                first.bind(str(directory/'a'))
                second.bind(str(directory/'b'))
                (directory/'a').chmod(0o600)
                (directory/'b').chmod(0o600)
                print('PHONE_TRANSPORT_FRESH_STARTED', flush=True)
                first_status, first_valid = run(directory/'a', first)
                print(json.dumps({'case':'fresh', 'exit':first_status, 'exactRecords':first_valid}), flush=True)
                second_status, second_valid = run(directory/'b', second)
                first_unused = packets(first) == []
                print(json.dumps({'case':'existing-new-endpoint', 'exit':second_status,
                                  'exactRecords':second_valid, 'oldEndpointUnused':first_unused}), flush=True)
                valid = first_status == 0 and first_valid and second_status == 0 and second_valid and first_unused
        stopped = subprocess.run([launcher, 'shutdown'], env=env, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
        print('PHONE_TRANSPORT_OWN_PREFIX_SHUTDOWN='+str(stopped), flush=True)
        if not valid or stopped:
            return 1
    print('PASS_PHONE_DIAGNOSTIC_TRANSPORT')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError):
        print('FAIL_PHONE_DIAGNOSTIC_TRANSPORT')
        raise SystemExit(1)
