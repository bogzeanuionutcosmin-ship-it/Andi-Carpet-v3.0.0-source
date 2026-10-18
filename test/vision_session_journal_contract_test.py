"""Fail-closed structural checks for a purely ephemeral Vision session journal."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "lib/vision/vision_session_journal.dart"


class VisionSessionJournalContract(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding="utf-8")
        self.executable = "\n".join(
            line for line in self.text.splitlines()
            if not line.lstrip().startswith("///") and
            not line.lstrip().startswith("//")
        )

    def test_only_pure_local_vision_models_are_imported(self):
        imports = re.findall(r"^import '([^']+)';$", self.text, re.MULTILINE)
        self.assertEqual(imports, [
            "vision_diagnostic_report.dart", "vision_error_log.dart"
        ])

    def test_no_persistence_network_storage_or_global_device_journal(self):
        for bad in (
            "FirebaseFirestore", "FirebaseAuth", "FirebaseFunctions",
            "FlutterSecureStorage", "VisionErrorTelemetry.",
            "http.get(", "http.post(", "Timer(", "Future.delayed(",
            "Clipboard.", "dart:io", "dart:async",
            "SharedPreferences", "VisionLocalPersistence",
        ):
            with self.subTest(bad=bad):
                self.assertNotIn(bad, self.executable)

    def test_old_epoch_rejected_before_read_and_report(self):
        self.assertIn("identical(_currentKey, key)", self.executable)
        self.assertIn("if (verify()) return true;", self.executable)
        self.assertIn("if (identical(_currentKey, key)) revoke();", self.executable)
        self.assertIn("if (current == null) return null;", self.executable)
        self.assertIn("if (!isCurrent) return null;", self.executable)
        self.assertIn("final key = Object();", self.executable)
        self.assertIn("_activeLog = null;", self.executable)

    def test_journal_requires_external_epoch_ownership_and_no_route(self):
        self.assertIn("required bool Function() isSessionCurrent", self.text)
        self.assertIn("class VisionSessionJournalLease", self.text)
        for bad in ("Navigator.", "BuildContext", "Route(", "Widget build(",
                    "setState(", "FirebaseUserProfile"):
            with self.subTest(bad=bad):
                self.assertNotIn(bad, self.executable)


if __name__ == "__main__":
    unittest.main()
