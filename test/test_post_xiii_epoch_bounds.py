"""Review model of Firestore-safe monotonic epoch boundaries."""
import unittest

MAX_EPOCH = 9007199254740991


def next_epoch(current):
    if type(current) is not int or current < 0 or current >= MAX_EPOCH:
        return None
    return current + 1


class EpochBoundsTest(unittest.TestCase):
    def test_first_epoch(self):
        self.assertEqual(next_epoch(0), 1)

    def test_last_permitted_increment(self):
        self.assertEqual(next_epoch(MAX_EPOCH - 1), MAX_EPOCH)

    def test_saturation_denied(self):
        self.assertIsNone(next_epoch(MAX_EPOCH))

    def test_negative_float_bool_and_string_denied(self):
        for value in (-1, 1.0, True, "1", None):
            self.assertIsNone(next_epoch(value))


if __name__ == "__main__":
    unittest.main()
