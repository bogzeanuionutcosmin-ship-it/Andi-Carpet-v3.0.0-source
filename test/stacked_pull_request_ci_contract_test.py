import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STACK_BASES = (
    "codex/xix-program-postpone-policy-20261021",
    "codex/xix-program-start-snapshot-20261021",
    "codex/xix-pdf-decont-input-selection-20261021",
    "codex/xix-program-schedule-item-removal-20261021",
    "codex/xix-program-schedule-item-addition-20261021",
    "codex/xix-home-team-membership-projection-20261021",
    "codex/xix-program-start-location-resolution-20261021",
    "codex/xix-expense-duplicate-decision-20261021",
    "codex/xix-program-graph-state-persistence-20261021",
    "codex/xix-dashboard-start-record-policy-20261021",
    "codex/xix-home-location-proximity-policy-20261021",
    "codex/xix-home-active-schedule-policy-20261021",
    "codex/xix-home-arrival-candidate-policy-20261021",
    "codex/xix-home-gps-sampling-profile-20261021",
    "codex/xix-dashboard-operational-status-20261021",
    "codex/xix-expense-optional-ocr-prefill-20261021",
    "codex/xix-home-live-location-resources-20261021",
    "codex/xix-map-route-line-presentation-20261021",
)


class StackedPullRequestCiContract(unittest.TestCase):
    def assert_one_run_key_per_step(self, workflow):
        step = None
        run_keys = 0
        for line in workflow.splitlines():
            if line.startswith("      - "):
                if step is not None:
                    self.assertLessEqual(run_keys, 1, f"duplicate run keys in {step}")
                step = line.strip()
                run_keys = 0
            elif line.startswith("        run:") and step is not None:
                run_keys += 1
        if step is not None:
            self.assertLessEqual(run_keys, 1, f"duplicate run keys in {step}")

    def test_validation_workflow_targets_stack_bases(self):
        workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
        for branch in ("main", *STACK_BASES):
            self.assertIn(branch, workflow)
        self.assertIn("permissions:", workflow)
        self.assertIn("contents: read", workflow)

    def test_android_workflow_runs_focused_stack_contracts(self):
        workflow = (ROOT / ".github/workflows/build-test-apk.yml").read_text(encoding="utf-8")
        self.assert_one_run_key_per_step(workflow)
        for branch in ("main", *STACK_BASES):
            self.assertIn(branch, workflow)
        self.assertIn("flutter test test/map_road_geometry_controller_test.dart", workflow)
        self.assertIn("flutter test test/map_route_line_presentation_test.dart", workflow)
        self.assertIn("flutter test test/decont_financial_input_selection_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_removal_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_creation_test.dart", workflow)
        self.assertIn("flutter test test/program_start_location_resolution_test.dart", workflow)
        self.assertIn("flutter test test/expense_duplicate_decision_test.dart", workflow)
        self.assertIn("flutter test test/program_graph_state_persistence_test.dart", workflow)
        self.assertIn("flutter test test/dashboard_start_record_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_location_proximity_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_location_sampling_profile_test.dart", workflow)
        self.assertIn("flutter test test/dashboard_operational_status_test.dart", workflow)
        self.assertIn("- name: Test Home active schedule policy contract", workflow)
        self.assertIn("flutter test test/home_arrival_candidate_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_location_sampling_profile_test.dart", workflow)
        self.assertIn("flutter test test/home_active_schedule_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_arrival_candidate_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_team_membership_projection_test.dart", workflow)
        self.assertIn("retention-days: 7", workflow)

    def test_native_workflow_runs_contract_without_live_permissions(self):
        workflow = (ROOT / ".github/workflows/xix-native-candidate.yml").read_text(encoding="utf-8")
        self.assert_one_run_key_per_step(workflow)
        for branch in ("main", *STACK_BASES):
            self.assertIn(branch, workflow)
        self.assertIn("github.base_ref == 'codex/xix-pdf-decont-input-selection-20261021'", workflow)
        self.assertIn("github.base_ref == 'codex/xix-expense-duplicate-decision-20261021'", workflow)
        self.assertIn("github.base_ref == 'codex/xix-home-location-proximity-policy-20261021'", workflow)
        self.assertIn("github.base_ref == 'codex/xix-home-arrival-candidate-policy-20261021'", workflow)
        self.assertIn("github.base_ref == 'codex/xix-home-gps-sampling-profile-20261021'", workflow)
        self.assertIn("github.base_ref == 'codex/xix-home-live-location-resources-20261021'", workflow)
        self.assertIn("github.base_ref == 'codex/xix-map-route-line-presentation-20261021'", workflow)
        self.assertIn("flutter test test/map_route_line_presentation_test.dart", workflow)
        self.assertIn("github.head_ref == 'codex/xix-program-graph-state-persistence-20261021'", workflow)
        self.assertIn("flutter test test/decont_financial_input_selection_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_removal_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_creation_test.dart", workflow)
        self.assertIn("flutter test test/program_start_location_resolution_test.dart", workflow)
        self.assertIn("flutter test test/expense_duplicate_decision_test.dart", workflow)
        self.assertIn("flutter test test/program_graph_state_persistence_test.dart", workflow)
        self.assertIn("flutter test test/dashboard_start_record_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_location_proximity_policy_test.dart", workflow)
        self.assertIn("github.base_ref == 'codex/xix-dashboard-operational-status-20261021'", workflow)
        self.assertIn("flutter test test/dashboard_operational_status_test.dart", workflow)
        self.assertIn("flutter test test/home_team_membership_projection_test.dart", workflow)
        self.assertIn("permissions:", workflow)
        self.assertIn("contents: read", workflow)
        self.assertNotIn("firebase deploy", workflow)
        self.assertNotIn("id-token: write", workflow)


    def test_home_sampling_profile_is_extracted_without_changing_the_predicate(self):
        page = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        policy = (ROOT / "lib/home/home_location_sampling_profile.dart").read_text(
            encoding="utf-8"
        )
        self.assertIn("homeUsesEconomicalLocationTracking(", page)
        self.assertNotIn("_personalLocationMode == 'economic' && !_nativeLocationProximityBoost", page)
        self.assertEqual(main.count("part 'home/home_location_sampling_profile.dart';"), 1)
        self.assertIn(
            "locationMode == 'economic' && !proximityBoost",
            policy,
        )


    def test_dashboard_delegates_operational_status_priority(self):
        page = (ROOT / "lib/dashboard/dashboard_page.dart").read_text(encoding="utf-8")
        policy = (ROOT / "lib/dashboard/dashboard_operational_status.dart").read_text(
            encoding="utf-8"
        )
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("dashboardTeamOperationalStatus(", page)
        status_start = page.index("    String stateText;")
        status_end = page.index("    final pendingForEstimate", status_start)
        status_block = page[status_start:status_end]
        self.assertIn("switch (operationalStatus)", status_block)
        self.assertNotIn("if (running.isNotEmpty)", status_block)
        self.assertEqual(main.count("part 'dashboard/dashboard_operational_status.dart';"), 1)
        self.assertIn("DashboardOperationalStatus.running", policy)
        self.assertIn("insideWorkWindow", policy)


    def test_optional_automatic_expense_ocr_prefill_preserves_manual_fallback(self):
        page = (ROOT / "lib/expenses/expense_page.dart").read_text(encoding="utf-8")
        scan = (ROOT / "lib/expenses/expense_ocr_scan.dart").read_text(encoding="utf-8")
        self.assertIn("shouldRunOptionalAutomaticExpenseOcr(", page)
        self.assertIn("scanOptionalAutomaticExpenseOcr(", page)
        self.assertIn("ocrSetting?.enabled == true", page)
        self.assertIn("ocrSetting?.mode == LearningMode.automatic", page)
        self.assertIn("result.error == null", page)
        self.assertIn("imageBytes.isNotEmpty && enabled && automaticMode", scan)
        self.assertIn("scanExpenseDocumentOcr(", scan)
        self.assertIn("if (e != null) await _saveNewExpense(e);", page)


    def test_home_live_location_resources_own_only_timer_and_stream_lifecycle(self):
        page = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        resources = (ROOT / "lib/home/home_live_location_resources.dart").read_text(
            encoding="utf-8"
        )
        android = (ROOT / ".github/workflows/build-test-apk.yml").read_text(
            encoding="utf-8"
        )
        native = (ROOT / ".github/workflows/xix-native-candidate.yml").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("_liveLocationTimer", page)
        self.assertNotIn("_backgroundLocationSubscription", page)
        self.assertIn("_liveLocationResources.stop()", page)
        self.assertIn("_liveLocationResources.startPeriodicPolling(", page)
        self.assertIn("_liveLocationResources.clearPositionSubscription()", page)
        self.assertIn("_liveLocationResources.replacePositionSubscription(", page)
        self.assertIn("_liveLocationResources.dispose()", page)
        self.assertEqual(main.count("part 'home/home_live_location_resources.dart';"), 1)
        self.assertIn("Timer.periodic(interval, (_) => onTick())", resources)
        self.assertIn("await previous?.cancel();", resources)
        self.assertIn("if (_disposed) return;", resources)
        self.assertIn(
            "flutter test test/home_live_location_resources_test.dart",
            android,
        )
        self.assertIn(
            "flutter test test/home_live_location_resources_test.dart",
            native,
        )


if __name__ == "__main__":
    unittest.main()
    unittest.main()
