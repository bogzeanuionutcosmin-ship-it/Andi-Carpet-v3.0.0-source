import unittest
from integration_gate import evaluate, REQUIRED


def evidence():
    return {"candidate_tree_sha": "a" * 40, **{key: True for key in REQUIRED[1:]}}


class IntegrationGateTests(unittest.TestCase):
    def test_complete_record_never_approves(self):
        result = evaluate(evidence())
        self.assertEqual(result["status"], "HUMAN_REVIEW_REQUIRED")
        self.assertFalse(result["release_approved"])

    def test_missing_evidence_blocks(self):
        item = evidence()
        del item["android_device_pass"]
        self.assertIn("android_device_pass", evaluate(item)["missing"])

    def test_failed_evidence_blocks(self):
        item = evidence()
        item["firebase_emulator_pass"] = False
        self.assertIn("firebase_emulator_pass", evaluate(item)["failed"])

    def test_non_boolean_evidence_blocks(self):
        item = evidence()
        item["combined_ci_pass"] = "true"
        self.assertIn("combined_ci_pass", evaluate(item)["invalid"])

    def test_invalid_sha_rejected(self):
        item = evidence()
        item["candidate_tree_sha"] = "main"
        with self.assertRaises(ValueError):
            evaluate(item)

    def test_non_object_rejected(self):
        with self.assertRaises(ValueError):
            evaluate([])


if __name__ == "__main__":
    unittest.main()
