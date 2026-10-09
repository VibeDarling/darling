import importlib.util
import json
import sys
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "builder", Path(__file__).parent / "all-vibedarling-pr-prefix.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

BASE = "a" * 40
PR = {"number": 7, "repository_url": "https://api.github.com/repos/VibeDarling/darling",
      "html_url": "https://github.com/VibeDarling/darling/pull/7", "title": "t"}


def fake_git(*args, **kwargs):
    if args[:3] == ("git", "remote", "get-url"):
        return b.ROOT
    if args[:2] == ("git", "status"):
        return ""
    return BASE


def locked(item):
    return {**item, "branch": "main", "base": BASE, "off_branch_prs": []}


class NoPrsResolveTests(unittest.TestCase):
    def resolve(self, no_prs):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "refs.lock.json"
            args = SimpleNamespace(source=tmp, output=str(out), repo=None, jobs=1, no_prs=no_prs)
            with patch.object(b, "run", side_effect=fake_git), \
                    patch.object(b, "modules", return_value=[]), \
                    patch.object(b, "remote_refs", side_effect=locked), \
                    patch.object(b, "api", return_value={"base": {"ref": "main"}}), \
                    patch.object(b, "open_prs", return_value=[PR]) as prs:
                b.resolve(args)
            return json.loads(out.read_text()), prs

    def test_no_prs_skips_the_pr_search_entirely(self):
        lock, prs = self.resolve(True)
        prs.assert_not_called()
        self.assertEqual(lock["repos"][0]["prs"], [])
        self.assertEqual(lock["excluded_open_prs"], [])
        self.assertTrue(lock["complete"])
        self.assertTrue(lock["no_prs"])

    def test_default_still_locks_open_prs(self):
        lock, prs = self.resolve(False)
        prs.assert_called_once()
        self.assertEqual([p["number"] for p in lock["repos"][0]["prs"]], [7])
        self.assertFalse(lock["no_prs"])


class CommandLineTests(unittest.TestCase):
    def dispatched(self, *argv):
        with patch.object(sys, "argv", ["prefix", "resolve", "--output", "out.json", *argv]), \
                patch.object(b, "resolve") as resolve:
            self.assertEqual(b.main(), 0)
        return resolve.call_args.args[0]

    def test_no_prs_flag_reaches_resolve(self):
        self.assertTrue(self.dispatched("--no-prs").no_prs)

    def test_no_prs_defaults_to_false(self):
        self.assertFalse(self.dispatched().no_prs)


class NoPrsResolveNestedTests(unittest.TestCase):
    def resolve_nested(self, no_prs, top_no_prs=None):
        top_no_prs = no_prs if top_no_prs is None else top_no_prs
        occurrence = {"parent": "src/external/a", "path": "sub", "repo": "inner",
                      "url": "https://github.com/VibeDarling/inner.git",
                      "kind": "VibeDarling", "pin": BASE}
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp) / "workspace"
            workspace.mkdir()
            (workspace / "integrated.json").write_text("{}\n")
            (workspace / "refs.lock.json").write_text(json.dumps(
                {"repos": [{"repo": "darling"}], "excluded_open_prs": [], "no_prs": top_no_prs}))
            out = Path(tmp) / "nested.lock.json"
            args = SimpleNamespace(workspace=str(workspace), output=str(out), jobs=1, no_prs=no_prs)
            pr = {**PR, "repository_url": "https://api.github.com/repos/VibeDarling/inner"}
            with patch.object(b, "nested_modules", return_value=[occurrence]), \
                    patch.object(b, "remote_refs", side_effect=locked), \
                    patch.object(b, "api", return_value={"base": {"ref": "main"}}), \
                    patch.object(b, "open_prs", return_value=[pr]) as prs:
                b.resolve_nested(args)
            return json.loads(out.read_text()), prs

    def test_no_prs_skips_the_pr_search_entirely(self):
        lock, prs = self.resolve_nested(True)
        prs.assert_not_called()
        self.assertEqual(lock["vibedarling"][0]["prs"], [])
        self.assertTrue(lock["no_prs"])

    def test_no_prs_is_inherited_from_the_top_level_lock(self):
        lock, prs = self.resolve_nested(False, top_no_prs=True)
        prs.assert_not_called()
        self.assertEqual(lock["vibedarling"][0]["prs"], [])
        self.assertTrue(lock["no_prs"])

    def test_no_prs_flag_conflicting_with_the_top_level_lock_fails(self):
        with self.assertRaisesRegex(RuntimeError, "conflicts with the top-level lock"):
            self.resolve_nested(True, top_no_prs=False)

    def test_default_still_locks_open_prs(self):
        lock, prs = self.resolve_nested(False)
        prs.assert_called_once()
        self.assertEqual([p["number"] for p in lock["vibedarling"][0]["prs"]], [7])


class NestedCommandLineTests(unittest.TestCase):
    def dispatched(self, *argv):
        with patch.object(sys, "argv", ["prefix", "resolve-nested", "--workspace", "w", "--output", "o.json", *argv]), \
                patch.object(b, "resolve_nested") as resolve_nested:
            self.assertEqual(b.main(), 0)
        return resolve_nested.call_args.args[0]

    def test_no_prs_flag_reaches_resolve_nested(self):
        self.assertTrue(self.dispatched("--no-prs").no_prs)

    def test_no_prs_defaults_to_false_and_is_inherited_from_the_lock(self):
        self.assertFalse(self.dispatched().no_prs)
        with patch.object(sys, "argv", ["prefix", "resolve-nested", "--workspace", "w", "--output", "o.json"]):
            with tempfile.TemporaryDirectory() as tmp:
                workspace = Path(tmp)
                (workspace / "integrated.json").write_text("{}\n")
                (workspace / "refs.lock.json").write_text(json.dumps(
                    {"repos": [{"repo": "darling"}], "excluded_open_prs": [], "no_prs": True}))
                sys.argv[3] = str(workspace)
                sys.argv[5] = str(workspace / "nested.json")
                with patch.object(b, "nested_modules", return_value=[]), \
                        patch.object(b, "open_prs") as prs:
                    self.assertEqual(b.main(), 0)
                prs.assert_not_called()
                self.assertTrue(json.loads((workspace / "nested.json").read_text())["no_prs"])


if __name__ == "__main__":
    unittest.main()
