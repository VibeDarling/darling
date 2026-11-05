import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "builder", Path(__file__).parent / "all-vibedarling-pr-prefix.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SupplementTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.donor = root / "donor"
        self.donor.mkdir()
        self.git(self.donor, "init")
        self.identity(self.donor)
        self.git(self.donor, "remote", "add", "origin",
                 "https://github.com/VibeDarling/darling-cocotron.git")
        self.commit_file(self.donor, "shared.txt", "base\n")
        self.base = self.git(self.donor, "rev-parse", "HEAD")
        self.workspace = root / "workspace"
        self.source = self.workspace / "source"
        self.source.mkdir(parents=True)
        self.git(self.source, "init")
        self.identity(self.source)
        self.path = "src/external/cocotron"
        self.target = self.source / self.path
        self.target.parent.mkdir(parents=True)
        builder.run("git", "clone", "--no-local", str(self.donor), str(self.target))
        self.identity(self.target)
        self.commit_file(self.target, "open-pr.txt", "preserve locked PR\n")
        self.commit_file(self.source, ".gitmodules",
                         '[submodule "cocotron"]\n'
                         f' path = {self.path}\n url = ../darling-cocotron.git\n')
        self.git(self.source, "add", self.path)
        self.git(self.source, "commit", "-m", "fixture: pin locked source")
        (self.workspace / "integrated.json").write_text('{}\n')
        (self.workspace / "refs.lock.json").write_text(json.dumps({"repos": [
            {"repo": "darling"}, {"repo": "darling-cocotron", "paths": [self.path]}]}))

    def git(self, repo, *args):
        return builder.run("git", *args, cwd=repo)

    def identity(self, repo):
        self.git(repo, "config", "user.name", "Fixture")
        self.git(repo, "config", "user.email", "fixture@localhost")

    def commit_file(self, repo, name, text):
        (repo / name).write_text(text)
        self.git(repo, "add", name)
        self.git(repo, "commit", "-m", "fixture: update input")
        return self.git(repo, "rev-parse", "HEAD")

    def apply(self, commit):
        builder.supplement(SimpleNamespace(
            workspace=str(self.workspace), path=self.path,
            from_repo=str(self.donor), commit=commit,
            reason="fixture verifies committed source supplementation"))

    def test_merges_fix_preserves_pr_and_records_exact_source(self):
        commit = self.commit_file(self.donor, "fix.txt", "measurement fix\n")
        lock = (self.workspace / "refs.lock.json").read_bytes()
        donor_head = self.git(self.donor, "rev-parse", "HEAD")
        self.apply(commit)
        self.assertEqual((self.target / "open-pr.txt").read_text(), "preserve locked PR\n")
        self.assertEqual((self.target / "fix.txt").read_text(), "measurement fix\n")
        self.assertEqual(self.git(self.donor, "rev-parse", "HEAD"), donor_head)
        self.assertEqual(self.git(self.donor, "status", "--porcelain"), "")
        self.assertEqual(self.git(self.source, "status", "--porcelain"), "")
        self.assertEqual((self.workspace / "refs.lock.json").read_bytes(), lock)
        record = json.loads((self.workspace / "supplements.json").read_text())["inputs"][0]
        self.assertEqual(record["commit"], commit)
        self.assertEqual(record["status"], "complete")
        self.assertEqual(record["superproject_result"], self.git(self.source, "rev-parse", "HEAD"))

    def test_missing_commit_leaves_source_unchanged(self):
        head = self.git(self.source, "rev-parse", "HEAD")
        with self.assertRaises(RuntimeError):
            self.apply("f" * 40)
        self.assertEqual(head, self.git(self.source, "rev-parse", "HEAD"))
        self.assertEqual(self.git(self.source, "status", "--porcelain"), "")

    def test_configured_workspace_rejected(self):
        (self.workspace / "build").mkdir()
        with self.assertRaisesRegex(RuntimeError, "unconfigured"):
            self.apply(self.base)

    def test_conflict_recorded_and_retained_for_inspection(self):
        commit = self.commit_file(self.donor, "shared.txt", "donor change\n")
        self.commit_file(self.target, "shared.txt", "locked PR change\n")
        self.git(self.source, "add", self.path)
        self.git(self.source, "commit", "-m", "fixture: pin conflicting PR")
        with self.assertRaisesRegex(RuntimeError, "supplement failed"):
            self.apply(commit)
        record = json.loads((self.workspace / "supplements.json").read_text())["inputs"][0]
        self.assertEqual(record["status"], "failed")
        self.assertEqual(record["conflicts"], ["shared.txt"])
        self.assertIn("shared.txt", self.git(self.target, "diff", "--name-only", "--diff-filter=U"))

    def test_gitlink_addition_requires_new_dependency_lock(self):
        self.git(self.donor, "update-index", "--add", "--cacheinfo", "160000", self.base, "nested")
        self.git(self.donor, "commit", "-m", "fixture: add nested dependency")
        with self.assertRaisesRegex(RuntimeError, "nested gitlinks"):
            self.apply(self.git(self.donor, "rev-parse", "HEAD"))
        self.assertEqual(self.git(self.source, "status", "--porcelain"), "")

    def configure_fixture(self):
        self.commit_file(self.source, "CMakeLists.txt", "cmake_minimum_required(VERSION 3.16)\n"
                         "project(PrivateFixture NONE)\n"
                         "configure_file(revision.txt revision.txt COPYONLY)\n")
        self.commit_file(self.source, "revision.txt", "first revision\n")
        args = SimpleNamespace(workspace=str(self.workspace), jobs=2,
                               cmake_arg=[], configure_only=True, reconfigure=False)
        builder.build(args)
        return args

    def test_source_correction_requires_opt_in_and_records_reconfiguration(self):
        args = self.configure_fixture()
        marker = self.workspace / "build/.darling-pr-prefix-source"
        previous = marker.read_text().strip()
        corrected = self.commit_file(self.source, "revision.txt", "corrected revision\n")
        with self.assertRaisesRegex(RuntimeError, "does not match"):
            builder.build(args)
        self.assertEqual(marker.read_text().strip(), previous)
        args.reconfigure = True
        builder.build(args)
        self.assertEqual(marker.read_text().strip(), corrected)
        self.assertEqual((self.workspace / "build/revision.txt").read_text(), "corrected revision\n")
        history = json.loads((self.workspace / "build/.darling-pr-prefix-history.json").read_text())
        self.assertEqual(history[-1]["previous_source"], previous)
        self.assertEqual(history[-1]["source"], corrected)

    def test_reconfiguration_refuses_an_existing_prefix(self):
        args = self.configure_fixture()
        marker = self.workspace / "build/.darling-pr-prefix-source"
        previous = marker.read_text()
        (self.workspace / "prefix").mkdir()
        args.reconfigure = True
        with self.assertRaisesRegex(RuntimeError, "must not exist"):
            builder.build(args)
        self.assertEqual(marker.read_text(), previous)


if __name__ == "__main__":
    unittest.main()
