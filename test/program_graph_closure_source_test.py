"""Guard against Learning bypassing the approved explicit STOP confirmation."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OfficialStopSourceTest(unittest.TestCase):
    def test_learning_only_reminds_and_does_not_close_or_save(self):
        source = (ROOT / 'lib/home/home_page.dart').read_text()
        body = source.split('Future<void> _maybeAutoCloseResolvedSchedules', 1)[1].split('final _coreSubscriptions', 1)[0]
        self.assertIn('programGraphsReadyForOfficialStop(', body)
        self.assertIn('_automationNotifyOnce(', body)
        self.assertNotIn('_saveScheduleDirect(', body)
        self.assertNotIn('.closed =', body)
        self.assertNotIn('.active =', body)
