"""Standalone review acceptance model: marker_conflict; not production implementation."""
import unittest

def marker_decision(stored_digest, proposed_digest):
    if not isinstance(proposed_digest,str) or not proposed_digest: return "blocked"
    if stored_digest is None: return "new"
    return "replay" if stored_digest == proposed_digest else "conflict"

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertEqual(marker_decision(None,"d1"),"new")
        self.assertEqual(marker_decision("d1","d1"),"replay")
        self.assertEqual(marker_decision("d1","d2"),"conflict")
        self.assertEqual(marker_decision(None,""),"blocked")

if __name__ == "__main__":
    unittest.main()
