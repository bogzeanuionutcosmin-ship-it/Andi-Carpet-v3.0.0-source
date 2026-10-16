"""Standalone review acceptance model: auth_revocation; not production implementation."""
import unittest

def may_continue(captured_epoch, authoritative_epoch, uid_matches, team_matches):
    return (type(captured_epoch) is int and type(authoritative_epoch) is int
            and captured_epoch > 0 and captured_epoch == authoritative_epoch
            and uid_matches is True and team_matches is True)

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertTrue(may_continue(3,3,True,True))
        self.assertFalse(may_continue(3,4,True,True))
        self.assertFalse(may_continue(3,3,True,False))
        self.assertFalse(may_continue(True,1,True,True))

if __name__ == "__main__":
    unittest.main()
