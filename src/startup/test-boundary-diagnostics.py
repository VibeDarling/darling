#!/usr/bin/env python3
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile

EVENTS = (
    b'diag.ready\n',
    b'coredata.container.init.enter\n',
    b'coredata.container.init.ok\n',
    b'coredata.container.init.model-error\n',
    b'coredata.container.load.enter\n',
    b'coredata.container.load.success\n',
    b'coredata.container.load.error\n',
    b'coredata.store-description.init.enter\n',
    b'coredata.store-description.init.ok\n',
    b'coredata.model.load.enter\n',
    b'coredata.model.load.ok\n',
    b'coredata.model.load.error\n',
    b'coredata.context.init.enter\n',
    b'coredata.context.init.ok\n',
    b'foundation.overlay.lookup.success\n',
    b'foundation.overlay.bridge.success\n',
    b'coredata.container.load.model-error\n',
    b'coredata.container.load.unsupported-sqlite\n',
    b'coredata.container.load.unsupported-type\n',
    b'coredata.container.load.nonfile-url\n',
    b'coredata.container.load.readonly-missing\n',
    b'coredata.container.load.directory-error\n',
    b'coredata.container.load.coordinator-enter\n',
    b'coredata.container.load.coordinator-error\n',
    b'coredata.container.load.coordinator-empty-error\n',
    b'coredata.container.load.coordinator-exception\n',
    b'fixture.coredata.case.enter\n',
    b'fixture.coredata.case.complete\n',
)
FIXTURE_FETCH_EVENTS = (
    b'swiftui.app.main.enter\n', b'fixture.fetch.context.ok\n', b'fixture.fetch.add.ok\n', b'fixture.fetch.edit.ok\n',
    b'fixture.fetch.delete.ok\n', b'fixture.fetch.other.ok\n', b'fixture.fetch.return.ok\n',
)
SWIFTUI_PHASE_EVENTS = (
    b'swiftui.app.self.ready\n', b'swiftui.app.graph.ready\n', b'swiftui.app.uikit.enter\n',
    b'swiftui.app.launch.enter\n', b'swiftui.app.render.enter\n', b'swiftui.app.body.enter\n',
    b'swiftui.fetch.enter\n', b'swiftui.fetch.success\n', b'swiftui.fetch.error\n',
    b'swiftui.observer.enter\n', b'swiftui.observer.ready\n',
    b'swiftui.windowgroup.init.enter\n', b'swiftui.windowgroup.init.ready\n',
    b'swiftui.windowgroup.make.enter\n', b'swiftui.windowgroup.content.ready\n',
    b'swiftui.fetch.init.enter\n', b'swiftui.fetch.init.ready\n',
)
CATEGORIES = frozenset(EVENTS+FIXTURE_FETCH_EVENTS+SWIFTUI_PHASE_EVENTS)
IMPORT = re.compile(rb'missing-import:[A-Za-z0-9_.$]{1,200}\n\Z')


def permitted(packet):
    return 0 < len(packet) <= 1024 and (packet in CATEGORIES or IMPORT.fullmatch(packet) is not None)


def run(binary, endpoint, name='_authored.$9', arguments=None):
    env = os.environ.copy()
    env.pop('DARLING_BOUNDARY_SOCKET', None)
    if endpoint is not None:
        env['DARLING_BOUNDARY_SOCKET'] = str(endpoint)
    completed = subprocess.run([binary, *(arguments if arguments is not None else [name])], env=env, stdin=subprocess.DEVNULL,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
    if completed.returncode:
        raise AssertionError('FIXTURE_RESULT_CHANGED')


def drain(receiver):
    packets = []
    receiver.settimeout(0.03)
    while True:
        try:
            packet = receiver.recv(1025)
        except socket.timeout:
            return packets
        if not permitted(packet):
            raise AssertionError('PROTOCOL_REJECTED')
        packets.append(packet)


def check(condition):
    if not condition:
        raise AssertionError('CONTRACT_FAILED')


def main(binary):
    for packet in CATEGORIES:
        check(permitted(packet) and not permitted(packet+b'x') and not permitted(packet[:-1]))
    with tempfile.TemporaryDirectory(prefix='fcd-', dir=Path.home()/'.cache') as temporary:
        root = Path(temporary)
        endpoint = root/'s'
        check(len(str(endpoint).encode()) <= 80)
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as receiver:
            receiver.bind(str(endpoint))
            endpoint.chmod(0o600)
            for index, event in enumerate(EVENTS):
                run(binary, endpoint, arguments=['--event', str(index)])
                check(drain(receiver) == [event])
                for invalid in (None, 'relative'):
                    run(binary, invalid, arguments=['--event', str(index)])
                    check(drain(receiver) == [])
                check(not permitted(event+b'x') and not permitted(event+b'\n') and not permitted(event[:-1]))
            run(binary, endpoint)
            check(drain(receiver) == [b'diag.ready\n', b'missing-import:_authored.$9\n'])
            for name in ('', 'bad name', 'bad/name', 'bad\nname', 'bad:name', 'x'*201):
                run(binary, endpoint, name)
                check(drain(receiver) == [b'diag.ready\n'])
            run(binary, endpoint, 'x'*200)
            check(drain(receiver) == [b'diag.ready\n', b'missing-import:'+b'x'*200+b'\n'])
            for invalid in (None, 'relative', root/'absent', str(root)+'/../s', '/'+('x'*81)):
                run(binary, invalid)
                check(drain(receiver) == [])
            regular = root/'regular'
            regular.write_bytes(b'unchanged')
            run(binary, regular)
            check(regular.read_bytes() == b'unchanged' and drain(receiver) == [])
            link = root/'link'
            link.symlink_to(endpoint)
            run(binary, link)
            check(drain(receiver) == [])
            root.chmod(0o755)
            run(binary, endpoint)
            root.chmod(0o700)
            check(drain(receiver) == [])
            with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as filler:
                filler.setblocking(False)
                for count in range(10000):
                    try:
                        filler.sendto(b'diag.ready\n', str(endpoint))
                    except BlockingIOError:
                        break
                else:
                    raise AssertionError('SATURATION_NOT_REACHED')
                run(binary, endpoint)
                drain(receiver)
        run(binary, endpoint)
        check(not permitted(b'unknown:authored-test\n'))
        check(not permitted(b'missing-import:bad name\n'))
        check(not permitted(b'diag.ready\nextra'))
        check(not permitted(b'x'*1025))
    print('PASS_BOUNDARY_DIAGNOSTIC_PROTOCOL')


if __name__ == '__main__':
    try:
        main(sys.argv[1])
    except (AssertionError, OSError, subprocess.TimeoutExpired):
        print('FAIL_BOUNDARY_DIAGNOSTIC_PROTOCOL')
        sys.exit(1)
