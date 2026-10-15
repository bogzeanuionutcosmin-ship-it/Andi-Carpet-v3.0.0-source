"""VII-04: only tag the two pre-write denials; preserve every server operation."""
from pathlib import Path
import hashlib
import unittest
ROOT = Path(__file__).resolve().parents[1]
class FinanceRejectionAdapterBoundary(unittest.TestCase):
    def test_only_prewrite_denial_types_changed(self):
        source = (ROOT / 'lib/home/home_financial_write_actions.dart').read_text()
        self.assertEqual(source.count('throw FinanceSaveRejected('), 2)
        reconstructed = source.replace('throw FinanceSaveRejected(', 'throw StateError(')
        self.assertEqual(hashlib.sha256(reconstructed.encode()).hexdigest(), '7de96936fd2493ed210d392cc6554f768a3a3dc25fafca2169e9ab126e807f76')
        for method, collection in [('_saveSettlementDirect', 'settlements'), ('_saveFinanceDirect', 'finance')]:
            body = source.split('  Future<void> ' + method, 1)[1].split('\n  Future<void>', 1)[0]
            self.assertLess(body.index('throw FinanceSaveRejected('), body.index("collection('" + collection + "')"))
