from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CENTRALIZER = (ROOT / "lib/centralizer/centralizer_page.dart").read_text()
REPORT = (ROOT / "lib/reports/pdf_reports.dart").read_text()
DATES = (ROOT / "lib/utils/operational_dates.dart").read_text()


class CraiovaInterventionCorrectionContract(unittest.TestCase):
    def test_correction_keeps_existing_intervention_identity(self):
        self.assertIn("id:r.id,teamId:r.teamId,locationId:r.locationId,type:r.type", CENTRALIZER)
        self.assertIn("await widget.saveRecord(updated);", CENTRALIZER)
        self.assertNotIn("r.startedAt=newStart;", CENTRALIZER)
        self.assertNotIn("r.finishedAt=newFinish;", CENTRALIZER)

    def test_date_and_facade_can_be_corrected_with_hours(self):
        self.assertIn("title:const Text('Data intervenției')", CENTRALIZER)
        self.assertIn("title:const Text('Fațadă realizată')", CENTRALIZER)
        self.assertIn("startedAt:newStart,finishedAt:newFinish", CENTRALIZER)
        self.assertIn("facadeDone:facadeDone", CENTRALIZER)
        self.assertIn("if(newStart==null||newFinish==null)", CENTRALIZER)

    def test_report_uses_actual_record_dates_and_facade(self):
        self.assertIn("'date':recordEventTime(r)", REPORT)
        self.assertIn("record?.facadeDone==true", REPORT)
        self.assertIn("final when = recordEventTime(r);", REPORT)
        self.assertIn("r.finishedAt ?? r.startedAt", DATES)

    def test_scheduled_work_does_not_replace_execution_history(self):
        self.assertIn("recordBelongsToWorkDate(r, schedule.date)", REPORT)
        self.assertIn("if (sameDayRecords.isNotEmpty) continue;", REPORT)


if __name__ == "__main__":
    unittest.main()
