"""Standalone review acceptance model: per_diem_due; not production implementation."""
import unittest
from datetime import timezone
from datetime import datetime
def due(when, accrued_minor):
    if not isinstance(when, datetime) or when.tzinfo is None or type(accrued_minor) is not int: return False
    return (when.hour,when.minute) >= (9,31) and accrued_minor > 0

class ContractTest(unittest.TestCase):
    def test_acceptance_cases(self):
        self.assertFalse(due(datetime(2026,10,17,9,30,tzinfo=timezone.utc),100))
        self.assertTrue(due(datetime(2026,10,17,9,31,tzinfo=timezone.utc),100))
        self.assertFalse(due(datetime(2026,10,17,9,31,tzinfo=timezone.utc),0))

if __name__ == "__main__":
    unittest.main()
