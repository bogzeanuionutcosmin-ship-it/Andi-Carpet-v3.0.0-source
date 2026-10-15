"""The session-only fix must not alter active-session uncertain save behavior."""
from pathlib import Path
import hashlib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StaleCloseBoundary(unittest.TestCase):
    def test_removing_only_the_new_guard_reconstructs_previous_runtime(self):
        source = (ROOT / 'lib/expenses/expense_settlement_actions.dart').read_text()
        guard = '        // Ignore every completion owned by an obsolete financial session.\n        if (!operationIsCurrent()) return;\n'
        self.assertEqual(source.count(guard), 1)
        previous = source.replace(guard, '', 1)
        self.assertEqual(hashlib.sha256(previous.encode()).hexdigest(),
                         'db37036095f0f8f54b3e820cb0eb9230a8f8243f12aaae55f4d87b2559cbf87d')
