"""Offline Shiva acceptance test for vision_allowlist; not a runtime proof."""
import unittest

ALLOWED={"uncertain","revision_conflict","session_revoked"}
def diagnostic(value):
    return value if type(value) is str and value in ALLOWED else None

class ContractTest(unittest.TestCase):
    def test_contract(self):
        self.assertEqual(diagnostic("uncertain"),"uncertain")
        self.assertIsNone(diagnostic("uid:A"))
        self.assertIsNone(diagnostic({"event":"uncertain"}))

if __name__ == "__main__":
    unittest.main()
