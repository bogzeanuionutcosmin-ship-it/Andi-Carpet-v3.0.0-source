"""Isolated backup/restore acceptance model for uncertain financial intents.

Restored data never gains implicit authority to submit an old operation.
"""
import unittest


def restored_intent_policy(source_uid, source_team, target_uid, target_team,
                           journal_state, marker_proven):
    if (source_uid, source_team) != (target_uid, target_team):
        return "quarantine"
    if journal_state not in ("prepared", "uncertain", "confirmed"):
        return "quarantine"
    if journal_state == "confirmed" and marker_proven is True:
        return "read_only_confirmed"
    return "manual_reconciliation_required"


class RestoreContractTest(unittest.TestCase):
    def test_restored_uncertain_never_autosends(self):
        for marker in (True, False, None):
            self.assertEqual(restored_intent_policy(
                "A", "T1", "A", "T1", "uncertain", marker),
                "manual_reconciliation_required")

    def test_restored_prepared_is_not_safe_to_send(self):
        self.assertEqual(restored_intent_policy(
            "A", "T1", "A", "T1", "prepared", False),
            "manual_reconciliation_required")

    def test_foreign_uid_and_team_are_quarantined(self):
        for uid, team in (("B", "T1"), ("A", "T2"), ("B", "T2")):
            self.assertEqual(restored_intent_policy(
                "A", "T1", uid, team, "confirmed", True), "quarantine")

    def test_confirmed_requires_marker_evidence(self):
        self.assertEqual(restored_intent_policy(
            "A", "T1", "A", "T1", "confirmed", True),
            "read_only_confirmed")
        self.assertEqual(restored_intent_policy(
            "A", "T1", "A", "T1", "confirmed", False),
            "manual_reconciliation_required")

    def test_unknown_or_corrupt_state_is_quarantined(self):
        for state in ("", "sent", "failed", None):
            self.assertEqual(restored_intent_policy(
                "A", "T1", "A", "T1", state, True), "quarantine")


if __name__ == "__main__":
    unittest.main()
