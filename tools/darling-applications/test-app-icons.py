#!/usr/bin/env python3
"""Offline source-text checks for bundle icon loading; never starts Darling or an app.

NSWorkspace iconForFile:/iconForFileType: are unimplemented stubs in this
AppKit build and return nil, so the viewer must read bundle icons directly
from Info.plist + .icns instead of relying on them.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src/darling-applications/main.m"


class AppIconLoadingTests(unittest.TestCase):
    def test_icons_are_read_from_bundle_not_workspace_stubs(self):
        text = SOURCE.read_text()
        self.assertNotIn("iconForFile:", text)
        self.assertNotIn("iconForFileType:", text)
        self.assertIn("BundleIconForApplication(path)", text)

    def test_missing_icon_falls_back_to_a_generic_icon_not_a_blank_cell(self):
        text = SOURCE.read_text()
        self.assertIn("if (icon == (id)[NSNull null] || !icon) icon = GenericApplicationIcon();", text)


if __name__ == "__main__":
    unittest.main()
