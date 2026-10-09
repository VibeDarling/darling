import importlib.util
from pathlib import Path
from types import SimpleNamespace
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "builder", Path(__file__).parent / "all-vibedarling-pr-prefix.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

URL = "https://github.com/VibeDarling/darling-cocotron.git"


def done(code=0, stderr=""):
    return SimpleNamespace(returncode=code, stdout="", stderr=stderr)


@patch.object(b.time, "sleep")
class CloneShallowTests(unittest.TestCase):
    def test_timed_out_attempt_leaves_no_partial_directory_for_the_retry(self, sleep):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "clone"

            def fake(command, **kwargs):
                if target.exists():
                    return done(128, "fatal: destination path already exists")
                target.mkdir()
                if fake.calls == 0:
                    fake.calls += 1
                    raise subprocess.TimeoutExpired(command, kwargs["timeout"])
                return done()
            fake.calls = 0
            with patch.object(b.subprocess, "run", side_effect=fake):
                b.clone_shallow(URL, target)
            self.assertTrue(target.is_dir())

    def test_exhausted_attempts_keep_the_timeout_cause(self, sleep):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "clone"

            def fake(command, **kwargs):
                target.mkdir()
                raise subprocess.TimeoutExpired(command, kwargs["timeout"])
            with patch.object(b.subprocess, "run", side_effect=fake) as run:
                with self.assertRaisesRegex(RuntimeError, f"timed out after {b.CLONE_TIMEOUT}s"):
                    b.clone_shallow(URL, target)
            self.assertEqual(run.call_count, b.ATTEMPTS)
            self.assertFalse(target.exists())

    def test_a_directory_that_existed_before_is_never_removed(self, sleep):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "existing"
            target.mkdir()
            (target / "keep.txt").write_text("user data")
            with patch.object(b.subprocess, "run", return_value=done(128, "fatal: destination path exists")):
                with self.assertRaises(RuntimeError):
                    b.clone_shallow(URL, target)
            self.assertEqual((target / "keep.txt").read_text(), "user data")

    def test_permanent_clone_failure_is_not_retried(self, sleep):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(b.subprocess, "run", return_value=done(128, "fatal: repository not found")) as run:
                with self.assertRaises(RuntimeError):
                    b.clone_shallow(URL, Path(tmp) / "clone")
            self.assertEqual(run.call_count, 1)


class SubmoduleCloneOrderTests(unittest.TestCase):
    def git(self, repo, *args):
        return b.run("git", "-c", "user.name=F", "-c", "user.email=f@localhost", *args, cwd=repo)

    def test_timed_out_submodule_clone_is_retried_into_the_empty_checkout_directory(self):
        real_run = subprocess.run
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            library = root / "library"
            library.mkdir()
            self.git(library, "init", "-b", "main")
            (library / "f").write_text("f")
            self.git(library, "add", "f")
            self.git(library, "commit", "-m", "fixture: library")
            tip = self.git(library, "rev-parse", "HEAD")
            super_ = root / "super"
            super_.mkdir()
            self.git(super_, "init", "-b", "main")
            self.git(super_, "update-index", "--add", "--cacheinfo", f"160000,{tip},src/external/library")
            self.git(super_, "commit", "-m", "fixture: gitlink")
            source = root / "workspace/source"
            b.clone_repository(super_.as_uri(), source)
            self.git(source, "checkout", "--detach", "HEAD")
            target = source / "src/external/library"
            self.assertTrue(target.is_dir() and not any(target.iterdir()))
            item = {"repo": "library", "paths": ["src/external/library"], "url": library.as_uri(),
                    "branch": "main", "base": tip, "prs": []}
            attempts = []

            def flaky(command, **kwargs):
                if command[1] == "clone" and not attempts:
                    attempts.append(1)
                    real_run(command, **{**kwargs, "timeout": None})
                    raise subprocess.TimeoutExpired(command, kwargs["timeout"])
                return real_run(command, **kwargs)
            with patch.object(b.subprocess, "run", side_effect=flaky), patch.object(b.time, "sleep"):
                b.clone_and_integrate(source, item, None)
            self.assertEqual(self.git(target, "rev-parse", "HEAD"), tip)

    def test_timeout_cause_survives_when_every_attempt_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "empty"
            target.mkdir()

            def hang(command, **kwargs):
                (target / "partial").write_text("x")
                raise subprocess.TimeoutExpired(command, kwargs["timeout"])
            with patch.object(b.subprocess, "run", side_effect=hang), patch.object(b.time, "sleep"):
                with self.assertRaisesRegex(RuntimeError, "timed out after"):
                    b.clone_shallow(URL, target)
            self.assertTrue(target.is_dir() and not any(target.iterdir()))


class NetworkTimeoutTests(unittest.TestCase):
    def timeouts(self, call):
        with patch.object(b.subprocess, "run", return_value=done()) as run:
            call()
        return [c.kwargs.get("timeout") for c in run.call_args_list if c.args[0][1] in ("clone", "fetch")]

    def test_clone_uses_the_clone_timeout(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(self.timeouts(lambda: b.clone_repository(URL, Path(tmp) / "c")), [b.CLONE_TIMEOUT])

    def test_fetches_use_the_clone_timeout(self):
        repo = Path(".")
        with patch.object(b.subprocess, "run", side_effect=[done(1), done(), done()]) as run:
            b.object_at(repo, "a" * 40, "refs/heads/main")
        self.assertEqual(run.call_args_list[1].kwargs["timeout"], b.CLONE_TIMEOUT)
        with patch.object(b.subprocess, "run", side_effect=[done(1), done(1), done(), done()]) as run:
            b.object_at(repo, "a" * 40, "refs/heads/main")
        self.assertEqual(run.call_args_list[2].kwargs["timeout"], b.CLONE_TIMEOUT)

    def test_unshallow_uses_the_clone_timeout(self):
        results = [done(1), done(0, ""), done()]
        results[1].stdout = "true\n"
        with patch.object(b.subprocess, "run", side_effect=results) as run:
            b.ensure_merge_base(Path("."), "b" * 40)
        self.assertEqual(run.call_args_list[2].kwargs["timeout"], b.CLONE_TIMEOUT)


if __name__ == "__main__":
    unittest.main()
