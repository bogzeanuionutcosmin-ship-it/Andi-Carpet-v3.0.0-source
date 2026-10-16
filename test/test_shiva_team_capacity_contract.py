"""Standalone review acceptance model: team_capacity; not production implementation."""
import unittest

def can_join(members, uid):
    if not isinstance(members, (tuple,list)) or type(uid) is not str or not uid: return False
    if len(set(members)) != len(members) or any(type(x) is not str or not x for x in members): return False
    return uid in members or len(members) < 2

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertTrue(can_join(["A"],"B"))
        self.assertFalse(can_join(["A","B"],"C"))
        self.assertTrue(can_join(["A","B"],"A"))
        self.assertFalse(can_join(["A","A"],"C"))

if __name__ == "__main__":
    unittest.main()
