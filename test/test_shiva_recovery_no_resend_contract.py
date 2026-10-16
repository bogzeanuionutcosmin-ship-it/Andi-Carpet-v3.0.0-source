"""Standalone review acceptance model: recovery_no_resend; not production implementation."""
import unittest

def recovery_action(state, marker):
    if state not in ("uncertain","prepared","confirmed"): return "quarantine"
    if marker == "matching": return "read_only_confirmed"
    return "manual_reconciliation"

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertEqual(recovery_action("uncertain",None),"manual_reconciliation")
        self.assertEqual(recovery_action("prepared","missing"),"manual_reconciliation")
        self.assertEqual(recovery_action("confirmed","matching"),"read_only_confirmed")
        self.assertEqual(recovery_action("retry","matching"),"quarantine")

if __name__ == "__main__":
    unittest.main()
