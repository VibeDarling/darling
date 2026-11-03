#!/usr/bin/env python3
"""Control an isolated official app with discarded general output and validated diagnostics."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import selectors
import shutil
import socket
import subprocess
import tempfile
import time
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path, required=True)
    parser.add_argument('--prefix', type=Path, required=True)
    parser.add_argument('--reuse-owned-prefix', action='store_true')
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--archive-sha256', required=True)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--executable', required=True)
    args = parser.parse_args()
    base = args.base.resolve()
    prefix = args.prefix.resolve()
    if prefix.parent != base:
        raise RuntimeError('OWN_PREFIX_PARENT_REQUIRED')
    if args.reuse_owned_prefix:
        if not (prefix/'clean-release-control-20261103').is_file():
            raise RuntimeError('OWN_PREFIX_MARKER_REQUIRED')
    elif prefix.exists():
        raise RuntimeError('FRESH_OWN_PREFIX_REQUIRED')
    if any('/' in part or part in ('', '.', '..') for part in (args.bundle, args.executable)):
        raise RuntimeError('INVALID_APP_COMPONENT')
    if hashlib.file_digest(args.archive.open('rb'), 'sha256').hexdigest() != args.archive_sha256:
        raise RuntimeError('ARCHIVE_IDENTITY_MISMATCH')
    protocol_spec = importlib.util.spec_from_file_location('owned_protocol', Path(__file__).with_name('test-boundary-diagnostics.py'))
    protocol = importlib.util.module_from_spec(protocol_spec)
    protocol_spec.loader.exec_module(protocol)
    manifest = json.loads((base/'diagnostic-payload/manifest.json').read_text())
    def verify(root):
        for component in manifest['components'].values():
            with (root/component['relative']).open('rb') as source:
                if hashlib.file_digest(source, 'sha256').hexdigest() != component['sha256']:
                    raise RuntimeError('COMPONENT_IDENTITY_MISMATCH')
    verify(base/'runtime/libexec/darling')
    env = os.environ.copy()
    for key in list(env):
        if key.startswith('DYLD_') or key in ('DARLING_BOUNDARY_SOCKET', 'DARLING_STRICT_LINKING'):
            env.pop(key)
    env.update(DARLING_INSTALL_PREFIX=str(base/'runtime'), DPREFIX=str(prefix),
               DARLING_MLDR_PATH=str(base/'native/libmldr.so'),
               DARLING_SERVER_PATH=str(base/'native/libdarlingserver.so'),
               LD_LIBRARY_PATH=str(base/'native'), DARLING_SHM_DIR=str(base/'cache/shm'),
               DARLING_NO_CORE_DUMPS='1', TMPDIR=str(base/'cache'))
    launcher = str(base/'native/libdarling.so')
    def launch(command, **kwargs):
        return subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kwargs)
    host = None
    guest = None
    stopped = None
    diagnostic_temporary = None
    owned_sockets = []
    def shutdown():
        nonlocal stopped
        if stopped is None:
            stopped = launch([launcher, 'shutdown']).wait()
        if host is not None and host.poll() is None:
            try:
                host.stdin.write('quit\n')
                host.stdin.flush()
            except BrokenPipeError:
                pass
            host.wait()
        return {'shutdownExit':stopped, 'guestExit':None if guest is None else guest.poll(),
                'hostExit':None if host is None else host.poll()}
    try:
        bootstrap = launch([launcher, 'shell', '/bin/test', '-f', '/clean-release-control-20261103'])
        print('SAFE_APP_PREFIX_BOOTSTRAP_RUNNING', flush=True)
        if bootstrap.wait() != 0:
            raise RuntimeError('OWN_PREFIX_BOOTSTRAP_FAILED')
        verify(prefix)
        for item in ('display.sock', 'app-control.sock', 'app-diagnostic.sock'):
            if (base/item).exists():
                raise RuntimeError('ENDPOINT_ALREADY_EXISTS')
        diagnostic_temporary = tempfile.TemporaryDirectory(prefix='fca-', dir=Path.home()/'.cache')
        diagnostic_directory = Path(diagnostic_temporary.name)
        diagnostic = diagnostic_directory/'s'
        mapped_diagnostic = '/Volumes/SystemRoot'+str(diagnostic)
        if len(mapped_diagnostic.encode()) > 80:
            raise RuntimeError('DIAGNOSTIC_ENDPOINT_TOO_LONG')
        bundle_path = prefix/'Applications'/args.bundle
        with zipfile.ZipFile(args.archive) as archive:
            for entry in archive.infolist():
                if not entry.filename.startswith('Payload/'+args.bundle+'/'):
                    continue
                relative = Path(entry.filename).relative_to('Payload')
                if relative.is_absolute() or '..' in relative.parts:
                    raise RuntimeError('INVALID_ARCHIVE_PATH')
                destination = prefix/'Applications'/relative
                if entry.is_dir():
                    destination.mkdir(parents=True, exist_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with archive.open(entry) as source, destination.open('wb') as output:
                        shutil.copyfileobj(source, output)
                    destination.chmod((entry.external_attr >> 16) & 0o777 or 0o644)
        (bundle_path/args.executable).chmod(0o755)
        host = subprocess.Popen([str(base/'pocket-host'), str(base/'display.sock'), '1170x2532@3', '141,0,102,0'],
                                stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
        while not (base/'display.sock').is_socket():
            if host.poll() is not None:
                raise RuntimeError('DISPLAY_HOST_FAILED')
            time.sleep(0.02)
        records = []
        guest = None
        active = True
        def report():
            value = {'source':manifest['source'], 'prefix':str(prefix),
                     'reusedOwnedPrefix':args.reuse_owned_prefix,
                     'archiveSha256':args.archive_sha256,
                     'guestStarted':guest is not None, 'guestExit':None if guest is None else guest.poll(),
                     'hostExit':host.poll(), 'records':records}
            (base/'safe-app-report.json').write_text(json.dumps(value, indent=2)+'\n')
            return value
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as receiver, socket.socket(socket.AF_UNIX) as server:
            receiver.bind(str(diagnostic))
            owned_sockets.append(diagnostic)
            diagnostic.chmod(0o600)
            server.bind(str(base/'app-control.sock'))
            owned_sockets.append(base/'app-control.sock')
            server.listen(1)
            with selectors.DefaultSelector() as selector:
                selector.register(receiver, selectors.EVENT_READ, 'diagnostic')
                selector.register(server, selectors.EVENT_READ, 'control')
                print('SAFE_APP_CONTROLLER_READY', flush=True)
                while active:
                    for key, mask in selector.select(0.2):
                        if key.data == 'diagnostic':
                            packet = receiver.recv(1025)
                            if not protocol.permitted(packet) or len(records) >= 10000:
                                shutdown()
                                raise RuntimeError('DIAGNOSTIC_PROTOCOL_REJECTED')
                            records.append(packet.decode('ascii'))
                        else:
                            client, address = server.accept()
                            with client:
                                command = json.loads(client.recv(4096).split(b'\n')[0])
                                if command == ['start'] and guest is None:
                                    guest = launch([launcher, 'shell', 'env',
                                        'FONTCONFIG_FILE='+str(base/'fonts.conf'),
                                        'DARLING_SHM_DIR='+str(base/'cache/shm'),
                                        'DARLING_POCKET_DISPLAY=/Volumes/SystemRoot'+str(base/'display.sock'),
                                        'DARLING_BOUNDARY_SOCKET='+mapped_diagnostic,
                                        '/Applications/'+args.bundle+'/'+args.executable])
                                    result = {'started':True}
                                elif command == ['status']:
                                    result = report()
                                elif command == ['shot']:
                                    host.stdin.write('shot '+str(base/'safe-app-screen.png')+'\n')
                                    host.stdin.flush()
                                    result = {'screenshotRequested':True}
                                elif len(command) == 3 and command[0] == 'tap' and all(str(x).isdecimal() for x in command[1:]):
                                    host.stdin.write('tap '+str(command[1])+' '+str(command[2])+'\n')
                                    host.stdin.flush()
                                    result = {'tapSent':True}
                                elif command == ['shutdown']:
                                    result = shutdown()
                                    active = False
                                else:
                                    result = {'invalidControlAction':True}
                                client.sendall(json.dumps(result).encode()+b'\n')
                    report()
        print('SAFE_APP_CONTROLLER_STOPPED', flush=True)
    finally:
        cleanup = shutdown()
        for endpoint in owned_sockets:
            if endpoint.is_socket():
                endpoint.unlink()
        if diagnostic_temporary is not None:
            diagnostic_temporary.cleanup()
        print(json.dumps({'cleanup':cleanup}), flush=True)



if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError):
        print('SAFE_APP_CONTROLLER_FAILED', flush=True)
        raise SystemExit(1)
