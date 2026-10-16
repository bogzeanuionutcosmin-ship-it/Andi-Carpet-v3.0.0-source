"""Offline Shiva acceptance test for lease_expiry; not a runtime proof."""
import unittest

def valid(now,expires,epoch,current):
    return (type(now) is int and type(expires) is int and now < expires
            and type(epoch) is int and epoch > 0 and epoch == current)

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertTrue(valid(99,100,2,2))
        self.assertFalse(valid(100,100,2,2))
        self.assertFalse(valid(99,100,2,3))
        self.assertFalse(valid(True,100,2,2))

if __name__ == "__main__":
    unittest.main()
