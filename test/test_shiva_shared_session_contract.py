"""Independent executable cross-tab/session-fence contract MODEL.

No Firebase, native locks, browser engine, SDK or protected runtime is exercised.
The unsafe local-only path is intentionally demonstrated as a counterexample.
"""
import unittest
from dataclasses import dataclass


@dataclass(frozen=True)
class Lease:
    uid: str
    team: str
    epoch: int


class EpochStore:
    def __init__(self):
        self.current = Lease("A", "team-1", 1)

    def revoke(self, uid, team):
        self.current = Lease(uid, team, self.current.epoch + 1)

    def owns(self, lease):
        return lease == self.current


class FakeServer:
    def __init__(self, epochs):
        self.epochs = epochs
        self.markers = {}
        self.sends = 0

    def submit(self, lease, operation_id, *, enforce_epoch):
        self.sends += 1
        if enforce_epoch and not self.epochs.owns(lease):
            return "rejected_before_write"
        key = (lease.uid, lease.team, operation_id)
        if key in self.markers:
            return "confirmed_replay"
        self.markers[key] = "committed"
        return "confirmed"


class FakeClient:
    def __init__(self, lease, epochs, server):
        self.lease, self.epochs, self.server = lease, epochs, server
        self.local_intents = {}

    def prepare(self, operation_id):
        if not self.epochs.owns(self.lease):
            return "rejected_before_write"
        self.local_intents[operation_id] = "pending"
        return "prepared"

    def send_after_await(self, operation_id, *, enforce_server_epoch):
        # An async suspension may happen after a successful local check.
        if operation_id not in self.local_intents:
            return "rejected_before_write"
        outcome = self.server.submit(
            self.lease, operation_id, enforce_epoch=enforce_server_epoch)
        self.local_intents[operation_id] = (
            "uncertain" if outcome == "confirmed" else outcome)
        return outcome

    def reconcile(self, operation_id):
        key = (self.lease.uid, self.lease.team, operation_id)
        if key in self.server.markers:
            self.local_intents[operation_id] = "confirmed"
            return "confirmed"
        return "uncertain"


class SharedSessionContractTest(unittest.TestCase):
    def setUp(self):
        self.epochs = EpochStore()
        self.server = FakeServer(self.epochs)
        self.a = FakeClient(self.epochs.current, self.epochs, self.server)

    def test_local_lease_check_is_not_a_remote_server_fence(self):
        self.assertEqual(self.a.prepare("op-1"), "prepared")
        self.epochs.revoke("B", "team-2")
        self.assertEqual(
            self.a.send_after_await("op-1", enforce_server_epoch=False),
            "confirmed")
        self.assertEqual(len(self.server.markers), 1)

    def test_server_fence_denies_stale_epoch_after_await(self):
        self.assertEqual(self.a.prepare("op-1"), "prepared")
        self.epochs.revoke("B", "team-2")
        self.assertEqual(
            self.a.send_after_await("op-1", enforce_server_epoch=True),
            "rejected_before_write")
        self.assertFalse(self.server.markers)

    def test_a1_b_a2_does_not_reauthorize_a1(self):
        self.assertEqual(self.a.prepare("op-1"), "prepared")
        self.epochs.revoke("B", "team-2")
        self.epochs.revoke("A", "team-1")
        a2 = FakeClient(self.epochs.current, self.epochs, self.server)
        self.assertNotEqual(a2.lease.epoch, self.a.lease.epoch)
        self.assertEqual(
            self.a.send_after_await("op-1", enforce_server_epoch=True),
            "rejected_before_write")
        self.assertEqual(a2.prepare("op-2"), "prepared")
        self.assertEqual(
            a2.send_after_await("op-2", enforce_server_epoch=True),
            "confirmed")

    def test_ack_lost_retains_uncertain_and_reconciles_without_resend(self):
        self.assertEqual(self.a.prepare("op-1"), "prepared")
        self.assertEqual(
            self.a.send_after_await("op-1", enforce_server_epoch=True),
            "confirmed")
        self.assertEqual(self.a.local_intents["op-1"], "uncertain")
        before = self.server.sends
        self.epochs.revoke("B", "team-2")
        self.assertEqual(self.a.reconcile("op-1"), "confirmed")
        self.assertEqual(self.server.sends, before)

    def test_team_transfer_never_adopts_old_intent(self):
        self.assertEqual(self.a.prepare("op-1"), "prepared")
        self.epochs.revoke("A", "team-2")
        new = FakeClient(self.epochs.current, self.epochs, self.server)
        self.assertNotIn("op-1", new.local_intents)
        self.assertEqual(
            self.a.send_after_await("op-1", enforce_server_epoch=True),
            "rejected_before_write")
        self.assertFalse(self.server.markers)

    def test_new_intent_after_revocation_denied_before_send(self):
        self.epochs.revoke("B", "team-2")
        self.assertEqual(self.a.prepare("op-1"), "rejected_before_write")
        self.assertEqual(self.server.sends, 0)


if __name__ == "__main__":
    unittest.main()
