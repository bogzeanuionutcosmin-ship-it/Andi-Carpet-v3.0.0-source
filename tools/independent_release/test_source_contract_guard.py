import unittest
from pathlib import Path
from source_contract_guard import inspect


WORKFLOW = "on:\n  push:\n    branches: [main]\nsteps:\n  - run: firebase deploy"
GRADLE = 'release { signingConfig = signingConfigs.getByName("debug") }'
BACKFILL = "initializeApp({ projectId: 'andicarpet-e777e' });\nawait db.runTransaction(async tx => { written++; deleted++; });"


class SourceContractGuardTests(unittest.TestCase):
    def test_repository_source_hazards_are_detected(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / ".github/workflows/restore-member-directory.yml").read_text(encoding="utf-8")
        gradle = (root / "android/app/build.gradle.kts").read_text(encoding="utf-8")
        backfill = (root / "functions/backfill_member_directory.js").read_text(encoding="utf-8")
        result = inspect(workflow, gradle, backfill)
        self.assertEqual(result["status"], "BLOCK")
        # The repository may harden the deploy trigger independently (for
        # example, manual dispatch with explicit approval). Keep asserting
        # unresolved source hazards without requiring a fixed hazard to remain.
        self.assertTrue({
            "RELEASE_DEBUG_SIGNING",
            "BACKFILL_HARDCODED_PRODUCTION",
            "BACKFILL_TRANSACTION_COUNTER_RETRY_REVIEW",
        }.issubset(set(result["findings"])))
        self.assertFalse(result["production_safe"])
        self.assertFalse(result["release_approved"])

    def test_all_known_risks(self):
        result = inspect(WORKFLOW, GRADLE, BACKFILL)
        self.assertEqual(result["status"], "BLOCK")
        self.assertEqual(len(result["findings"]), 4)
        self.assertFalse(result["release_approved"])

    def test_missing_risks_never_certifies(self):
        result = inspect("on: workflow_dispatch", "signingConfig = releaseKey", "initializeApp()")
        self.assertEqual(result["status"], "UNCERTIFIED")
        self.assertFalse(result["production_safe"])

    def test_debug_signing_only(self):
        self.assertEqual(inspect("", GRADLE, "")["findings"], ["RELEASE_DEBUG_SIGNING"])

    def test_backfill_counter_retry_risk(self):
        result = inspect("", "", "runTransaction(async () => { written++; })")
        self.assertIn("BACKFILL_TRANSACTION_COUNTER_RETRY_REVIEW", result["findings"])


if __name__ == "__main__":
    unittest.main()
