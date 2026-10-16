"""Standalone review acceptance model: single_team; not production implementation."""
import unittest

def team_assignment_allowed(existing_team, requested_team):
    return (type(requested_team) is str and bool(requested_team)
            and (existing_team is None or existing_team == requested_team))

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertTrue(team_assignment_allowed(None,"T1"))
        self.assertTrue(team_assignment_allowed("T1","T1"))
        self.assertFalse(team_assignment_allowed("T1","T2"))
        self.assertFalse(team_assignment_allowed(None,""))

if __name__ == "__main__":
    unittest.main()
