"""Offline Shiva acceptance test for idempotency_scope; not a runtime proof."""
import unittest

def key(uid,team,operation):
    if not all(type(x) is str and x for x in (uid,team,operation)): return None
    return (uid,team,operation)

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertNotEqual(key("A","T","op"),key("B","T","op"))
        self.assertNotEqual(key("A","T","op"),key("A","U","op"))
        self.assertEqual(key("A","T","op"),key("A","T","op"))
        self.assertIsNone(key("A","","op"))

if __name__ == "__main__":
    unittest.main()
