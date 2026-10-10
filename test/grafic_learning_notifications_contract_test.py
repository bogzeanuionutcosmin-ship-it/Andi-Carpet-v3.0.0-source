from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "lib" / "main.dart").read_text()
FUNCTIONS = (ROOT / "functions" / "index.js").read_text()

class GraficLearningNotificationsContract(unittest.TestCase):
    def test_learning_minimum_three(self):
        self.assertIn("if (history.length < 3) return null;", MAIN)
        self.assertIn("duration.inSeconds <= 0", MAIN)
    def test_recalculation_preserves_active_items(self):
        self.assertIn("_pendingItemsForDay(day, workDate, includeActive: false)", MAIN)
    def test_alert_cooldown(self):
        self.assertIn("difference(day.planAlertAt!).inMinutes < 60", MAIN)
        self.assertIn("difference(day.planAlertAt!).inHours < 4", MAIN)
    def test_auto_recalculation_cooldown(self):
        self.assertIn("difference(updated.lastRecalculatedAt!).inMinutes >= 30", MAIN)
    def test_sms_uses_previous_calendar_day(self):
        self.assertIn("addDaysToDateKey(workDateKey, -1)", FUNCTIONS)
        self.assertIn("context.smsPreviousDayTime", FUNCTIONS)
    def test_sms_cancel_old_date_and_no_eta_spam(self):
        self.assertIn("cancelPendingSmsJobsForSchedule(event.params.scheduleId, beforeDateKey)", FUNCTIONS)
        self.assertIn("Nu mai trimitem actualizări pentru simple schimbări de ETA", FUNCTIONS)
    def test_learning_audit_and_sms_gateway(self):
        self.assertIn("_recordRoutingChoice(updated", MAIN)
        self.assertIn("exports.planManagerSms", FUNCTIONS)

if __name__ == "__main__": unittest.main()
