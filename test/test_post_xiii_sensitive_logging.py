"""Minimal review model for avoiding sensitive diagnostics."""
import unittest


ALLOWED = frozenset(("status", "gate", "platform"))
STATUSES = frozenset(("blocked", "unknown", "fail", "pass"))


def sanitize(event):
    if type(event) is not dict or not set(event).issubset(ALLOWED):
        return None
    if "status" not in event or event["status"] not in STATUSES:
        return None
    if not all(type(value) is str for value in event.values()):
        return None
    return dict(event)


class SensitiveLoggingTest(unittest.TestCase):
    def test_safe_event(self):
        self.assertEqual(sanitize({"status": "blocked", "gate": "hardware"}),
                         {"status": "blocked", "gate": "hardware"})

    def test_identifiers_and_money_denied(self):
        for field in ("uid", "team", "operationId", "amount", "token"):
            self.assertIsNone(sanitize({"status": "pass", field: "secret"}))

    def test_unknown_status_denied(self):
        self.assertIsNone(sanitize({"status": "deployed"}))


if __name__ == "__main__":
    unittest.main()
