import unittest
from source_contract_guard import inspect


WORKFLOW = "on:\n  push:\n    branches: [main]\nsteps:\n  - run: firebase deploy"
GRADLE = 'release { signingConfig = signingConfigs.getByName("debug") }'
BACKFILL = "initializeApp({ projectId: 'andicarpet-e777e' });\nawait db.runTransaction(async tx => { written++; deleted++; });"


class SourceContractGuardTests(unittest.TestCase):
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
