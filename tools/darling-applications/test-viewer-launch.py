#!/usr/bin/env python3
"""Offline launch-wiring checks; never starts Darling or an app."""
from pathlib import Path
import os
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src/darling-applications/main.m"


class ViewerLaunchTests(unittest.TestCase):
    def test_workspace_reports_target_and_error(self):
        text = SOURCE.read_text()
        self.assertIn("launchApplicationAtURL:url options:0 configuration:nil error:&error", text)
        self.assertIn("viewer launch failed: bundle=%@ path=%@ error=%@", text)
        self.assertIn("DARLING_APPKIT_BACKEND", text)

    def test_known_apps_are_executable_when_fixture_is_supplied(self):
        root = os.environ.get("DARLING_APPLICATIONS_ROOT")
        if not root:
            self.skipTest("set DARLING_APPLICATIONS_ROOT for a read-only installed-app integrity check")
        for app in ("TextEdit.app", "Stickies.app"):
            executable = Path(root) / app / "Contents/MacOS" / app[:-4]
            self.assertTrue(executable.is_file(), executable)
            self.assertTrue(os.access(executable, os.X_OK), executable)


if __name__ == "__main__":
    unittest.main()
