"""Standalone review acceptance model: diagnostic_dedup; not production implementation."""
import unittest

def accept_signal(seen, session, signal):
    if type(session) is not str or not session or type(signal) is not str or not signal: return False
    key=(session,signal)
    if key in seen: return False
    seen.add(key)
    return True

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertTrue(accept_signal(set(),"S1","uncertain"))
        self.assertFalse(accept_signal({("S1","uncertain")},"S1","uncertain"))
        self.assertTrue(accept_signal({("S1","uncertain")},"S2","uncertain"))

if __name__ == "__main__":
    unittest.main()
