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


if __name__ == "__main__":
    unittest.main()
