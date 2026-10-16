"""Financial HomePage listener extraction: structural regression checks only."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HomeFinancialSyncContracts(unittest.TestCase):
    def test_single_financial_method_and_original_calls(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        finance = (ROOT / "lib/home/home_financial_sync.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'home/home_financial_sync.dart';"), 1)
        self.assertTrue(finance.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeFinancialSync on _HomePageState {", finance)
        self.assertEqual(finance.count("  void _startFinancialSync() {"), 1)
        self.assertNotIn("  void _startFinancialSync() {", home)
        self.assertIn("    _startFinancialSync();", home)
        self.assertIn("    for (final sub in _financialSubscriptions) { sub.cancel(); }", home)

    def test_four_scoped_listeners_and_reset_remain_unmodified(self):
        finance = (ROOT / "lib/home/home_financial_sync.dart").read_text(encoding="utf-8")
        self.assertEqual(finance.count("_financialSubscriptions.add("), 4)
        self.assertEqual(finance.count(".snapshots().listen("), 4)
        for fragment in (
            "final canViewAll = isAdmin || hasPermission(FunctionPermission.viewOtherDecont);",
            "final scope = canViewAll ? '*' : me.teamId;",
            "if (_financialTeamScope == scope) return;",
            "for (final sub in _financialSubscriptions) { sub.cancel(); }",
            "_financialSubscriptions.clear();",
            "expenses.clear(); perDiems.clear(); finances.clear(); settlements.clear();",
            "if (scope == null || scope.isEmpty)",
            "db.collection('expenses').where('teamId',isEqualTo:scope)",
            "db.collection('perDiems').where('teamId',isEqualTo:scope)",
            "db.collection('finance').where('teamId',isEqualTo:scope)",
            "db.collection('settlements').where('teamId',isEqualTo:scope)",
            "expensesQuery.snapshots().listen(", "perDiemQuery.snapshots().listen(",
            "financeQuery.snapshots().listen(", "settlementQuery.snapshots().listen(",
            "coreSyncError='Cheltuieli: $e'", "coreSyncError='Diurne: $e'",
            "coreSyncError='Financiar: $e'", "coreSyncError='Deplasări: $e'",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, finance)

    def test_listener_count_not_confused_with_core_subscriptions(self):
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        first = (ROOT / "lib/home/home_sync_listeners.dart").read_text(encoding="utf-8")
        second = (ROOT / "lib/home/home_directory_definitions_audit_sync.dart").read_text(encoding="utf-8")
        finance = (ROOT / "lib/home/home_financial_sync.dart").read_text(encoding="utf-8")
        self.assertEqual(first.count("_coreSubscriptions.add("), 10)
        self.assertEqual(second.count("_coreSubscriptions.add("), 5)
        self.assertEqual(finance.count("_coreSubscriptions.add("), 0)
        self.assertEqual(finance.count("_financialSubscriptions.add("), 4)
        self.assertIn("final List<StreamSubscription<dynamic>> _financialSubscriptions = [];", home)

    def test_financial_converter_and_query_order_coverage_from_alternate_pr(self):
        finance = (ROOT / "lib/home/home_financial_sync.dart").read_text(encoding="utf-8")
        collections = ("expenses", "perDiems", "finance", "settlements")
        indices = []
        for name in collections:
            with self.subTest(collection=name):
                needle = "db.collection('" + name + "')"
                self.assertEqual(finance.count(needle), 2)
                indices.append(finance.index(needle))
        self.assertEqual(indices, sorted(indices))
        for converter in ("_expenseFromDoc", "_perDiemFromDoc",
                          "_financeFromDoc", "_settlementFromDoc"):
            with self.subTest(converter=converter):
                self.assertIn(converter, finance)
