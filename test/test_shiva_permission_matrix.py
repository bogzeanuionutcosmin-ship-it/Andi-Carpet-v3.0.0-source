"""Isolated model for write authorization under granular permissions.

No server rules are modified. A role name alone is never write authorization.
"""
from dataclasses import dataclass
import itertools
import unittest


@dataclass(frozen=True)
class Permission:
    uid: str
    team: str
    epoch: int
    approved: bool
    finance_write: bool


def can_write(grant, uid, team, epoch):
    return (grant.uid == uid and grant.team == team
            and grant.epoch == epoch and grant.approved is True
            and grant.finance_write is True)


class PermissionMatrixTest(unittest.TestCase):
    def test_all_approval_and_write_permission_combinations(self):
        for approved, enabled in itertools.product((False, True), repeat=2):
            grant = Permission("A", "T1", 3, approved, enabled)
            self.assertEqual(can_write(grant, "A", "T1", 3),
                             approved and enabled)

    def test_cross_team_uid_or_epoch_rejected(self):
        grant = Permission("A", "T1", 3, True, True)
        for uid, team, epoch in (("B", "T1", 3), ("A", "T2", 3),
                                 ("A", "T1", 2), ("A", "T1", 4)):
            self.assertFalse(can_write(grant, uid, team, epoch))

    def test_truthy_non_boolean_permission_is_denied(self):
        for bad in (1, "true", ["finance_write"], None):
            self.assertFalse(can_write(Permission("A", "T1", 3, bad, True),
                                       "A", "T1", 3))
            self.assertFalse(can_write(Permission("A", "T1", 3, True, bad),
                                       "A", "T1", 3))

    def test_admin_label_is_not_a_permission(self):
        grant = Permission("admin-user", "T1", 3, True, False)
        self.assertFalse(can_write(grant, "admin-user", "T1", 3))


if __name__ == "__main__":
    unittest.main()
