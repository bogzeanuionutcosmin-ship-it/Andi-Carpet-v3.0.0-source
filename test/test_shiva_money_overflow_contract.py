"""Offline Shiva acceptance test for money_overflow; not a runtime proof."""
import unittest

MAX=2**63-1
def add_minor(a,b):
    if type(a) is not int or type(b) is not int: return None
    result=a+b
    return result if -MAX-1<=result<=MAX else None

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertEqual(add_minor(1,2),3)
        self.assertIsNone(add_minor(MAX,1))
        self.assertIsNone(add_minor(-MAX-1,-1))
        self.assertIsNone(add_minor(True,1))

if __name__ == "__main__":
    unittest.main()
