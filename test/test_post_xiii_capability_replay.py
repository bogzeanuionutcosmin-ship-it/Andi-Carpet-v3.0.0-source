"""Threat-model tests for non-adoptable session capabilities.

This is NOT a deployed issuer or Firestore rules test.
"""
from dataclasses import dataclass
import unittest


@dataclass(frozen=True)
class Capability:
    uid: str
    team: str
    epoch: int
    login_nonce: str
    issued_to: str


def authorize(capability, *, uid, team, epoch, nonce, device):
    return (capability.uid == uid and capability.team == team
            and type(epoch) is int and epoch > 0 and capability.epoch == epoch
            and capability.login_nonce == nonce and capability.issued_to == device
            and bool(nonce) and bool(device))


class CapabilityReplayThreatTest(unittest.TestCase):
    def setUp(self):
        self.a1 = Capability("A", "T1", 1, "login-1", "device-1")

    def test_old_refresh_session_cannot_adopt_new_epoch(self):
        self.assertFalse(authorize(self.a1, uid="A", team="T1", epoch=2,
                                   nonce="login-1", device="device-1"))

    def test_same_epoch_different_login_denied(self):
        self.assertFalse(authorize(self.a1, uid="A", team="T1", epoch=1,
                                   nonce="login-2", device="device-1"))

    def test_cross_device_copy_denied(self):
        self.assertFalse(authorize(self.a1, uid="A", team="T1", epoch=1,
                                   nonce="login-1", device="device-2"))

    def test_cross_team_transfer_denied(self):
        self.assertFalse(authorize(self.a1, uid="A", team="T2", epoch=1,
                                   nonce="login-1", device="device-1"))

    def test_original_binding_is_authorized_before_revocation(self):
        self.assertTrue(authorize(self.a1, uid="A", team="T1", epoch=1,
                                  nonce="login-1", device="device-1"))


if __name__ == "__main__":
    unittest.main()
