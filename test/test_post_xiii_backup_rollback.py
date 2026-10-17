"""Review model for detecting replayed backups using independent monotonic state.

A local digest cannot authenticate freshness. This does not implement key custody.
"""
import unittest


def restore_decision(backup_revision, trusted_high_water, authenticated,
                     same_owner, unresolved):
    if type(backup_revision) is not int or backup_revision < 0:
        return "quarantine"
    if type(trusted_high_water) is not int or trusted_high_water < 0:
        return "quarantine"
    if authenticated is not True or same_owner is not True:
        return "quarantine"
    if backup_revision < trusted_high_water:
        return "rollback_detected"
    if backup_revision > trusted_high_water:
        return "quarantine"
    if unresolved is not False:
        return "manual_reconciliation"
    return "read_only_candidate"


class BackupRollbackThreatTest(unittest.TestCase):
    def test_old_valid_checksum_cannot_prove_freshness(self):
        self.assertEqual(restore_decision(5, 6, True, True, False),
                         "rollback_detected")

    def test_missing_external_high_water_fails_closed(self):
        self.assertEqual(restore_decision(5, None, True, True, False),
                         "quarantine")

    def test_unresolved_work_cannot_be_replayed(self):
        self.assertEqual(restore_decision(5, 5, True, True, True),
                         "manual_reconciliation")

    def test_foreign_owner_is_quarantined(self):
        self.assertEqual(restore_decision(5, 5, True, False, False),
                         "quarantine")

    def test_future_revision_is_not_implicitly_trusted(self):
        self.assertEqual(restore_decision(6, 5, True, True, False),
                         "quarantine")


if __name__ == "__main__":
    unittest.main()
