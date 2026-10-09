import importlib.util
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('adapter',Path(__file__).with_name('build-swiftui-supplement.py'))
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
class ContractTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.root=Path(self.tmp.name);self.runtime=self.root/'runtime';self.runtime.mkdir();self.workspace=self.root/'build'
  self.config={'schema_version':1,'architecture':'arm64','sources':[{'path':'source','commit':'a'*40}], 'integration':{'link_targets':['link'],'install_targets':['install']},'targets':[{'name':'link','argv':['ld','-undefined','error'],'inputs':['source'],'outputs':['{workspace}/SwiftUI']},{'name':'install','argv':['cp'],'inputs':['{workspace}/SwiftUI'],'outputs':['{workspace}/image/System/Library/Frameworks/SwiftUI.framework/Versions/A/SwiftUI']}]}
 def test_full_contract_passes(self): self.assertEqual(len(a.validate(self.config,self.runtime,self.workspace)),1)
 def test_compile_only_rejected(self):
  del self.config['integration']
  with self.assertRaisesRegex(ValueError,'link_targets'): a.validate(self.config,self.runtime,self.workspace)
 def test_runtime_install_rejected(self):
  self.config['targets'][1]['outputs']=['{runtime_root}/SwiftUI']
  with self.assertRaisesRegex(ValueError,'escapes'): a.validate(self.config,self.runtime,self.workspace)
 def test_dynamic_lookup_rejected(self):
  self.config['targets'][0]['argv']=['ld','-undefined','dynamic_lookup']
  with self.assertRaisesRegex(ValueError,'strict'): a.validate(self.config,self.runtime,self.workspace)
 def test_dirty_source_opt_in_rejected(self):
  self.config['sources'][0]['allow_recorded_changes']=True
  with self.assertRaisesRegex(ValueError,'clean'): a.validate(self.config,self.runtime,self.workspace)
if __name__=='__main__': unittest.main()
