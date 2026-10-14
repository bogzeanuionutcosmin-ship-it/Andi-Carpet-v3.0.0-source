"""Regression guard: Dart test entrypoints belong in Flutter's test/ suite."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LedgerTestDiscoveryTests(unittest.TestCase):
    def test_no_dart_test_entrypoints_hidden_under_lib(self):
        misplaced = sorted(
            str(path.relative_to(ROOT))
            for path in (ROOT / "lib").rglob("*_test.dart")
        )
        self.assertEqual(misplaced, [], "flutter test test/ skips these files")

    def test_migrated_financial_regressions_are_discoverable(self):
        source = (ROOT / "test/per_diem_ledger_edge_cases_test.dart").read_text(
            encoding="utf-8"
        )
        self.assertIn("package:andi_carpeta/finance/per_diem_ledger.dart", source)
        names = [
            "Pending becomes paid without double counting",
            "Partial confirmation is accounted at received amount",
            "Duplicate ID across different pairs is rejected",
            "Reversal cannot predate original",
            "Confirmed reversal removes paid amount",
        ]
        for name in names:
            with self.subTest(name=name):
                self.assertEqual(source.count("test('" + name + "'"), 1)
