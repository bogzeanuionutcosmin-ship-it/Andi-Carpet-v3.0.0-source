import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ExpenseDuplicateDecisionSourceContract(unittest.TestCase):
    def test_expense_page_delegates_mode_decision_and_keeps_effects(self):
        page = (ROOT / "lib/expenses/expense_page.dart").read_text(encoding="utf-8")
        self.assertIn("decideExpenseDuplicate<Expense>(", page)
        self.assertIn("ExpenseDuplicateDecisionKind.block", page)
        self.assertIn("showDialog<bool>(context: context", page)
        self.assertIn("widget.log('Duplicat financiar blocat'", page)

    def test_decision_policy_is_registered_as_an_expenses_part(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        policy = (ROOT / "lib/expenses/expense_duplicate_decision.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(main.count("part 'expenses/expense_duplicate_decision.dart';"), 1)
        self.assertIn("enum ExpenseDuplicateDecisionKind", policy)
        self.assertIn("findDuplicate()", policy)


if __name__ == "__main__":
    unittest.main()
