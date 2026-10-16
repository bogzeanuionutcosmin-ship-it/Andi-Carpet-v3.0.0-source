"""Offline Shiva acceptance test for journal_transition; not a runtime proof."""
import unittest

TRANSITIONS={"prepared":{"uncertain","rejected_before_write"},"uncertain":{"confirmed","conflict"},"confirmed":set(),"conflict":set(),"rejected_before_write":set()}
def transition(old,new):
    return new in TRANSITIONS.get(old,set())

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertTrue(transition("prepared","uncertain"))
        self.assertTrue(transition("uncertain","confirmed"))
        self.assertFalse(transition("uncertain","prepared"))
        self.assertFalse(transition("confirmed","prepared"))

if __name__ == "__main__":
    unittest.main()
