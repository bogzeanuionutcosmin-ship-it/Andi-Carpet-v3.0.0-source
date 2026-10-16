"""Unit tests for Shiva's offline review gate; no SDK, credentials or network."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "shiva_release_evidence_gate.py"
spec = importlib.util.spec_from_file_location("shiva_release_evidence_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def evidence(status="blocked", reference=""):
    return {key: {"status": status, "reference": reference} for key in gate.REQUIRED}


class ReleaseEvidenceGateTest(unittest.TestCase):
    def test_default_blocked(self):
        report = gate.evaluate(evidence())
        self.assertFalse(report["production_ready"])
        self.assertFalse(report["formal_evidence_complete"])
        self.assertEqual(report["blockers"], list(gate.REQUIRED))

    def test_one_missing_hardware_check_blocks_all_green(self):
        items = evidence("pass", "synthetic-test-proof")
        items["hardware_android"] = {"status": "unknown", "reference": ""}
        report = gate.evaluate(items)
        self.assertFalse(report["production_ready"])
        self.assertEqual(report["blockers"], ["hardware_android"])

    def test_all_pass_is_only_formal_green(self):
        report = gate.evaluate(evidence("pass", "synthetic-test-proof"))
        self.assertFalse(report["production_ready"])
        self.assertTrue(report["formal_evidence_complete"])
        self.assertEqual(report["passed"], len(gate.REQUIRED))

    def test_synthetic_all_pass_never_authorizes_production(self):
        items = evidence("pass", "arbitrary self-assertion")
        report = gate.evaluate(items)
        self.assertEqual(report["blockers"], [])
        self.assertTrue(report["formal_evidence_complete"])
        self.assertIs(report["production_ready"], False)

    def test_missing_or_extra_keys_rejected(self):
        items = evidence()
        items.pop("protected_hashes")
        with self.assertRaises(ValueError):
            gate.evaluate(items)
        items = evidence()
        items["unreviewed"] = {"status": "pass", "reference": "x"}
        with self.assertRaises(ValueError):
            gate.evaluate(items)

    def test_invalid_and_unsubstantiated_pass_rejected(self):
        items = evidence()
        items["exact_sha_ci"] = {"status": "pass", "reference": "  "}
        with self.assertRaises(ValueError):
            gate.evaluate(items)
        items["exact_sha_ci"] = {"status": "maybe", "reference": ""}
        with self.assertRaises(ValueError):
            gate.evaluate(items)

    def test_no_implicit_coercion_or_leaked_extra_fields(self):
        items = evidence()
        items["vision_enum_only"]["status"] = True
        with self.assertRaises(ValueError):
            gate.evaluate(items)
        items = evidence()
        items["vision_enum_only"]["uid"] = "should-not-be-in-evidence"
        with self.assertRaises(ValueError):
            gate.evaluate(items)

    def test_cli_fails_closed_and_has_no_write_effect(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "evidence.json"
            path.write_text(json.dumps(evidence()), encoding="utf-8")
            before = path.read_bytes()
            self.assertEqual(gate.main([str(path)]), 1)
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(gate.main([str(path) + ".missing"]), 2)


    def test_malformed_json_and_wrong_root_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "evidence.json"
            path.write_text("{", encoding="utf-8")
            self.assertEqual(gate.main([str(path)]), 2)
            path.write_text("[]", encoding="utf-8")
            self.assertEqual(gate.main([str(path)]), 2)

    def test_missing_field_and_wrong_reference_type_fail_closed(self):
        items = evidence()
        items["money_exactness"] = {"status": "blocked"}
        with self.assertRaises(ValueError):
            gate.evaluate(items)
        items = evidence()
        items["money_exactness"]["reference"] = ["private-payload"]
        with self.assertRaises(ValueError):
            gate.evaluate(items)

    def test_status_values_cannot_be_truthy_objects(self):
        for status in (1, True, ["pass"], {"status": "pass"}, None):
            items = evidence()
            items["hardware_ios"]["status"] = status
            with self.subTest(status=status), self.assertRaises(ValueError):
                gate.evaluate(items)

    def test_every_required_gate_independently_blocks_release(self):
        for key in gate.REQUIRED:
            items = evidence("pass", "synthetic-only-not-release-proof")
            items[key] = {"status": "fail", "reference": "synthetic"}
            with self.subTest(key=key):
                report = gate.evaluate(items)
                self.assertFalse(report["production_ready"])
                self.assertEqual(report["blockers"], [key])

    def test_checked_in_baseline_is_never_approved(self):
        baseline = SCRIPT.parents[1] / "docs" / "SHIVA_RELEASE_EVIDENCE_2026-10-16.json"
        items = json.loads(baseline.read_text(encoding="utf-8"))
        report = gate.evaluate(items)
        self.assertEqual(report["total"], 20)
        self.assertFalse(report["production_ready"])
        self.assertIn("explicit_release_approval", report["blockers"])
        self.assertIn("journal_cross_process_cas", report["blockers"])
        self.assertIn("legacy_client_server_gate", report["blockers"])


if __name__ == "__main__":
    unittest.main()
