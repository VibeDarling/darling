#!/usr/bin/env python3
"""Pure parser tests; no Darling prefix, Brewfile, or package manager access."""
import importlib.util
import unittest

SPEC = importlib.util.spec_from_file_location("homebrew_actions", __file__.replace("test-homebrew-actions.py", "homebrew-actions.py"))
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


class MasEntryTests(unittest.TestCase):
    def test_standard_and_parenthesized(self):
        self.assertEqual(MODULE.mas_entries('mas "Foo", id: 123\nmas("Bar", id: 456)\n'), [("Foo", "123"), ("Bar", "456")])

    def test_multiline_conditional_is_not_executed(self):
        text = 'if ENV["IMPORT_MAS"]\n  mas "Long Name",\n      id: 789\nend\nbrew "git"\n'
        self.assertEqual(MODULE.mas_entries(text), [("Long Name", "789")])

    def test_unsafe_declaration_fails_closed(self):
        with self.assertRaises(SystemExit):
            MODULE.mas_entries('mas "Missing id"\n')


if __name__ == "__main__":
    unittest.main()
