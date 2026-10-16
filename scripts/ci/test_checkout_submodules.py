import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import checkout_submodules as helper


HERE = Path(__file__).resolve().parent
WORKFLOW = HERE.parents[1] / ".github/workflows/actions.yaml"


class OfflineCheckout(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="checkout-proof-1181-"))
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.env = dict(PATH=os.environ["PATH"], LC_ALL="C", GIT_CONFIG_NOSYSTEM="1",
                        GIT_ALLOW_PROTOCOL="file", GIT_TERMINAL_PROMPT="0",
                        GIT_CONFIG_GLOBAL=str(self.root / "gitconfig"))
        self.canonical = self.root / "canonical"
        self.canonical.mkdir()
        self.git("config", "--global", "url." + self.canonical.as_uri() + "/.insteadOf",
                 "https://github.com/VibeDarling/")
        nested = self.repo(self.canonical / "nested.git", "nested")
        external = self.repo(self.root / "external.git", "external")
        self.external_sha = self.git("rev-parse", "HEAD", cwd=external)
        top = self.repo(self.canonical / "top.git", "top")
        self.git("submodule", "add", str(nested), "nested", cwd=top)
        self.git("config", "-f", ".gitmodules", "submodule.nested.url", "../nested.git", cwd=top)
        self.commit(top)
        self.top_sha = self.git("rev-parse", "HEAD", cwd=top)
        self.nested_sha = self.git("rev-parse", "HEAD", cwd=nested)
        superproject = self.repo(self.canonical / "darling.git", "super")
        scripts = superproject / "scripts/ci"
        scripts.mkdir(parents=True)
        (scripts / "checkout_submodules.py").write_bytes((HERE / "checkout_submodules.py").read_bytes())
        self.git("submodule", "add", str(top), "top", cwd=superproject)
        self.git("config", "-f", ".gitmodules", "submodule.top.url", "../top.git", cwd=superproject)
        self.git("submodule", "add", str(external), "external", cwd=superproject)
        self.commit(superproject)
        self.external = str(external)
        self.original = "https://github.com/fixture-fork/darling.git"
        self.source = self.root / "source" / "darling"
        self.git("clone", str(superproject), str(self.source))
        self.git("remote", "set-url", "origin", self.original, cwd=self.source)
        self.identity = self.git("rev-parse", "HEAD", "HEAD^{tree}", cwd=self.source)
        self.index_tree = self.git("write-tree", cwd=self.source)

    def git(self, *arguments, cwd=None):
        done = subprocess.run(["git", *arguments], cwd=cwd, env=self.env,
                              capture_output=True, text=True)
        if done.returncode:
            raise RuntimeError(done.stderr)
        return done.stdout.strip()

    def repo(self, path, contents):
        path.mkdir()
        self.git("init", "-b", "master", cwd=path)
        self.git("config", "user.name", "Fixture", cwd=path)
        self.git("config", "user.email", "fixture@localhost", cwd=path)
        (path / "content").write_text(contents)
        self.commit(path)
        return path

    def commit(self, repo):
        self.git("add", ".", cwd=repo)
        self.git("commit", "-m", "fixture: pin authored content", cwd=repo)

    def assert_original(self, expected=None):
        self.assertEqual(self.git("config", "--local", "--get", "remote.origin.url", cwd=self.source), expected or self.original)
        self.assertEqual(self.git("rev-parse", "HEAD", "HEAD^{tree}", cwd=self.source), self.identity)
        self.assertEqual(self.git("write-tree", cwd=self.source), self.index_tree)

    def checkout(self, source=None):
        with patch.dict(os.environ, self.env, clear=True):
            return helper.checkout(source or self.source)

    def cli(self, source=None):
        return subprocess.run([sys.executable, "scripts/ci/checkout_submodules.py"],
                              cwd=source or self.source, env=self.env,
                              capture_output=True, text=True)

    def test_recursive_pins_external_url_and_third_job_directory(self):
        self.assertEqual(self.source.parts[-2:], ("source", "darling"))
        caller_cwd = os.getcwd()
        self.assertEqual(self.checkout(), 0)
        self.assertEqual(os.getcwd(), caller_cwd)
        self.assert_original()
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.source / "top"), self.top_sha)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.source / "top/nested"), self.nested_sha)
        self.assertEqual(self.git("remote", "get-url", "origin", cwd=self.source / "top"),
                         (self.canonical / "top.git").as_uri())
        self.assertEqual(self.git("remote", "get-url", "origin", cwd=self.source / "top/nested"),
                         (self.canonical / "nested.git").as_uri())
        self.assertEqual(self.git("remote", "get-url", "origin", cwd=self.source / "external"), self.external)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.source / "external"), self.external_sha)
        for module in ("top", "top/nested"):
            self.assertEqual(self.git("rev-parse", "--is-shallow-repository", cwd=self.source / module), "true", module)
        print(json.dumps(dict(fixture=str(self.root), superproject=self.identity,
                              top=self.top_sha, nested=self.nested_sha, external=self.external_sha)))

    def test_omitted_temporary_origin_fails_without_network(self):
        done = subprocess.run(["git", "-C", str(self.source), "submodule", "update", "--init", "--recursive"],
                              env=self.env, capture_output=True, text=True)
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("https://github.com/fixture-fork/top.git", done.stderr)
        self.assertIn("transport 'https' not allowed", done.stderr)
        self.assert_original()

    def test_canonical_origin_stays_canonical(self):
        self.git("remote", "set-url", "origin", helper.CANONICAL, cwd=self.source)
        self.assertEqual(self.checkout(), 0)
        self.assert_original(helper.CANONICAL)

    def test_cached_submodule_url_rejected_without_change(self):
        self.git("config", "submodule.top.url", "https://github.com/fixture-fork/top.git", cwd=self.source)
        with self.assertRaisesRegex(RuntimeError, "fresh checkout"):
            self.checkout()
        self.assert_original()

    def test_checkout_failure_restores_origin_and_status(self):
        self.git("config", "-f", ".gitmodules", "submodule.top.url", "../missing.git", cwd=self.source)
        expected = subprocess.run(["git", "-C", str(self.source), "submodule", "update", "--init", "--recursive"],
                                  env=self.env, capture_output=True).returncode
        self.assertNotEqual(expected, 0)
        fresh = self.root / "failure-source"
        self.git("clone", str(self.canonical / "darling.git"), str(fresh))
        self.git("remote", "set-url", "origin", self.original, cwd=fresh)
        self.git("config", "-f", ".gitmodules", "submodule.top.url", "../missing.git", cwd=fresh)
        self.assertEqual(self.checkout(fresh), expected)
        self.assertEqual(self.git("remote", "get-url", "origin", cwd=fresh), self.original)

    def test_restore_failure_explicitly_reports_checkout_status(self):
        run = subprocess.run
        def lock_after_update(arguments, **kwargs):
            done = run(arguments, **kwargs)
            if "submodule" in arguments and "update" in arguments:
                (self.source / ".git/config.lock").write_text("fixture restoration failure")
            return done
        with patch.object(helper.subprocess, "run", side_effect=lock_after_update):
            with self.assertRaisesRegex(RuntimeError, "restore original origin; checkout exit status: 0"):
                self.checkout()

    def test_actual_cli_in_both_job_directories(self):
        for name in ("root-job", "third-job/source/darling"):
            with self.subTest(directory=name):
                source = self.root / name
                self.git("clone", str(self.canonical / "darling.git"), str(source))
                original = self.original.encode() + b"\xff  \r\n"
                self.git("remote", "set-url", "origin", original, cwd=source)
                done = self.cli(source)
                self.assertEqual(done.returncode, 0, done.stderr)
                configured = subprocess.run(["git", "config", "--local", "--null", "--get", "remote.origin.url"],
                                            cwd=source, env=self.env, capture_output=True)
                self.assertEqual(configured.stdout, original + b"\0")
                self.assertEqual(self.git("rev-parse", "HEAD", "HEAD^{tree}", cwd=source), self.identity)

    def test_actual_cli_failure_status_and_origin_restoration(self):
        self.git("config", "-f", ".gitmodules", "submodule.top.url", "../missing.git", cwd=self.source)
        done = self.cli()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn(f"exit status {done.returncode}", done.stderr)
        self.assertIn("missing.git", done.stderr)
        self.assertNotIn(self.original, done.stderr)
        self.assert_original()

    def test_multiple_origins_rejected_before_change(self):
        self.git("config", "--add", "remote.origin.url", "second", cwd=self.source)
        done = self.cli()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("exactly one", done.stderr)
        self.assertEqual(self.git("config", "--get-all", "remote.origin.url", cwd=self.source),
                         self.original + "\nsecond")

    def test_all_workflow_callers_initialize_from_correct_directory(self):
        workflow = WORKFLOW.read_text()
        jobs = re.split(r"(?m)^  (?=[A-Za-z])", workflow)[1:]
        callers = [job for job in jobs if "uses: actions/checkout@v4" in job]
        self.assertEqual(len(callers), 3)
        for job in callers:
            self.assertIn("submodules: false", job)
            self.assertNotIn("submodules: recursive", job)
            self.assertEqual(job.count("run: python3 scripts/ci/checkout_submodules.py"), 1)
            self.assertLess(job.index("uses: actions/checkout@v4"),
                            job.index("run: python3 scripts/ci/checkout_submodules.py"))
        third = next(job for job in callers if "path: source/darling" in job)
        self.assertIn("working-directory: source/darling", third)


if __name__ == "__main__":
    unittest.main()
