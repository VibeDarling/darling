import email.message
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import subprocess
import tempfile
import unittest
import urllib.error
from unittest.mock import MagicMock, patch


spec = importlib.util.spec_from_file_location(
    "builder", Path(__file__).parent / "all-vibedarling-pr-prefix.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


def http_error(code, body=b"{}", **headers):
    message = email.message.Message()
    for name, value in headers.items():
        message[name.replace("_", "-")] = value
    return urllib.error.HTTPError("https://api.github.com/x", code, "err", message, io.BytesIO(body))


def response(payload):
    handle = MagicMock()
    handle.__enter__.return_value = io.BytesIO(json.dumps(payload).encode())
    return handle


@patch.object(b.time, "sleep")
class ApiRetryTests(unittest.TestCase):
    def test_rate_limit_waits_for_retry_after_then_succeeds(self, sleep):
        with patch.object(b.urllib.request, "urlopen", side_effect=[http_error(429, Retry_After="7"), response({"ok": 1})]):
            self.assertEqual(b.api("/x"), {"ok": 1})
        sleep.assert_called_once_with(7)

    def test_primary_limit_resetting_within_the_budget_waits_for_the_reset(self, sleep):
        with patch.object(b.time, "time", return_value=1000.0), \
                patch.object(b.urllib.request, "urlopen", side_effect=[
                    http_error(403, X_RateLimit_Remaining="0", X_RateLimit_Reset="1020"), response({})]):
            b.api("/x")
        sleep.assert_called_once_with(20)

    def test_primary_limit_resetting_beyond_the_budget_fails_at_once_with_the_reset_time(self, sleep):
        with patch.object(b.time, "time", return_value=1000.0), \
                patch.object(b.urllib.request, "urlopen", side_effect=[
                    http_error(403, X_RateLimit_Remaining="0", X_RateLimit_Reset="4600")]) as opened:
            with self.assertRaisesRegex(RuntimeError, "resets at 1970-01-01T01:16:40.*GITHUB_TOKEN.*gh auth login"):
                b.api("/x")
        self.assertEqual(opened.call_count, 1)
        sleep.assert_not_called()

    def test_secondary_limit_without_retry_after_is_retried_once(self, sleep):
        def secondary():
            return http_error(403, b'{"message": "You have exceeded a secondary rate limit."}')
        with patch.object(b.urllib.request, "urlopen", side_effect=[secondary(), response({})]):
            b.api("/x")
        sleep.assert_called_once_with(b.SECONDARY_WAIT)
        with patch.object(b.urllib.request, "urlopen", side_effect=[secondary(), secondary(), response({})]) as opened:
            with self.assertRaisesRegex(RuntimeError, "secondary limit persists"):
                b.api("/x")
        self.assertEqual(opened.call_count, 2)

    def test_retry_after_beyond_the_budget_fails_with_its_value(self, sleep):
        with patch.object(b.urllib.request, "urlopen", side_effect=[http_error(429, Retry_After="120")]) as opened:
            with self.assertRaisesRegex(RuntimeError, "Retry-After 120s exceeds the 60s budget"):
                b.api("/x")
        self.assertEqual(opened.call_count, 1)

    def test_exhausted_rate_limit_retries_say_to_authenticate(self, sleep):
        with patch.object(b.urllib.request, "urlopen", side_effect=[http_error(429)] * b.ATTEMPTS):
            with self.assertRaisesRegex(RuntimeError, "rate limited.*GITHUB_TOKEN.*gh auth login"):
                b.api("/x")

    def test_plain_403_fails_at_once(self, sleep):
        with patch.object(b.urllib.request, "urlopen", side_effect=[http_error(403)]) as opened:
            with self.assertRaisesRegex(RuntimeError, "HTTP 403"):
                b.api("/x")
        self.assertEqual(opened.call_count, 1)

    def test_truncated_body_is_retried_and_exhaustion_names_the_path(self, sleep):
        reset = ConnectionResetError("reset")
        with patch.object(b.urllib.request, "urlopen", side_effect=[reset] * b.ATTEMPTS) as opened:
            with self.assertRaisesRegex(RuntimeError, f"GitHub API /x: connection failed after {b.ATTEMPTS}"):
                b.api("/x")
        self.assertEqual(opened.call_count, b.ATTEMPTS)


@patch.object(b.time, "sleep")
class GitRetryTests(unittest.TestCase):
    def completed(self, code, out="ok\n"):
        return SimpleNamespace(returncode=code, stdout=out, stderr="boom")

    def test_run_retries_a_transient_failure(self, sleep):
        with patch.object(b.subprocess, "run", side_effect=[self.completed(1), self.completed(0)]) as run:
            self.assertEqual(b.run("git", "ls-remote", "u", retries=3), "ok")
        self.assertEqual(run.call_count, 2)

    def test_permanent_failures_are_not_retried(self, sleep):
        missing = SimpleNamespace(returncode=128, stdout="", stderr="fatal: repository 'https://x/y.git/' not found")
        dns = SimpleNamespace(returncode=128, stdout="", stderr="fatal: unable to access: Could not resolve host: x")
        for failure in (missing, dns):
            with patch.object(b.subprocess, "run", return_value=failure) as run:
                with self.assertRaises(RuntimeError):
                    b.run("git", "ls-remote", "u", retries=3)
            self.assertEqual(run.call_count, 1)
        sleep.assert_not_called()

    def test_a_hung_command_times_out_and_is_retried(self, sleep):
        with patch.object(b.subprocess, "run", side_effect=subprocess.TimeoutExpired("git", 1)) as run:
            with self.assertRaisesRegex(RuntimeError, "timed out after 0.2s"):
                b.run("git", "ls-remote", "u", retries=1, timeout=0.2)
        self.assertEqual(run.call_count, 2)

    def test_a_real_stub_that_sleeps_is_killed_by_the_timeout(self, sleep):
        with self.assertRaisesRegex(RuntimeError, "sleep 30: timed out after 0.2s"):
            b.run("sleep", "30", timeout=0.2)

    def test_ls_remote_timeout_names_the_repo(self, sleep):
        item = {"repo": "darling-installer", "url": "https://github.com/VibeDarling/darling-installer.git", "prs": []}
        with patch.object(b.subprocess, "run", side_effect=subprocess.TimeoutExpired("git", b.NETWORK_TIMEOUT)) as run:
            with self.assertRaisesRegex(RuntimeError, f"^darling-installer: .*timed out after {b.NETWORK_TIMEOUT}s"):
                b.remote_refs(item)
        self.assertEqual(run.call_count, b.ATTEMPTS)

    def test_run_is_not_retried_by_default(self, sleep):
        with patch.object(b.subprocess, "run", return_value=self.completed(1)) as run:
            with self.assertRaises(RuntimeError):
                b.run("git", "status")
        self.assertEqual(run.call_count, 1)

    def test_persistent_ls_remote_failure_names_the_repo_and_writes_no_lock(self, sleep):
        item = {"repo": "darling-libxml2", "url": "https://github.com/VibeDarling/darling-libxml2.git", "prs": []}
        with patch.object(b.subprocess, "run", return_value=self.completed(1)) as run:
            with self.assertRaisesRegex(RuntimeError, "^darling-libxml2: git ls-remote"):
                b.remote_refs(item)
        self.assertEqual(run.call_count, b.ATTEMPTS)

    def test_failed_repo_aborts_resolve_without_a_lock(self, sleep):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "refs.lock.json"
            args = SimpleNamespace(source=tmp, output=str(out), repo=None, jobs=1, no_prs=True)

            def fake(*cmd, **kwargs):
                if cmd[:2] == ("git", "ls-remote"):
                    raise RuntimeError("down")
                return b.ROOT if cmd[:3] == ("git", "remote", "get-url") else ""
            with patch.object(b, "run", side_effect=fake), patch.object(b, "modules", return_value=[]):
                with self.assertRaisesRegex(RuntimeError, "darling: down"):
                    b.resolve(args)
            self.assertFalse(out.exists())


if __name__ == "__main__":
    unittest.main()
