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
        self.assertEqual(report["blockers"], list(gate.REQUIRED))

    def test_one_missing_hardware_check_blocks_all_green(self):
        items = evidence("pass", "synthetic-test-proof")
        items["hardware_android"] = {"status": "unknown", "reference": ""}
        report = gate.evaluate(items)
        self.assertFalse(report["production_ready"])
        self.assertEqual(report["blockers"], ["hardware_android"])

    def test_all_pass_is_only_formal_green(self):
        report = gate.evaluate(evidence("pass", "synthetic-test-proof"))
        self.assertTrue(report["production_ready"])
        self.assertEqual(report["passed"], len(gate.REQUIRED))

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


if __name__ == "__main__":
    unittest.main()
