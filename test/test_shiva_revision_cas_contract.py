"""Standalone review acceptance model: revision_cas; not production implementation."""
import unittest

def cas(current_revision, expected_revision):
    return (type(current_revision) is int and type(expected_revision) is int
            and current_revision >= 0 and current_revision == expected_revision)

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertTrue(cas(3,3))
        self.assertFalse(cas(4,3))
        self.assertFalse(cas(0,True))
        self.assertFalse(cas(-1,-1))

if __name__ == "__main__":
    unittest.main()
