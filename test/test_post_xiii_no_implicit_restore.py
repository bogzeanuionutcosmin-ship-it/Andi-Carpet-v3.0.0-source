"""Fail-closed restore model: never rehydrate a financial send permit."""
import unittest


def restore_intent(owner_matches, authenticated, current_epoch_matches,
                   state, marker_verified):
    if owner_matches is not True or authenticated is not True:
        return "quarantine"
    if current_epoch_matches is not True:
        return "authorization_required"
    if state == "uncertain":
        return "manual_reconciliation"
    if state == "confirmed" and marker_verified is True:
        return "read_only"
    return "quarantine"


class NoImplicitRestoreTest(unittest.TestCase):
    def test_uncertain_cannot_be_automatically_sent(self):
        self.assertEqual(restore_intent(True, True, True, "uncertain", True),
                         "manual_reconciliation")

    def test_old_epoch_requires_new_authorization(self):
        self.assertEqual(restore_intent(True, True, False, "uncertain", True),
                         "authorization_required")

    def test_unknown_state_is_quarantined(self):
        self.assertEqual(restore_intent(True, True, True, "prepared", False),
                         "quarantine")

    def test_confirmed_is_read_only(self):
        self.assertEqual(restore_intent(True, True, True, "confirmed", True),
                         "read_only")


if __name__ == "__main__":
    unittest.main()
