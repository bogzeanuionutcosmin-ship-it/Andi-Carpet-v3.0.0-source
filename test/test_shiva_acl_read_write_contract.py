"""Offline Shiva acceptance test for acl_read_write; not a runtime proof."""
import unittest

def allowed(grant,operation):
    return (type(grant) is dict and type(operation) is str and operation in ("read","write")
            and grant.get("approved") is True and grant.get(operation) is True)

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertTrue(allowed({"approved":True,"read":True,"write":False},"read"))
        self.assertFalse(allowed({"approved":True,"read":True,"write":False},"write"))
        self.assertFalse(allowed({"approved":False,"read":True},"read"))

if __name__ == "__main__":
    unittest.main()
