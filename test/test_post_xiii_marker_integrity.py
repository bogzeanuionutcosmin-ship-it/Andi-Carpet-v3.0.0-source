"""Read-only marker evidence must match all immutable intent fields."""
import unittest


def confirm(intent, marker, current_read_allowed):
    if current_read_allowed is not True:
        return "authorization_required"
    required = ("uid", "team", "operation", "digest", "frozen_epoch")
    if not isinstance(intent, dict) or not isinstance(marker, dict):
        return "uncertain"
    if any(k not in intent or k not in marker for k in required):
        return "uncertain"
    if any(intent[k] != marker[k] for k in required):
        return "conflict"
    return "confirmed"


class MarkerIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.intent = dict(uid="A", team="T1", operation="op1",
                           digest="sha", frozen_epoch=1)

    def test_exact_marker_confirmed(self):
        self.assertEqual(confirm(self.intent, self.intent.copy(), True), "confirmed")

    def test_every_identity_field_matters(self):
        for field in self.intent:
            changed = self.intent.copy()
            changed[field] = "different"
            self.assertEqual(confirm(self.intent, changed, True), "conflict")

    def test_revoked_reader_cannot_confirm(self):
        self.assertEqual(confirm(self.intent, self.intent.copy(), False),
                         "authorization_required")

    def test_missing_marker_remains_uncertain(self):
        self.assertEqual(confirm(self.intent, None, True), "uncertain")


if __name__ == "__main__":
    unittest.main()
