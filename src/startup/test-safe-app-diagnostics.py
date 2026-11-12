#!/usr/bin/env python3
"""Exercise only authored datagrams; never start a guest or inspect general output."""
import importlib.util
from pathlib import Path
import socket

def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
controller = load('controller', 'test-safe-app-phone.py')
protocol = load('protocol', 'test-boundary-diagnostics.py')

def run(packets, limit=10000):
    records = []
    capture = {'recordLimit':limit, 'recordLimitExceeded':False, 'protocolRejected':False,
               'truncatedDatagrams':0, 'transportDrops':None}
    sender, receiver = socket.socketpair(socket.AF_UNIX, socket.SOCK_DGRAM)
    with sender, receiver:
        receiver.setblocking(False)
        for packet in packets:
            sender.send(packet)
        failed = False
        try:
            controller.drain_diagnostics(receiver, protocol, records, capture)
        except RuntimeError:
            failed = True
        return records, capture, failed

record = b'foundation.session.create.enter\n'
rows, capture, failed = run([record] * 3)
assert not failed and rows == [record.decode()] * 3 and capture['transportDrops'] is None
rows, capture, failed = run([record, b'not-an-allowed-record\n'])
assert failed and len(rows) == 1 and capture['protocolRejected'] and not capture['recordLimitExceeded']
rows, capture, failed = run([record] * 3, limit=2)
assert failed and len(rows) == 2 and capture['recordLimitExceeded'] and not capture['protocolRejected']
rows, capture, failed = run([b'x' * 2048])
assert failed and rows == [] and capture['truncatedDatagrams'] == 1 and capture['protocolRejected']
print('PASS_SAFE_APP_DIAGNOSTIC_DRAIN')
