"""Property-oriented review model: uncertain operations never imply safe retry.

All values are synthetic; this does not connect to Firebase or native storage.
"""
import itertools
import unittest


def decision(local, marker, authorized):
    if not authorized:
        return "authorization_required"
    if local not in ("prepared", "sent_uncertain", "confirmed"):
        return "blocked"
    if marker == "matching":
        return "confirmed"
    if marker in ("missing", "mismatched", "unavailable"):
        return "uncertain"
    return "blocked"


class NoResendMatrixTest(unittest.TestCase):
    def test_every_unknown_server_outcome_is_uncertain_not_retry(self):
        for local, marker in itertools.product(
                ("prepared", "sent_uncertain", "confirmed"),
                ("missing", "mismatched", "unavailable")):
            with self.subTest(local=local, marker=marker):
                self.assertEqual(decision(local, marker, True), "uncertain")

    def test_every_revoked_state_denies_reconciliation(self):
        for local, marker in itertools.product(
                ("prepared", "sent_uncertain", "confirmed"),
                ("matching", "missing", "mismatched", "unavailable")):
            with self.subTest(local=local, marker=marker):
                self.assertEqual(decision(local, marker, False),
                                 "authorization_required")

    def test_matching_marker_is_only_positive_evidence(self):
        for local in ("prepared", "sent_uncertain", "confirmed"):
            self.assertEqual(decision(local, "matching", True), "confirmed")

    def test_unknown_local_state_fails_closed(self):
        for local in ("", "sent", "retry", None, "failed"):
            self.assertEqual(decision(local, "matching", True), "blocked")


if __name__ == "__main__":
    unittest.main()
