import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class StackedPullRequestCiContract(unittest.TestCase):
    def test_validation_workflow_targets_the_integration_base(self):
        workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
        self.assertIn("branches: [main, fix/grafic-edit-controls-20261017, fix/grafic-end-to-end-xiv-20261017, mission-xix/modular-integration]", workflow)
        self.assertIn("permissions:\\n  contents: read", workflow)

    def test_android_test_apk_workflow_targets_the_integration_base(self):
        workflow = (ROOT / ".github/workflows/build-test-apk.yml").read_text(encoding="utf-8")
        self.assertIn("branches: [main, fix/grafic-edit-controls-20261017, fix/grafic-end-to-end-xiv-20261017, mission-xix/modular-integration]", workflow)
        self.assertIn("retention-days: 7", workflow)

    def test_native_emulator_accepts_stacked_prs_without_live_permissions(self):
        workflow = (ROOT / ".github/workflows/xix-native-candidate.yml").read_text(encoding="utf-8")
        self.assertIn("branches: [main, mission-xix/modular-integration]", workflow)
        self.assertIn("github.base_ref == 'mission-xix/modular-integration'", workflow)
        self.assertIn("permissions:\\n  contents: read", workflow)
        self.assertNotIn("firebase deploy", workflow)
        self.assertNotIn("id-token: write", workflow)


if __name__ == "__main__":
    unittest.main()
