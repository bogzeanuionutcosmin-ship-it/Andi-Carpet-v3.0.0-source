"""Financial listener extraction: read-only structural checks, no live Firebase."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HomeFinancialSyncContracts(unittest.TestCase):
    def test_new_part_is_unique_and_original_method_is_not_duplicated(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        source = (ROOT / "lib/home/home_financial_sync.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(main.count("part 'home/home_financial_sync.dart';"), 1)
        self.assertTrue(source.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeFinancialSync on _HomePageState {", source)
        self.assertEqual(source.count("  void _startFinancialSync() {"), 1)
        self.assertNotIn("  void _startFinancialSync() {", home)
        self.assertIn("    _startFinancialSync();", home)

    def test_team_scope_and_subscriptions_stay_unchanged(self):
        source = (ROOT / "lib/home/home_financial_sync.dart").read_text(
            encoding="utf-8"
        )
        self.assertIn("isAdmin || hasPermission(FunctionPermission.viewOtherDecont)", source)
        self.assertIn("final scope = canViewAll ? '*' : me.teamId;", source)
        self.assertIn("if (_financialTeamScope == scope) return;", source)
        self.assertIn("_financialTeamScope = scope;", source)
        self.assertIn("for (final sub in _financialSubscriptions) { sub.cancel(); }", source)
        self.assertIn("_financialSubscriptions.clear();", source)
        self.assertIn("if (scope == null || scope.isEmpty)", source)
        self.assertEqual(source.count("_financialSubscriptions.add("), 4)
        self.assertEqual(source.count(".snapshots().listen("), 4)
        names = ("expenses", "perDiems", "finance", "settlements")
        offsets = []
        for name in names:
            with self.subTest(collection=name):
                needle = "db.collection('" + name + "')"
                self.assertEqual(source.count(needle), 2)
                offsets.append(source.index(needle))
                self.assertIn(".where('teamId',isEqualTo:scope)", source)
        self.assertEqual(offsets, sorted(offsets))
        self.assertIn(
            "for (final sub in _financialSubscriptions) { sub.cancel(); }",
            (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8"),
        )

    def test_financial_converters_and_error_messages_are_preserved(self):
        source = (ROOT / "lib/home/home_financial_sync.dart").read_text(
            encoding="utf-8"
        )
        for symbol in (
            "_expenseFromDoc", "_perDiemFromDoc", "_financeFromDoc",
            "_settlementFromDoc", "Cheltuieli: $e", "Diurne: $e",
            "Financiar: $e", "Deplasări: $e",
            "expenses.clear(); perDiems.clear(); finances.clear(); settlements.clear();",
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, source)


if __name__ == "__main__":
    unittest.main()
