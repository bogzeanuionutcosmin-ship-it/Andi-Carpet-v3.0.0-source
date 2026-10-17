"""Offline request-cost model; not measured Firebase billing."""
import unittest


def budget_ok(reads, writes, max_reads, max_writes):
    values = (reads, writes, max_reads, max_writes)
    return (all(type(v) is int and v >= 0 for v in values)
            and reads <= max_reads and writes <= max_writes)


class CostBoundsTest(unittest.TestCase):
    def test_fenced_append_documented_nominal_bound(self):
        self.assertTrue(budget_ok(4, 3, 4, 3))

    def test_retry_cost_not_hidden(self):
        self.assertFalse(budget_ok(12, 9, 4, 3))

    def test_invalid_and_unbounded_values_denied(self):
        self.assertFalse(budget_ok(True, 3, 4, 3))
        self.assertFalse(budget_ok(-1, 3, 4, 3))


if __name__ == "__main__":
    unittest.main()
