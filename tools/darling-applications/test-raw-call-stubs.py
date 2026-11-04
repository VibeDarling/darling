#!/usr/bin/env python3
from pathlib import Path
import platform
import runpy
import subprocess
import tempfile
import unittest

TOOL = runpy.run_path(str(Path(__file__).with_name("raw-call-stubs.py")))


class RawCallTest(unittest.TestCase):
    def test_names_do_not_establish_signatures(self):
        for name, category in [("_OBJC_CLASS_$_Fixture", "objc-class-data"),
                               ("_OBJC_METACLASS_$_Fixture", "objc-metaclass-data"),
                               ("_$s7Fixture", "swift-mangled"),
                               ("__Z7fixturev", "cxx-mangled"),
                               ("_Fixture", "unclassified")]:
            result = TOOL["name_information"](name)
            self.assertEqual(result["category"], category)
            self.assertFalse(result["signature_established"])

    def test_class_data_and_unsupported_callable_exports_are_rejected(self):
        for record in [{"symbol": "_Fixture", "kind": "function"},
                       {"symbol": "_OBJC_CLASS_$_Fixture", "kind": "function",
                        "evidence": "authored fixture"}]:
            with tempfile.TemporaryDirectory() as directory:
                with self.assertRaises(ValueError):
                    TOOL["generate"]([record], Path(directory) / "generated")

    def test_macho_compiles_and_exports_authored_function(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "generated"
            TOOL["generate"]([{"symbol": "_Fixture", "kind": "function",
                               "evidence": "authored test fixture"}], root)
            for source in ["logger.c", "entries.S"]:
                subprocess.run(["clang", "-target", "arm64-apple-macos11",
                                "-Wall", "-Wextra", "-Werror", "-c", str(root / source),
                                "-o", str(root / (source + ".o"))],
                               check=True, capture_output=True)
            exports = subprocess.run(["llvm-nm", "-gU", "-j", str(root / "entries.S.o")],
                                     check=True, capture_output=True, text=True).stdout
            self.assertIn("_Fixture", exports.splitlines())

    @unittest.skipUnless(platform.machine() == "aarch64", "Native arm64 required")
    def test_actual_entry_preserves_integer_pointer_and_fp_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "generated"
            TOOL["generate"]([{"symbol": "_Fixture", "kind": "function",
                               "evidence": "authored test fixture"}], root, False)
            (root / "fixture.c").write_text(
                'extern void fixture(long long, void *, double, float) __asm__("_Fixture");\n'
                'int main(void) { fixture(-42, (void *)1, 3.25, -2.5f); return 99; }\n')
            executable = root / "fixture"
            subprocess.run(["clang", "-Wall", "-Wextra", "-Werror",
                            str(root / "logger.c"), str(root / "entries.S"),
                            str(root / "fixture.c"), "-o", str(executable)],
                           check=True, capture_output=True)
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 78)
            self.assertIn("Darling diagnostic call: _Fixture", result.stderr)
            self.assertIn("x0 raw=0xffffffffffffffd6", result.stderr)
            self.assertIn("i64=-42", result.stderr)
            self.assertIn("x1 raw=0x0000000000000001", result.stderr)
            self.assertIn("v-low0 raw=0x400a000000000000", result.stderr)
            self.assertIn("f64=0x1.ap+1", result.stderr)
            self.assertIn("f32=-0x1.4p+1", result.stderr)
            self.assertIn("q7 raw128=", result.stderr)
            self.assertIn("object=unverified-address", result.stderr)
            self.assertNotIn("argument0=", result.stderr)


if __name__ == "__main__":
    unittest.main()
