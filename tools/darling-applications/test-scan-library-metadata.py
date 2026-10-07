#!/usr/bin/env python3
"""Exercise dependency inspection using only locally authored Mach-O images."""
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


class LibraryMetadataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        cls.expected = {}
        slices = []
        for arch in ("arm64", "x86_64"):
            source = cls.root / f"{arch}.c"
            source.write_text("int fixture(void) { return 1; }\n")
            obj = source.with_suffix(".o")
            cls.command("clang", "-target", f"{arch}-apple-macos11", "-c", source, "-o", obj)
            base = ["ld64.lld", "-arch", arch, "-platform_version", "macos", "11.0", "11.0", "-dylib", obj]
            dependencies = []
            cls.expected[arch] = []
            for kind, flag, command in (
                ("ordinary", None, "LC_LOAD_DYLIB"),
                ("weak", "-weak_library", "LC_LOAD_WEAK_DYLIB"),
                ("reexport", "-reexport_library", "LC_REEXPORT_DYLIB"),
            ):
                name = f"/fixture/{arch}/{kind} library.dylib"
                dep = cls.root / f"{arch}-{kind}.dylib"
                cls.command(*base, "-install_name", name, "-o", dep)
                dependencies.extend([flag, dep] if flag else [dep])
                cls.expected[arch].append((command, name))
            image = cls.root / f"{arch}.dylib"
            cls.command(*base, "-install_name", "/fixture/own-id.dylib", *dependencies, "-o", image)
            slices.append(image)
        cls.image = cls.root / "universal.dylib"
        cls.command("llvm-lipo", "-create", *slices, "-output", cls.image)
        with patch.dict(os.environ, {
            "VIBEDARLING_APP_ROOT": str(cls.root / "empty"),
            "VIBEDARLING_EXTRA_APP": "",
            "VIBEDARLING_SCAN_OUTPUT": str(cls.root / "scan"),
        }), patch.object(__import__("sys"), "argv", ["scanner"]):
            cls.scanner = runpy.run_path(str(Path(__file__).with_name("scan-imported-apps.py")))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    @staticmethod
    def command(*args):
        subprocess.run([str(a) for a in args], check=True, capture_output=True, text=True)

    def test_universal_dependency_kinds_without_full_load_command_dump(self):
        original = subprocess.run

        def metadata_only(args, **kwargs):
            self.assertFalse(args[0] == "llvm-otool" and "-l" in args,
                             "full load-command dumps violate the clean-room tool policy")
            if args[0] == "llvm-objdump":
                self.assertTrue("--dylibs-used" in args or "--dylib-id" in args)
                self.assertNotIn("--disassemble", args)
            return original(args, **kwargs)

        with patch("subprocess.run", side_effect=metadata_only):
            for arch in self.expected:
                with self.subTest(arch=arch):
                    actual = self.scanner["dylib_commands"](str(self.image), arch)
                    self.assertCountEqual(actual, self.expected[arch])

    def test_metadata_tool_failure_is_not_an_empty_dependency_list(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.scanner["dylib_commands"](str(self.root / "missing.dylib"), "arm64")

    def test_upward_and_lazy_metadata(self):
        output = ("fixture:\n"
                  "\t/upward.dylib (compatibility version 1.0.0, current version 1.0.0, upward)\n"
                  "\t/lazy.dylib (compatibility version 1.0.0, current version 1.0.0, lazy)\n")
        with patch("subprocess.run", side_effect=[
            subprocess.CompletedProcess([], 0, stdout="fixture:\n"),
            subprocess.CompletedProcess([], 0, stdout=output),
        ]):
            self.assertEqual(self.scanner["dylib_commands"]("fixture", "arm64"), [
                ("LC_LOAD_UPWARD_DYLIB", "/upward.dylib"),
                ("LC_LAZY_LOAD_DYLIB", "/lazy.dylib"),
            ])


if __name__ == "__main__":
    unittest.main()
