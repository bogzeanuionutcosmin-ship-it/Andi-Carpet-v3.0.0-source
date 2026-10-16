"""The proposed pin union must fail closed when either catalog loses a guard."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('compatibility_audit', Path(__file__).resolve().parents[1] / 'scripts/audit_finance_privacy_compatibility.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class CompatibilityUnion(unittest.TestCase):
    def test_disjoint_changes_preserve_both_and_untouched_guards(self):
        union, finance, privacy = audit.proposed_union(
            {'expense': 'old', 'home': 'old', 'auth': 'same'},
            {'expense': 'new-finance', 'home': 'old', 'auth': 'same'},
            {'expense': 'old', 'home': 'new-privacy', 'auth': 'same'})
        self.assertEqual(union, {'expense': 'new-finance', 'home': 'new-privacy', 'auth': 'same'})
        self.assertEqual(finance, {'expense': 'new-finance'})
        self.assertEqual(privacy, {'home': 'new-privacy'})

    def test_missing_guard_is_rejected(self):
        with self.assertRaises(ValueError):
            audit.proposed_union({'a': '1', 'b': '2'}, {'a': '1'}, {'a': '1', 'b': '2'})

    def test_extra_guard_requires_review(self):
        with self.assertRaises(ValueError):
            audit.proposed_union({'a': '1'}, {'a': '1'}, {'a': '1', 'b': '2'})

    def test_conflicting_source_changes_are_rejected(self):
        with self.assertRaises(ValueError):
            audit.proposed_union({'a': '1'}, {'a': 'finance'}, {'a': 'privacy'})
