"""Contract tests for fail-closed XIX native evidence collection."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "verify_xix_native_evidence", ROOT / "scripts/verify_xix_native_evidence.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class NativeEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "native-flow.pdf").write_bytes(b"%PDF-1.4\n%%EOF\n")
        self.observation = {
            "completed": True,
            "connectedFlow": {"observed": 1},
            "sameAttemptRetry": "ok",
            "twoNativeClients": {"accepted": [True, False]},
            "unauthorizedTeam": "permission-denied",
            "legacyAndDeletion": "ok",
            "offlineBeforeStart": "ok",
            "revokedProfile": "ok",
            "restore": "ok",
            "pdf": "ok",
        }
        self.save()

    def save(self):
        (self.root / "observations.json").write_text(json.dumps(self.observation))

    def test_complete_evidence_passes(self):
        module.verify(self.root)

    def test_missing_pdf_fails(self):
        (self.root / "native-flow.pdf").unlink()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_incomplete_scenario_fails(self):
        self.observation["completed"] = False
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_assertion_fails(self):
        self.observation.pop("restore")
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_both_clients_accepted_fails(self):
        self.observation["twoNativeClients"]["accepted"] = [True, True]
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)


if __name__ == "__main__":
    unittest.main()
