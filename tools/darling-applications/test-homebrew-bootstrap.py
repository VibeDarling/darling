#!/usr/bin/env python3
"""Fall-through diagnosis tests for homebrew-bootstrap; no Darling prefix needed.

The helper probes absolute guest paths, so on any machine without a staged
payload it reaches its final branch. Which message that branch prints is the
thing under test: a guest run with an unstaged prefix must not be reported as a
host-side invocation, and vice versa. `uname` is stubbed on PATH so both
branches are reachable from one host.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BOOTSTRAP = Path(__file__).resolve().parent / "homebrew-bootstrap"
# The probes are absolute paths that no stub can intercept, so on a host that
# really has one of them the helper succeeds and never reaches the branch under
# test. Homebrew-on-Linux at /usr/local/bin/brew is the realistic case.
STAGED = [p for p in ("/opt/homebrew/bin/brew", "/opt/nanobrew/prefix/bin/nb", "/usr/local/bin/brew") if Path(p).exists()]


def run_as(system: str) -> subprocess.CompletedProcess:
    with tempfile.TemporaryDirectory() as stub_dir:
        stub = Path(stub_dir) / "uname"
        stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "{system}"\n')
        stub.chmod(0o755)
        env = dict(os.environ, PATH=f"{stub_dir}:{os.environ.get('PATH', '')}")
        return subprocess.run(
            [str(BOOTSTRAP), "/opt/homebrew"],
            env=env, capture_output=True, text=True, timeout=60,
        )


@unittest.skipIf(STAGED, f"host really has {STAGED}, so the fall-through branch is unreachable here")
class FallThroughDiagnosisTests(unittest.TestCase):
    def test_guest_run_blames_the_unstaged_prefix(self):
        result = run_as("Darwin")
        self.assertEqual(result.returncode, 66)
        self.assertIn("no Homebrew or Nanobrew payload is staged in this prefix", result.stderr)
        self.assertIn("never downloads one", result.stderr)
        # The defect this guards: an in-guest run on an empty prefix used to be
        # reported as the helper having run in the wrong filesystem.
        self.assertNotIn("outside the guest", result.stderr)

    def test_host_run_blames_the_wrong_filesystem(self):
        result = run_as("Linux")
        self.assertEqual(result.returncode, 66)
        self.assertIn("outside the guest", result.stderr)
        self.assertIn("darling shell", result.stderr)

    def test_missing_uname_is_reported_as_undecidable(self):
        result = subprocess.run(
            [str(BOOTSTRAP), "/opt/homebrew"],
            env=dict(os.environ, PATH="/nonexistent"), capture_output=True, text=True, timeout=60,
        )
        self.assertEqual(result.returncode, 66)
        self.assertIn("could not run uname", result.stderr)

    def test_the_two_cases_are_distinguishable(self):
        # Positive control: proves the uname stub is honoured. Without it both
        # runs take one branch and the assertions above pass for free.
        self.assertNotEqual(run_as("Darwin").stderr, run_as("Linux").stderr)


if __name__ == "__main__":
    unittest.main()
