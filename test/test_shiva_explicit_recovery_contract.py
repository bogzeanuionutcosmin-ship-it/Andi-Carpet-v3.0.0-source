"""Offline explicit recovery authorization model.

A new session must not silently inherit a pending operation from an old epoch.
The server marker is queried under a separately granted recovery capability.
No network, real financial payload, or protected runtime.
"""
import unittest
from dataclasses import dataclass


@dataclass(frozen=True)
class RecoveryGrant:
    uid: str
    team: str
    operation: str
    issued_epoch: int
    valid: bool


def reconcile_old_intent(grant, current_uid, current_team, current_epoch,
                         original_uid, original_team, operation, local_digest,
                         marker):
    if not grant.valid or grant.issued_epoch != current_epoch:
        return "authorization_required"
    if (grant.uid, grant.team, grant.operation) != (
            original_uid, original_team, operation):
        return "authorization_required"
    if (current_uid, current_team) != (grant.uid, grant.team):
        return "authorization_required"
    if not isinstance(local_digest, str) or not local_digest:
        return "uncertain"
    if marker is None or marker != local_digest:
        return "uncertain"
    return "confirmed"


class ExplicitRecoveryTest(unittest.TestCase):
    def setUp(self):
        self.grant = RecoveryGrant("A", "T1", "op1", 3, True)
        self.args = ("A", "T1", 3, "A", "T1", "op1", "digest1", "digest1")

    def check(self, grant=None, args=None):
        return reconcile_old_intent(grant or self.grant, *(args or self.args))

    def test_authorized_new_epoch_can_read_matching_old_marker(self):
        self.assertEqual(self.check(), "confirmed")

    def test_cross_user_cannot_inherit_pending_intent(self):
        args = ("B", "T1", 3, "A", "T1", "op1", "digest1", "digest1")
        self.assertEqual(self.check(args=args), "authorization_required")

    def test_cross_team_cannot_inherit_pending_intent(self):
        args = ("A", "T2", 3, "A", "T1", "op1", "digest1", "digest1")
        self.assertEqual(self.check(args=args), "authorization_required")

    def test_stale_recovery_grant_denied(self):
        args = ("A", "T1", 4, "A", "T1", "op1", "digest1", "digest1")
        self.assertEqual(self.check(args=args), "authorization_required")

    def test_revoked_grant_denied(self):
        grant = RecoveryGrant("A", "T1", "op1", 3, False)
        self.assertEqual(self.check(grant=grant), "authorization_required")

    def test_wrong_operation_grant_denied(self):
        grant = RecoveryGrant("A", "T1", "op2", 3, True)
        self.assertEqual(self.check(grant=grant), "authorization_required")

    def test_missing_server_marker_never_becomes_failed_write(self):
        args = ("A", "T1", 3, "A", "T1", "op1", "digest1", None)
        self.assertEqual(self.check(args=args), "uncertain")

    def test_mismatched_marker_remains_uncertain(self):
        args = ("A", "T1", 3, "A", "T1", "op1", "digest1", "digest2")
        self.assertEqual(self.check(args=args), "uncertain")

    def test_missing_digest_remains_uncertain(self):
        args = ("A", "T1", 3, "A", "T1", "op1", "", "digest1")
        self.assertEqual(self.check(args=args), "uncertain")


if __name__ == "__main__":
    unittest.main()
