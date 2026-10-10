import importlib.util
from pathlib import Path
from unittest.mock import patch
import unittest
s=importlib.util.spec_from_file_location('builder',Path(__file__).with_name('all-vibedarling-pr-prefix.py'));b=importlib.util.module_from_spec(s);s.loader.exec_module(b)
class MissingRefTests(unittest.TestCase):
 def setUp(self):
  self.base='a'*40;self.head='b'*40
  self.item={'repo':'indium','url':'https://github.com/VibeDarling/indium.git','prs':[{'number':18}]}
  self.detail={'state':'open','merged':False,'head':{'sha':self.head,'ref':'fix/identity','repo':{'clone_url':'https://github.com/author/indium.git'}}}
 def fake_git(self,*args,**kw):
  if self.item['url'] in args:return 'ref: refs/heads/main\tHEAD\n'+self.base+'\tHEAD\n'+self.base+'\trefs/heads/main'
  return self.head+'\trefs/heads/fix/identity'
 def test_exact_open_declared_fork_is_locked_with_reason(self):
  with patch.object(b,'api',return_value=self.detail),patch.object(b,'run',side_effect=self.fake_git):r=b.remote_refs(self.item)
  p=r['prs'][0];self.assertEqual(p['head'],self.head);self.assertEqual(p['head_source']['sha'],self.head)
  self.assertIn('missing refs/pull/18/head',p['head_source']['reason'])
 def test_closed_pr_fails(self):
  self.detail['state']='closed'
  with patch.object(b,'api',return_value=self.detail),patch.object(b,'run',side_effect=self.fake_git):
   with self.assertRaisesRegex(RuntimeError,'not open'):b.remote_refs(self.item)
 def test_changed_fork_ref_fails(self):
  self.detail['head']['sha']='c'*40
  with patch.object(b,'api',return_value=self.detail),patch.object(b,'run',side_effect=self.fake_git):
   with self.assertRaisesRegex(RuntimeError,'differs'):b.remote_refs(self.item)
if __name__=='__main__':unittest.main()
