"""Offline Shiva acceptance test for revision_order; not a runtime proof."""
import unittest

def monotonic(revisions):
    return (type(revisions) is list and all(type(v) is int and v>=0 for v in revisions)
            and all(b>a for a,b in zip(revisions,revisions[1:])))

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertTrue(monotonic([0,1,3]))
        self.assertFalse(monotonic([1,1,2]))
        self.assertFalse(monotonic([2,1]))
        self.assertFalse(monotonic([True,2]))

if __name__ == "__main__":
    unittest.main()
