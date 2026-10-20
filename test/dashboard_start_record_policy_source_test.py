import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class DashboardStartRecordPolicySourceContract(unittest.TestCase):
    def test_dashboard_delegates_start_record_selection(self):
        page = (ROOT / "lib/dashboard/dashboard_page.dart").read_text(encoding="utf-8")
        self.assertIn("dashboardStartRecordDecision<CentralizerRecord>(", page)
        self.assertIn("DashboardStartRecordAction.blockedByOtherLocation", page)
        self.assertIn("DashboardStartRecordAction.alreadyRunning", page)
        start = page.split("Future<void> _startLocationOnce(ScheduleItem item) async {", 1)[1]
        start = start.split("final Set<String> _pendingFinishes", 1)[0]
        self.assertNotIn("widget.records.where", start)

    def test_policy_is_registered_as_a_dashboard_part(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        policy = (ROOT / "lib/dashboard/dashboard_start_record_policy.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(
            main.count("part 'dashboard/dashboard_start_record_policy.dart';"), 1
        )
        self.assertIn("enum DashboardStartRecordAction", policy)
        self.assertIn("eventTimeOf", policy)


if __name__ == "__main__":
    unittest.main()
