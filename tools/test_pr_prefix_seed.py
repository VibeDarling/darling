import hashlib
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "builder", Path(__file__).parent / "all-vibedarling-pr-prefix.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SeedTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("git-lfs"), "requires Git LFS")
    def test_seed_materializes_lfs_without_network_or_shared_objects(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            donor = root / "donor"
            donor.mkdir()
            builder.run("git", "init", cwd=donor)
            builder.run("git", "config", "user.name", "Fixture", cwd=donor)
            builder.run("git", "config", "user.email", "fixture@localhost", cwd=donor)
            builder.run("git", "lfs", "install", "--local", cwd=donor)
            (donor / ".gitattributes").write_text("*.payload filter=lfs diff=lfs merge=lfs -text\n")
            payload = b"Owned synthetic LFS fixture\n" * 100
            (donor / "framework.payload").write_bytes(payload)
            builder.run("git", "add", ".gitattributes", "framework.payload", cwd=donor)
            builder.run("git", "commit", "-m", "fixture: track synthetic LFS input", cwd=donor)
            sha = builder.run("git", "rev-parse", "HEAD", cwd=donor)
            baseline = root / "baseline"
            builder.run("git", "clone", "--no-local", "--no-checkout", str(donor), str(baseline))
            with self.assertRaises(RuntimeError):
                builder.run("git", "-c", "lfs.url=http://127.0.0.1:1/unavailable",
                            "checkout", sha, cwd=baseline)
            target = root / "target"
            builder.clone_repository("https://github.com/VibeDarling/fixture.git", target, donor)
            builder.run("git", "-c", "lfs.url=http://127.0.0.1:1/unavailable",
                        "checkout", sha, cwd=target)
            self.assertEqual((target / "framework.payload").read_bytes(), payload)
            digest = hashlib.sha256(payload).hexdigest()
            relative = Path(".git/lfs/objects") / digest[:2] / digest[2:4] / digest
            self.assertNotEqual((target / relative).stat().st_ino, (donor / relative).stat().st_ino)
            self.assertFalse((target / ".git/objects/info/alternates").exists())
            self.assertEqual(builder.run("git", "status", "--porcelain", cwd=donor), "")
            self.assertEqual(builder.run("git", "rev-parse", "HEAD", cwd=donor), sha)


if __name__ == "__main__":
    unittest.main()
