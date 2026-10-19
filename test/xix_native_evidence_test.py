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
            "sameAttemptRetry": "one document, identical payload accepted",
            "twoNativeClients": {"accepted": [True, False]},
            "unauthorizedTeam": "permission-denied",
            "legacyAndDeletion": "legacy update passed; deleted baseline rejected",
            "offlineBeforeStart": "native transaction rejected; reconnect has no queued record",
            "revokedProfile": "cached Auth identity cannot write after server profile deactivation",
            "restore": "admin complete/repeat passed; readable inventory followed by denied mixed batch rolled back allowed update and deletions; oversized restore changed no records",
            "pdf": "real builder with data reloaded from native Firestore; missing registry retained",
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

    def test_truncated_pdf_fails(self):
        (self.root / "native-flow.pdf").write_bytes(b"%PDF-1.4\\nmissing trailer")
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_observations_fails(self):
        (self.root / "observations.json").unlink()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_malformed_observations_fails(self):
        (self.root / "observations.json").write_text("{invalid")
        with self.assertRaises(ValueError):
            module.verify(self.root)

    def test_missing_connected_record_fails(self):
        self.observation["connectedFlow"]["observed"] = 0
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_revoked_profile_not_rejected_fails(self):
        self.observation["revokedProfile"] = "success"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_offline_write_queued_fails(self):
        self.observation["offlineBeforeStart"] = "queued"
        self.save()
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

    def test_placeholder_retry_evidence_fails(self):
        self.observation["sameAttemptRetry"] = "ok"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_placeholder_legacy_evidence_fails(self):
        self.observation["legacyAndDeletion"] = "ok"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_placeholder_pdf_evidence_fails(self):
        self.observation["pdf"] = "ok"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_permission_denial_fails(self):
        self.observation["unauthorizedTeam"] = "success"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_unproven_restore_fails(self):
        self.observation["restore"] = "ok"
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
