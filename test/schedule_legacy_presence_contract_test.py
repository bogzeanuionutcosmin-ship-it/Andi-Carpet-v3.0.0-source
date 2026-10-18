from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
class LegacyPresence(unittest.TestCase):
    def test_loaded_legacy_schedule_has_presence_independent_of_revision(self):
        codec = (ROOT/'lib/home/home_document_codecs.dart').read_text()
        self.assertIn('persisted: true', codec)
        for name in ['lib/schedule/program_page.dart', 'lib/dashboard/dashboard_page.dart']:
            self.assertIn('persisted:s.persisted', (ROOT/name).read_text())
    def test_transaction_checks_presence_before_writing(self):
        home = (ROOT/'lib/home/home_page.dart').read_text()
        writer = home[home.index('Future<void> _saveSchedulesDirect'):home.index('Future<void> _saveRecordDirect')]
        self.assertLess(writer.index('schedule.persisted != snapshot.exists'), writer.index('transaction.set('))
        self.assertLess(writer.index('await db.runTransaction'), writer.index('schedule.persisted = true'))
