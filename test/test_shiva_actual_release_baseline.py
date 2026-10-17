"""SHIVA follow-up: evaluate the REAL frozen evidence manifest offline.

Unlike synthetic all-pass fixtures, this test reads the actual tracked release
baseline. No production credentials, network or app code are involved.
"""
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from shiva_release_evidence_gate import REQUIRED, evaluate


class ShivaRealBaselineGateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.evidence = json.loads((ROOT / "docs/SHIVA_RELEASE_EVIDENCE_2026-10-16.json").read_text(encoding="utf-8"))
        cls.result = evaluate(cls.evidence)

    def test_every_required_gate_is_present(self):
        self.assertEqual(set(self.evidence), set(REQUIRED))

    def test_actual_baseline_does_not_claim_release_readiness(self):
        self.assertIs(self.result["production_ready"], False)
        self.assertFalse(self.result["formal_evidence_complete"])
        self.assertGreater(len(self.result["blockers"]), 0)

    def test_critical_unverified_gates_remain_blocked(self):
        for key in ("explicit_release_approval", "legacy_client_server_gate",
                    "single_finance_authority", "backup_restore_consistency"):
            with self.subTest(gate=key):
                self.assertIn(key, self.result["blockers"])

    def test_missing_evidence_cannot_become_pass(self):
        for key in REQUIRED:
            with self.subTest(gate=key):
                item = self.evidence[key]
                if item["status"] != "pass":
                    self.assertIn(key, self.result["blockers"])


if __name__ == "__main__":
    unittest.main()
