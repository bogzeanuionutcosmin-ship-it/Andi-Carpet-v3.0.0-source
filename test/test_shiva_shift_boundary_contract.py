"""Standalone review acceptance model: shift_boundary; not production implementation."""
import unittest
from datetime import timezone
from datetime import datetime, timedelta
def operational_day(when):
    if not isinstance(when, datetime) or when.tzinfo is None: return None
    return (when - timedelta(hours=9, minutes=30)).date()

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertEqual(operational_day(datetime(2026,10,17,9,29,tzinfo=timezone.utc)).isoformat(),"2026-10-16")
        self.assertEqual(operational_day(datetime(2026,10,17,9,30,tzinfo=timezone.utc)).isoformat(),"2026-10-17")
        self.assertIsNone(operational_day(datetime(2026,10,17,9,30)))

if __name__ == "__main__":
    unittest.main()
