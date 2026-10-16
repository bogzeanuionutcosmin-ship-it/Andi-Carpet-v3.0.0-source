"""Bounded diagnostics quota model; not a cloud billing guarantee."""
import unittest


class Budget:
    def __init__(self, daily_limit):
        self.daily_limit = daily_limit
        self.used = 0

    def reserve(self, units):
        if type(units) is not int or units <= 0:
            return False
        if type(self.daily_limit) is not int or self.daily_limit < 0:
            return False
        if self.used + units > self.daily_limit:
            return False
        self.used += units
        return True


class QuotaTest(unittest.TestCase):
    def test_exhaustion_blocks_new_reservations(self):
        b = Budget(3)
        self.assertTrue(b.reserve(2))
        self.assertFalse(b.reserve(2))
        self.assertTrue(b.reserve(1))
        self.assertFalse(b.reserve(1))
        self.assertEqual(b.used, 3)

    def test_invalid_units_never_consume_quota(self):
        b = Budget(5)
        for units in (0, -1, True, "1", None, 0.5):
            self.assertFalse(b.reserve(units))
        self.assertEqual(b.used, 0)

    def test_zero_budget_is_closed(self):
        self.assertFalse(Budget(0).reserve(1))


if __name__ == "__main__":
    unittest.main()
