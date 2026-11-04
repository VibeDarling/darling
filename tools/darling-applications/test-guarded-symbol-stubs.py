#!/usr/bin/env python3
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest


TOOL = runpy.run_path(str(Path(__file__).with_name("guarded-symbol-stubs.py")))


class GuardedStubsTest(unittest.TestCase):
    def test_authored_object_exports_classes_metaclasses_and_opaque_names(self):
        symbols = ["_OBJC_CLASS_$_FixtureClass", "_OBJC_METACLASS_$_FixtureClass",
                   "_FixtureUnknown", "_$s7FixtureUnknown"]
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "fixture.m"
            source.write_text(TOOL["source_for"]("/System/Fixture", symbols))
            obj = source.with_suffix(".o")
            subprocess.run(["clang", "-target", "arm64-apple-macos11", "-c",
                            str(source), "-o", str(obj)], check=True, capture_output=True)
            exports = subprocess.run(["llvm-nm", "-gU", "-j", str(obj)], check=True,
                                     capture_output=True, text=True).stdout.splitlines()
            self.assertTrue(set(symbols).issubset(exports))
            self.assertIn("_write", subprocess.run(["llvm-nm", "-u", str(obj)],
                          check=True, capture_output=True, text=True).stdout)

    def test_invalid_demand_is_rejected(self):
        for name, symbols in [("/System/../Fixture", ["_Valid"]),
                              ("/tmp/Fixture", ["_Valid"]),
                              ("/System/Fixture", ["_Bad;injection"]),
                              ("/System/Fixture", ["_Same", "_Same"]),
                              ("/System/Fixture", [])]:
            with self.subTest(name=name, symbols=symbols), self.assertRaises(ValueError):
                TOOL["source_for"](name, symbols)

    def test_generation_preserves_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scan = root / "scan.json"
            scan.write_text(json.dumps([{"missing": {"/System/Fixture": ["_Fixture"]}}]))
            output = root / "output"
            TOOL["generate"](scan, output, root / "runtime", "arm64")
            manifest = json.loads((output / "manifest.json").read_text())
            self.assertTrue(manifest["diagnostic_only"])
            with self.assertRaises(ValueError):
                TOOL["generate"](scan, output, root / "runtime", "arm64")


if __name__ == "__main__":
    unittest.main()
