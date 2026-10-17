from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROGRAM = (ROOT / "lib/schedule/program_page.dart").read_text()
HOME = (ROOT / "lib/home/home_page.dart").read_text()


class ScheduleTransactionalWriterContract(unittest.TestCase):
    def test_program_editor_has_no_single_document_writer_bypass(self):
        self.assertNotIn("widget.saveSchedule(", PROGRAM)
        self.assertIn("widget.saveSchedules(<WorkSchedule>[updated])", PROGRAM)
        self.assertIn("widget.saveSchedules(<WorkSchedule>[s])", PROGRAM)
        self.assertIn("saveSchedules: _saveSchedulesDirect", HOME)

    def test_batch_writer_checks_revisions_before_transaction_writes(self):
        writer = HOME[HOME.index("Future<void> _saveSchedulesDirect"):HOME.index("Future<void> _saveRecordDirect")]
        self.assertIn("db.runTransaction((transaction) async", writer)
        self.assertIn("timestampChanged || tokenChanged", writer)
        self.assertLess(writer.index("final snapshot = await transaction.get(reference)"), writer.index("transaction.set("))


if __name__ == "__main__":
    unittest.main()
