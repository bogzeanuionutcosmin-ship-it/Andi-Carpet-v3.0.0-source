"""Bounded history model; no actual Firestore query is executed."""
import unittest


def history_window(limit, cursor, records):
    if type(limit) is not int or not 1 <= limit <= 100:
        return "blocked"
    if cursor is not None and (type(cursor) is not int or cursor < 0):
        return "blocked"
    offset = cursor or 0
    return records[offset:offset + limit]


class HistoryBoundsTest(unittest.TestCase):
    def test_bounded_pages(self):
        data = list(range(250))
        self.assertEqual(history_window(100, 0, data), list(range(100)))
        self.assertEqual(history_window(100, 100, data), list(range(100, 200)))
        self.assertEqual(history_window(100, 200, data), list(range(200, 250)))

    def test_invalid_limits_fail_closed(self):
        for limit in (0, -1, 101, True, "100", None):
            self.assertEqual(history_window(limit, None, []), "blocked")

    def test_invalid_cursor_fails_closed(self):
        for cursor in (-1, True, "0", 0.5):
            self.assertEqual(history_window(10, cursor, []), "blocked")


if __name__ == "__main__":
    unittest.main()
