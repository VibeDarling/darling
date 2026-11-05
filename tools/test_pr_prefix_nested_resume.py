import hashlib
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
s=importlib.util.spec_from_file_location('builder',Path(__file__).with_name('all-vibedarling-pr-prefix.py'));b=importlib.util.module_from_spec(s);s.loader.exec_module(b)
class NestedResumeTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.w=Path(self.tmp.name);self.s=self.w/'source';self.s.mkdir()
  for a in [('init',),('config','user.name','Fixture'),('config','user.email','fixture@localhost')]:b.run('git',*a,cwd=self.s)
  (self.s/'.gitmodules').write_text('');b.run('git','add','.',cwd=self.s);b.run('git','commit','-m','fixture: define empty nested map',cwd=self.s)
  self.top=self.w/'refs.lock.json';self.top.write_text(json.dumps({'repos':[{'repo':'darling','paths':['.']}]}))
  self.lock=self.w/'input.json';self.lock.write_text(json.dumps({'schema':1,'owner':'VibeDarling','top_lock_sha256':hashlib.sha256(self.top.read_bytes()).hexdigest(),'vibedarling':[],'external_pinned':[]}))
  self.args=SimpleNamespace(workspace=str(self.w),lock=str(self.lock),resume=True,resolutions=None,seed_submodules_root=None)
 def test_retains_exact_lock_and_completes(self):
  b.checkout_nested(self.args);self.assertEqual(self.lock.read_bytes(),(self.w/'nested.refs.lock.json').read_bytes());self.assertEqual(json.loads((self.w/'nested.integrated.json').read_text()),[])
  with self.assertRaisesRegex(RuntimeError,'completed'):b.checkout_nested(self.args)
 def test_changed_retained_lock_rejected(self):
  (self.w/'nested.refs.lock.json').write_text('{}')
  with self.assertRaisesRegex(RuntimeError,'differs'):b.checkout_nested(self.args)
  self.assertFalse((self.w/'nested.integrated.json').exists())
 def test_existing_build_rejected(self):
  (self.w/'build').mkdir()
  with self.assertRaisesRegex(RuntimeError,'unbuilt'):b.checkout_nested(self.args)
 def test_wrong_top_lock_rejected(self):
  self.top.write_text(self.top.read_text()+'\n')
  with self.assertRaisesRegex(RuntimeError,'different top'):b.checkout_nested(self.args)
if __name__=='__main__':unittest.main()
