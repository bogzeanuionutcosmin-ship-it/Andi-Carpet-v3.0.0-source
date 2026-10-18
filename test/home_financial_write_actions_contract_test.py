"""Structural guardrails for unchanged financial writes and receipt transactions."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class HomeFinancialWriteActionsContracts(unittest.TestCase):
    def test_all_four_writes_are_extracted_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/home/home_financial_write_actions.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'home/home_financial_write_actions.dart';"), 1)
        self.assertTrue(module.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeFinancialWriteActions on _HomePageState {", module)
        for name in ("_saveExpenseDirect","_savePerDiemDirect","_saveSettlementDirect","_saveFinanceDirect"):
            with self.subTest(name=name):
                self.assertEqual(module.count(f"  Future<void> {name}("), 1)
                self.assertNotIn(f"  Future<void> {name}(", home)

    def test_server_side_receipt_transaction_and_audit_are_preserved(self):
        module = (ROOT / "lib/home/home_financial_write_actions.dart").read_text(encoding="utf-8")
        for contract in (
            "FirebaseAuth.instance.currentUser?.uid != currentUserId",
            "db.runTransaction((tx) async {", "final snap = await tx.get(ref);",
            "tx.update(ref, changes);", "tx.set(auditRef, {",
            "parsePerDiemBani(", "actualReceivedAmount", "confirmedAt",
            "receiptAudit", "declaredAmountBani", "differenceBani",
            "Nu ai dreptul să modifici această diurnă.",
            "canEditTeam(", "hasPermission(FunctionPermission.viewOwnDecont)",
        ):
            with self.subTest(contract=contract): self.assertIn(contract,module)

    def test_write_targets_and_existing_side_effects_are_preserved(self):
        module = (ROOT / "lib/home/home_financial_write_actions.dart").read_text(encoding="utf-8")
        for contract in (
            "collection('expenses')", "collection('perDiems')",
            "collection('settlements')", "collection('finance')",
            "_expenseCache[expense.id] =", "_perDiemCache[entry.id] =",
            "_financeCache[finance.teamId] =", "_writeLearningEvent(",
        ):
            with self.subTest(contract=contract): self.assertIn(contract,module)
