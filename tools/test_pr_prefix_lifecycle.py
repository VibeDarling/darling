import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
import subprocess

spec = importlib.util.spec_from_file_location('builder', Path(__file__).with_name('all-vibedarling-pr-prefix.py'))
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class PrefixLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.w = Path(self.tmp.name)
        self.sha = '1' * 40
        (self.w / 'source').mkdir()
        (self.w / 'image').mkdir()
        (self.w / 'build/src/startup').mkdir(parents=True)
        (self.w / 'build/src/startup/darling').write_text('authored launcher fixture')
        (self.w / 'build/.darling-pr-prefix-source').write_text(self.sha)
        (self.w / 'runtime.manifest.json').write_text(json.dumps({
            'source_commit': self.sha, 'image': str(self.w / 'image'),
            'launcher': str(self.w / 'build/src/startup/darling'), 'locks': {}}))
        self.args = SimpleNamespace(workspace=str(self.w), prefix_name='proof', guest_wait=1, disable_ptrauth=False)
        self.patch_run = patch.object(b, 'run', side_effect=lambda *a, **kw: self.sha if a[1] == 'rev-parse' else '')
        self.patch_run.start()
        self.addCleanup(self.patch_run.stop)

    def exercise(self, guest_exit, shutdown_exit=0, identity=True):
        def process(command, env, log, seconds):
            log.write_text('authored subprocess observation')
            if command[1] == 'shell':
                p = self.w / 'proof/private/etc'
                p.mkdir(parents=True)
                (p / 'passwd').write_text('fixture')
                return {'pid': 123, 'exit': guest_exit, 'pending': guest_exit is None}
            return {'pid': 124, 'exit': shutdown_exit, 'pending': False}
        with patch.object(b, 'bounded_process', side_effect=process), patch.object(b, 'prefix_server_identity',
                return_value={'server_pid': '999999991', 'server_identity_verified': identity}):
            b.verify_prefix(self.args)

    def test_natural_guest_and_matching_shutdown_verified(self):
        self.exercise(0)
        report = json.loads((self.w / 'proof.verify.json').read_text())
        self.assertTrue(report['verified'])
        self.assertFalse(report['signals_sent'])
        self.assertTrue(json.loads((self.w / 'runtime.manifest.json').read_text())['prefix_execution_verified'])

    def test_pending_guest_never_becomes_ready_from_shutdown(self):
        with self.assertRaisesRegex(RuntimeError, 'not verified'):
            self.exercise(None)
        report = json.loads((self.w / 'proof.verify.json').read_text())
        self.assertTrue(report['guest']['pending'])
        self.assertFalse(report['verified'])
        self.assertFalse(json.loads((self.w / 'runtime.manifest.json').read_text())['prefix_execution_verified'])

    def test_shutdown_refusal_and_identity_mismatch_fail(self):
        with self.assertRaisesRegex(RuntimeError, 'not verified'):
            self.exercise(0, shutdown_exit=1, identity=False)
        self.assertTrue((self.w / 'proof').exists())

    def test_existing_prefix_and_changed_binding_refused(self):
        (self.w / 'proof').mkdir()
        with self.assertRaisesRegex(RuntimeError, 'new direct child'):
            b.verify_prefix(self.args)
        (self.w / 'build/.darling-pr-prefix-source').write_text('2' * 40)
        with self.assertRaisesRegex(RuntimeError, 'binding'):
            b.verify_prefix(self.args)

    def test_bounded_wait_does_not_signal_pending_process(self):
        with patch.object(b.subprocess, 'Popen') as popen:
            popen.return_value.pid = 55
            popen.return_value.wait.side_effect = subprocess.TimeoutExpired(['fixture'], 1)
            result = b.bounded_process(['fixture'], {}, self.w / 'wait.log', 1)
            self.assertTrue(result['pending'])
            popen.return_value.kill.assert_not_called()
            popen.return_value.terminate.assert_not_called()

    def test_long_socket_path_refused_before_any_launch(self):
        self.args.prefix_name = 'x' * 100
        with patch.object(b, 'bounded_process', side_effect=AssertionError('must reject before launching')) as process:
            with self.assertRaisesRegex(RuntimeError, 'sun_path capacity'):
                b.verify_prefix(self.args)
            process.assert_not_called()
        self.assertFalse((self.w / self.args.prefix_name).exists())


if __name__ == '__main__':
    unittest.main()
