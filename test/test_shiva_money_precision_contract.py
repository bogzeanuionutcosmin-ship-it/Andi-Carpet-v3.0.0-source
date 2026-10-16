"""Review-only finance precision contract: decimal text, never binary floats."""
from decimal import Decimal, InvalidOperation
import unittest


def minor_units(value):
    if type(value) is not str or not value or value.strip() != value:
        return None
    try:
        amount = Decimal(value)
    except InvalidOperation:
        return None
    if not amount.is_finite() or amount.as_tuple().exponent < -2:
        return None
    scaled = amount * 100
    if scaled != scaled.to_integral_value():
        return None
    return int(scaled)


class MoneyPrecisionContractTest(unittest.TestCase):
    def test_three_tenths_are_exact(self):
        self.assertEqual(sum(minor_units(x) for x in ("0.10", "0.20", "0.30")), 60)

    def test_no_implicit_float_input(self):
        for value in (0.1, 1, True, None, ["1.00"]):
            with self.subTest(value=value):
                self.assertIsNone(minor_units(value))

    def test_fractional_minor_unit_fails_closed(self):
        for value in ("0.001", "1.999", "1e-3", "NaN", "Infinity", " 1.00"):
            with self.subTest(value=value):
                self.assertIsNone(minor_units(value))

    def test_exact_large_integer_minor_units(self):
        self.assertEqual(minor_units("9007199254740993.01"), 900719925474099301)

    def test_negative_and_zero_preserve_sign(self):
        self.assertEqual(minor_units("-0.01"), -1)
        self.assertEqual(minor_units("0.00"), 0)


if __name__ == "__main__":
    unittest.main()
