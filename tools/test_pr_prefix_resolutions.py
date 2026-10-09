import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('builder', Path(__file__).with_name('all-vibedarling-pr-prefix.py'))
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

class ResolutionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.r = Path(self.tmp.name)
        self.git('init'); self.git('config','user.name','Fixture'); self.git('config','user.email','fixture@localhost')
        (self.r/'base').write_text('base\n'); self.git('add','.'); self.git('commit','-m','fixture: base')
        base = self.git('rev-parse','HEAD')
        (self.r/'header').write_text('ours\n'); self.git('add','.'); self.git('commit','-m','fixture: ours')
        ours = self.git('rev-parse','HEAD')
        self.git('checkout','--detach',base)
        (self.r/'header').write_text('theirs\n'); self.git('add','.'); self.git('commit','-m','fixture: theirs')
        self.head = self.git('rev-parse','HEAD'); self.git('checkout','--detach',ours)
        try: self.git('merge','--no-edit',self.head)
        except RuntimeError: pass
        self.rule = dict(repo='darling-cocotron',pr=390,head=self.head,before_tree=self.git('rev-parse','HEAD^{tree}'),stages=self.git('ls-files','--unmerged'),files={'header':'ours\ntheirs\n'},reason='authored fixture')
    def git(self,*a): return b.run('git',*a,cwd=self.r)
    def apply(self): b.resolve_conflict(self.r,dict(repo='darling-cocotron'),dict(number=390,head=self.head),None)
    def test_exact_resolution_preserves_both_parents_and_audits(self):
        b.RESOLUTIONS=[self.rule]; self.apply()
        self.assertEqual(self.git('status','--porcelain'),'')
        self.git('merge-base','--is-ancestor',self.head,'HEAD')
        audit=json.loads((self.r/'.git/darling-pr-resolutions.json').read_text())[0]
        self.assertEqual(audit['result_tree'],self.git('rev-parse','HEAD^{tree}'))
        self.assertEqual(audit['result_blobs']['header'],self.git('rev-parse','HEAD:header'))
    def test_changed_conflict_stage_is_rejected_without_changes(self):
        b.RESOLUTIONS=[{**self.rule,'stages':'wrong'}]; before=(self.r/'header').read_bytes()
        with self.assertRaises(RuntimeError): self.apply()
        self.assertEqual(before,(self.r/'header').read_bytes())
        self.assertTrue((self.r/'.git/MERGE_HEAD').exists())
    def test_extra_resolved_path_is_rejected(self):
        b.RESOLUTIONS=[{**self.rule,'files':{'header':'resolved','extra':'unapproved'}}]
        with self.assertRaises(RuntimeError): self.apply()
        self.assertFalse((self.r/'extra').exists())

if __name__=='__main__': unittest.main()
