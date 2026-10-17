from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CENTRALIZER = (ROOT / "lib/centralizer/centralizer_page.dart").read_text()
HOME = (ROOT / "lib/home/home_page.dart").read_text()
REPORT = (ROOT / "lib/reports/pdf_reports.dart").read_text()
DATES = (ROOT / "lib/utils/operational_dates.dart").read_text()


class CraiovaInterventionCorrectionContract(unittest.TestCase):
    def test_correction_keeps_existing_intervention_identity(self):
        self.assertIn("id:r.id,teamId:r.teamId,locationId:r.locationId,type:r.type", CENTRALIZER)
        self.assertIn("await widget.correctRecord(r, updated);", CENTRALIZER)
        self.assertIn("await FirebaseFirestore.instance.runTransaction((tx) async {", HOME)
        self.assertIn("if (!snapshot.exists)", HOME)
        self.assertIn("tx.update(ref, changes);", HOME)
        self.assertNotIn("tx.set(ref, changes", HOME)
        self.assertNotIn("r.startedAt=newStart;", CENTRALIZER)
        self.assertNotIn("r.finishedAt=newFinish;", CENTRALIZER)

    def test_running_interventions_cannot_be_edited_as_completed(self):
        self.assertIn('r.status == WorkAttemptStatus.completed', CENTRALIZER)
        self.assertIn('if(r.status != WorkAttemptStatus.completed || r.startedAt == null || r.finishedAt == null)', CENTRALIZER)
        self.assertIn('Pot fi corectate doar intervențiile finalizate', CENTRALIZER)

    def test_correction_does_not_turn_running_work_into_completed_work(self):
        self.assertIn('startedAt:newStart,finishedAt:newFinish,status:r.status', CENTRALIZER)
        self.assertIn('initialDate:initial,firstDate:first,lastDate:last', CENTRALIZER)

    def test_stale_edit_is_rejected_before_update(self):
        self.assertIn('for (final entry in expected.entries)', HOME)
        self.assertIn('if (current[entry.key] != entry.value)', HOME)
        self.assertIn('hasPermission(FunctionPermission.editCentralizer)', HOME)

    def test_date_and_facade_can_be_corrected_with_hours(self):
        self.assertIn("title:const Text('Data intervenției')", CENTRALIZER)
        self.assertIn("title:const Text('Fațadă realizată')", CENTRALIZER)
        self.assertIn("startedAt:newStart,finishedAt:newFinish", CENTRALIZER)
        self.assertIn("facadeDone:facadeDone", CENTRALIZER)
        self.assertIn("if(newStart==null||newFinish==null)", CENTRALIZER)

    def test_manual_entry_warns_about_same_team_room_and_day(self):
        self.assertIn('record.locationId==l.id', CENTRALIZER)
        self.assertIn('record.teamId==selectedTeamId', CENTRALIZER)
        self.assertIn('sameDay(record.startedAt!,st!)', CENTRALIZER)
        self.assertIn('Execuție deja înregistrată', CENTRALIZER)
        self.assertIn('if(!confirmed)return;', CENTRALIZER)

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
