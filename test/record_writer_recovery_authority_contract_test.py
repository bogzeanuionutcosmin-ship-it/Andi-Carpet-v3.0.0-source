"""All recovery observations must pass authority checks before classification."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class RecoveryAuthorityContractTest(unittest.TestCase):
    def test_recovery_checks_metadata_before_using_payload(self):
        source = (ROOT / 'lib/operations/record_writer.dart').read_text()
        recovery = source.split('final observed = await ref.get(', 1)[1]
        guard = recovery.index('observed.metadata.isFromCache || observed.metadata.hasPendingWrites')
        self.assertLess(guard, recovery.index('final current = observed.data();'))
        self.assertIn('Error.throwWithStackTrace(error, stackTrace);', recovery[:recovery.index('final current = observed.data();')])


if __name__ == '__main__':
    unittest.main()
