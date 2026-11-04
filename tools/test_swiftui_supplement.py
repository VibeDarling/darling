import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('adapter', Path(__file__).with_name('build-swiftui-supplement.py'))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.runtime = self.root / 'runtime'
        self.runtime.mkdir()
        self.workspace = self.root / 'build'
        self.config = {
            'schema_version': 1, 'architecture': 'arm64',
            'sources': [{'path': 'source', 'commit': 'a' * 40}],
            'integration': {'link_targets': ['link'], 'install_targets': ['install']},
            'targets': [
                {'name': 'link', 'argv': ['ld', '-undefined', 'error'], 'inputs': ['source'],
                 'outputs': ['{workspace}/SwiftUI']},
                {'name': 'install', 'argv': ['cp'], 'inputs': ['{workspace}/SwiftUI'],
                 'outputs': ['{workspace}/image/System/Library/Frameworks/SwiftUI.framework/Versions/A/SwiftUI']},
            ]}

    def validate(self):
        return a.validate(self.config, self.runtime, self.workspace)

    def test_full_contract_passes(self):
        self.assertEqual(len(self.validate()), 1)

    def test_wl_error_form_passes(self):
        self.config['targets'][0]['argv'] = ['clang', '-Wl,-undefined,error']
        self.validate()

    def test_compile_only_rejected(self):
        del self.config['integration']
        with self.assertRaisesRegex(ValueError, 'link_targets'):
            self.validate()

    def test_runtime_install_rejected(self):
        self.config['targets'][1]['outputs'] = ['{runtime_root}/SwiftUI']
        with self.assertRaisesRegex(ValueError, 'escapes'):
            self.validate()

    def test_lenient_link_rejected(self):
        for argv in (['ld', '-undefined', 'dynamic_lookup'], ['ld', '-undefined', 'suppress'],
                     ['ld', '-undefined', 'warning'], ['ld', '-undefined'],
                     ['clang', '-Wl,-undefined,suppress'], ['clang', '-Wl,-undefined,dynamic_lookup'],
                     ['ld', '-undefined suppress'], ['ld', '-flat_namespace'],
                     ['clang', '-Wl,-flat_namespace'], ['ld', '-U', '_foo'],
                     ['clang', '-Wl,-U,_foo']):
            with self.subTest(argv=argv):
                self.config['targets'][0]['argv'] = argv
                with self.assertRaisesRegex(ValueError, 'strict'):
                    self.validate()

    def test_missing_argv_rejected(self):
        del self.config['targets'][0]['argv']
        with self.assertRaisesRegex(ValueError, 'argv'):
            self.validate()

    def test_dirty_source_opt_in_rejected(self):
        self.config['sources'][0]['allow_recorded_changes'] = True
        with self.assertRaisesRegex(ValueError, 'clean'):
            self.validate()


if __name__ == '__main__':
    unittest.main()
