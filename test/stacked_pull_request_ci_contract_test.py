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
)


class StackedPullRequestCiContract(unittest.TestCase):
    def test_validation_workflow_targets_stack_bases(self):
        workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
        for branch in ("main", *STACK_BASES):
            self.assertIn(branch, workflow)
        self.assertIn("permissions:", workflow)
        self.assertIn("contents: read", workflow)

    def test_android_workflow_runs_focused_stack_contracts(self):
        workflow = (ROOT / ".github/workflows/build-test-apk.yml").read_text(encoding="utf-8")
        for branch in ("main", *STACK_BASES):
            self.assertIn(branch, workflow)
        self.assertIn("flutter test test/map_road_geometry_controller_test.dart", workflow)
        self.assertIn("flutter test test/decont_financial_input_selection_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_removal_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_creation_test.dart", workflow)
        self.assertIn("flutter test test/program_start_location_resolution_test.dart", workflow)
        self.assertIn("flutter test test/expense_duplicate_decision_test.dart", workflow)
        self.assertIn("flutter test test/program_graph_state_persistence_test.dart", workflow)
        self.assertIn("flutter test test/dashboard_start_record_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_team_membership_projection_test.dart", workflow)
        self.assertIn("retention-days: 7", workflow)

    def test_native_workflow_runs_contract_without_live_permissions(self):
        workflow = (ROOT / ".github/workflows/xix-native-candidate.yml").read_text(encoding="utf-8")
        for branch in ("main", *STACK_BASES):
            self.assertIn(branch, workflow)
        self.assertIn("github.base_ref == 'codex/xix-pdf-decont-input-selection-20261021'", workflow)
        self.assertIn("github.base_ref == 'codex/xix-expense-duplicate-decision-20261021'", workflow)
        self.assertIn("github.head_ref == 'codex/xix-program-graph-state-persistence-20261021'", workflow)
        self.assertIn("flutter test test/decont_financial_input_selection_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_removal_test.dart", workflow)
        self.assertIn("flutter test test/program_schedule_item_creation_test.dart", workflow)
        self.assertIn("flutter test test/program_start_location_resolution_test.dart", workflow)
        self.assertIn("flutter test test/expense_duplicate_decision_test.dart", workflow)
        self.assertIn("flutter test test/program_graph_state_persistence_test.dart", workflow)
        self.assertIn("flutter test test/dashboard_start_record_policy_test.dart", workflow)
        self.assertIn("flutter test test/home_team_membership_projection_test.dart", workflow)
        self.assertIn("permissions:", workflow)
        self.assertIn("contents: read", workflow)
        self.assertNotIn("firebase deploy", workflow)
        self.assertNotIn("id-token: write", workflow)


if __name__ == "__main__":
    unittest.main()
    unittest.main()
