import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "builder", Path(__file__).parent / "all-vibedarling-pr-prefix.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class DivergedPullRequestTests(unittest.TestCase):
    def git(self, repo, *args):
        return b.run("git", "-c", "user.name=Fixture", "-c", "user.email=fixture@localhost", *args, cwd=repo)

    def commit(self, repo, name):
        (repo / name).write_text(name)
        self.git(repo, "add", name)
        self.git(repo, "commit", "-m", f"fixture: {name}")
        return self.git(repo, "rev-parse", "HEAD")

    def test_pr_branched_behind_the_tip_merges_in_a_shallow_clone(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            upstream = root / "upstream"
            upstream.mkdir()
            self.git(upstream, "init", "-b", "main")
            self.git(upstream, "config", "uploadpack.allowAnySHA1InWant", "true")
            self.commit(upstream, "a")
            fork_point = self.commit(upstream, "b")
            self.commit(upstream, "c")
            tip = self.commit(upstream, "d")
            self.git(upstream, "checkout", "-b", "pr", fork_point)
            head = self.commit(upstream, "pr-change")
            self.git(upstream, "checkout", "main")
            item = {"repo": "fixture", "paths": ["sub"], "url": upstream.as_uri(), "branch": "main",
                    "base": tip, "prs": [{"number": 1, "head": head, "ref": "refs/heads/pr"}]}
            source = root / "source"
            source.mkdir()
            _, merged = b.clone_and_integrate(source, item, None)
            target = source / "sub"
            self.assertEqual(self.git(target, "rev-parse", "--is-shallow-repository"), "false")
            self.assertEqual(self.git(target, "rev-parse", "HEAD^1"), tip)
            self.assertEqual(self.git(target, "rev-parse", "HEAD^2"), head)
            self.assertTrue((target / "pr-change").is_file() and (target / "d").is_file())
            self.assertEqual(self.git(target, "rev-parse", "HEAD"), merged)


if __name__ == "__main__":
    unittest.main()
