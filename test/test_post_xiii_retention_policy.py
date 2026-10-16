"""Unresolved journal records are never silently evicted."""
import unittest


def choose_eviction(records, capacity):
    if type(capacity) is not int or capacity < 0:
        return "blocked"
    if not isinstance(records, list):
        return "blocked"
    if any(r not in ("confirmed", "uncertain", "prepared") for r in records):
        return "blocked"
    if len(records) <= capacity:
        return []
    return "manual_capacity_resolution"


class RetentionPolicyTest(unittest.TestCase):
    def test_over_capacity_does_not_delete_uncertain(self):
        self.assertEqual(choose_eviction(["uncertain"] * 33, 32),
                         "manual_capacity_resolution")

    def test_over_capacity_does_not_delete_prepared(self):
        self.assertEqual(choose_eviction(["prepared"] * 33, 32),
                         "manual_capacity_resolution")

    def test_within_capacity_preserves_everything(self):
        self.assertEqual(choose_eviction(["confirmed", "uncertain"], 32), [])

    def test_bad_limit_denied(self):
        self.assertEqual(choose_eviction(["uncertain"], True), "blocked")


if __name__ == "__main__":
    unittest.main()
