import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
spec=importlib.util.spec_from_file_location('builder',Path(__file__).with_name('all-vibedarling-pr-prefix.py'))
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
class BuildStageTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.w=Path(self.tmp.name);self.s=self.w/'source';self.s.mkdir()
  for args in [('init',),('config','user.name','Fixture'),('config','user.email','fixture@localhost')]:b.run('git',*args,cwd=self.s)
  (self.s/'.gitmodules').write_text('')
  (self.s/'input.txt').write_text('authored runtime fixture\n')
  (self.s/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.16)\nproject(Fixture NONE)\nadd_custom_command(OUTPUT artifact.txt COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/input.txt artifact.txt DEPENDS ${CMAKE_SOURCE_DIR}/input.txt)\nadd_custom_target(artifact ALL DEPENDS artifact.txt)\ninstall(FILES ${CMAKE_BINARY_DIR}/artifact.txt DESTINATION lib)\n')
  b.run('git','add','.',cwd=self.s);b.run('git','commit','-m','fixture: define source stage',cwd=self.s)
  (self.w/'integrated.json').write_text('{}')
  (self.w/'refs.lock.json').write_text('{"repos": [{"repo": "darling", "paths": ["."]}]}')
 def args(self):return SimpleNamespace(workspace=str(self.w),jobs=1,configure_only=False,stage_only=True,cmake_arg=[],reconfigure=False)
 def test_stage_then_incremental_preserves_image_and_omits_prefix(self):
  b.build(self.args());artifact=self.w/'image/usr/local/lib/artifact.txt'; before=artifact.stat().st_mtime_ns
  self.assertEqual(artifact.read_text(),'authored runtime fixture\n');self.assertFalse((self.w/'prefix').exists())
  b.verify_build(self.args());self.assertEqual(before,artifact.stat().st_mtime_ns)
  self.assertTrue((self.w/'incremental.verify.json').exists())
 def test_changed_binding_rejected_before_rebuilding(self):
  b.build(self.args());(self.w/'build/.darling-pr-prefix-source').write_text('0'*40)
  with self.assertRaisesRegex(RuntimeError,'binding'):b.verify_build(self.args())
if __name__=='__main__':unittest.main()
