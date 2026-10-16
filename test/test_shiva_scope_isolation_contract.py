"""Isolated authority and journal namespace contract; no SDK or live backend."""
import itertools
import unittest
from dataclasses import dataclass


@dataclass(frozen=True)
class Scope:
    protocol: int
    uid: str
    team: str
    epoch: int


class ModelJournal:
    def __init__(self):
        self.records = {}

    def append(self, scope, operation, payload):
        if scope.protocol != 2 or not scope.uid or not scope.team or scope.epoch < 1:
            return "blocked"
        namespace = (scope.protocol, scope.uid, scope.team, scope.epoch)
        key = (namespace, operation)
        if key in self.records:
            return "already_present" if self.records[key] == payload else "conflict"
        self.records[key] = payload
        return "stored"

    def read(self, requester, owner, operation):
        if requester != owner:
            return "authorization_required"
        return self.records.get(((owner.protocol, owner.uid, owner.team, owner.epoch), operation))

    def reconcile(self, requester, owner, operation, server_markers):
        if requester != owner:
            return "authorization_required"
        local = self.read(requester, owner, operation)
        if local is None:
            return "unknown"
        marker = (owner.uid, owner.team, operation)
        return "confirmed" if server_markers.get(marker) == local else "uncertain"


class ScopeIsolationTest(unittest.TestCase):
    def setUp(self):
        self.journal = ModelJournal()
        self.owner = Scope(2, "A", "T1", 1)

    def test_exhaustive_cross_scope_reads_denied(self):
        self.assertEqual(self.journal.append(self.owner, "op1", "digest1"), "stored")
        choices = [
            Scope(1, "A", "T1", 1), Scope(2, "B", "T1", 1),
            Scope(2, "A", "T2", 1), Scope(2, "A", "T1", 2),
            Scope(2, "B", "T2", 2),
        ]
        for outsider in choices:
            with self.subTest(outsider=outsider):
                self.assertEqual(self.journal.read(outsider, self.owner, "op1"),
                                 "authorization_required")

    def test_same_operation_id_different_uid_team_and_epoch_isolated(self):
        scopes = [Scope(2, u, t, e)
                  for u, t, e in itertools.product(("A", "B"), ("T1", "T2"), (1, 2))]
        for index, scope in enumerate(scopes):
            self.assertEqual(self.journal.append(scope, "shared-op", str(index)), "stored")
        self.assertEqual(len(self.journal.records), 8)
        for index, scope in enumerate(scopes):
            self.assertEqual(self.journal.read(scope, scope, "shared-op"), str(index))

    def test_same_scope_same_id_different_payload_conflicts(self):
        self.assertEqual(self.journal.append(self.owner, "op1", "digest1"), "stored")
        self.assertEqual(self.journal.append(self.owner, "op1", "digest1"), "already_present")
        self.assertEqual(self.journal.append(self.owner, "op1", "digest2"), "conflict")
        self.assertEqual(self.journal.read(self.owner, self.owner, "op1"), "digest1")

    def test_unknown_or_legacy_protocol_denied(self):
        for protocol in (0, 1, 3, -1):
            self.assertEqual(self.journal.append(Scope(protocol, "A", "T1", 1), "x", "d"),
                             "blocked")
        self.assertFalse(self.journal.records)

    def test_marker_read_requires_scope_and_payload_match(self):
        self.journal.append(self.owner, "op1", "digest1")
        marker = {("A", "T1", "op1"): "digest1"}
        self.assertEqual(self.journal.reconcile(self.owner, self.owner, "op1", marker),
                         "confirmed")
        self.assertEqual(self.journal.reconcile(Scope(2, "B", "T1", 1),
                                                 self.owner, "op1", marker),
                         "authorization_required")
        marker[("A", "T1", "op1")] = "different-digest"
        self.assertEqual(self.journal.reconcile(self.owner, self.owner, "op1", marker),
                         "uncertain")

    def test_missing_marker_is_not_proof_of_failed_write(self):
        self.journal.append(self.owner, "op1", "digest1")
        self.assertEqual(self.journal.reconcile(self.owner, self.owner, "op1", {}),
                         "uncertain")


if __name__ == "__main__":
    unittest.main()
