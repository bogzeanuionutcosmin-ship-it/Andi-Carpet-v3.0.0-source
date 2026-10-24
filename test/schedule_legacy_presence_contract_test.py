from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
class LegacyPresence(unittest.TestCase):
    def test_loaded_legacy_schedule_has_presence_independent_of_revision(self):
        codec = (ROOT/'lib/home/home_document_codecs.dart').read_text()
        self.assertIn('scheduleFromDocumentData(doc.id, doc.data())', codec)
        schedule_codec = (ROOT/'lib/schedule/schedule_document_codec.dart').read_text()
        self.assertIn('persisted: true', schedule_codec)
        # Dashboard's immutable copy now lives in its extracted transition module.
        expectations = {
            'lib/schedule/program_schedule_clone.dart': 'persisted:s.persisted',
            'lib/dashboard/dashboard_program_transition.dart': 'persisted:schedule.persisted',
        }
        for name, expression in expectations.items():
            source = (ROOT/name).read_text().replace(' ', '')
            self.assertIn(expression, source)
    def test_transaction_checks_presence_before_writing(self):
        home = (ROOT/'lib/home/home_page.dart').read_text()
        writer = home[home.index('Future<void> _saveSchedulesDirect'):home.index('Future<void> _saveRecordDirect')]
        self.assertLess(writer.index('schedule.persisted != snapshot.exists'), writer.index('transaction.set('))
        self.assertLess(writer.index('await db.runTransaction'), writer.index('schedule.persisted = true'))
