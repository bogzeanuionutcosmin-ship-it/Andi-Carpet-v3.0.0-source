"""Current signed reader authority required even for old immutable evidence."""
import unittest


def can_read(current_uid, current_team, signed_epoch, authority_epoch,
             authority_enabled, evidence_team):
    return (type(current_uid) is str and bool(current_uid)
            and type(current_team) is str and current_team == evidence_team
            and type(signed_epoch) is int and signed_epoch > 0
            and type(authority_epoch) is int and signed_epoch == authority_epoch
            and authority_enabled is True)


class AuthorityReadGateTest(unittest.TestCase):
    def test_current_session_can_review_historic_same_team(self):
        self.assertTrue(can_read("A", "T", 2, 2, True, "T"))

    def test_revoked_reader_cannot_read_historic_evidence(self):
        self.assertFalse(can_read("A", "T", 1, 2, True, "T"))

    def test_team_transfer_denies_old_team_evidence(self):
        self.assertFalse(can_read("A", "T2", 2, 2, True, "T1"))

    def test_disabled_authority_denies(self):
        self.assertFalse(can_read("A", "T", 2, 2, False, "T"))


if __name__ == "__main__":
    unittest.main()
