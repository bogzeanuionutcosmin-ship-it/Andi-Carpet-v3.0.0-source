"""Privacy contract for the opt-in typed Vision session signal ingress.

These source checks supplement, but never replace, the widget/Dart tests.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "lib/vision/vision_scoped_signal_sink.dart"
AUTH = ROOT / "lib/auth/auth_gate.dart"


class VisionScopedSignalSinkContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code = SOURCE.read_text(encoding="utf-8")
        cls.active = "\n".join(
            line for line in cls.code.splitlines()
            if not line.strip().startswith(("///", "//"))
        )

    def test_pure_local_dependencies_only(self):
        self.assertEqual(
            re.findall(r"^import '([^']+)';$", self.code, re.MULTILINE),
            ["vision_error_log.dart", "vision_session_journal.dart"],
        )

    def test_no_transport_storage_global_journal_or_timers(self):
        for forbidden in (
            "FirebaseFirestore", "FirebaseAuth", "VisionErrorTelemetry.",
            "SharedPreferences", "FlutterSecureStorage", "http.get",
            "http.post", "Timer(", "Navigator.", "Clipboard.",
            "dart:io", "dart:convert", "dart:async",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, self.active)

    def test_typed_signal_and_platform_no_raw_details_argument(self):
        self.assertIn("enum VisionDiagnosticSignal", self.code)
        self.assertIn("enum VisionSignalPlatform", self.code)
        self.assertRegex(
            self.code,
            r"bool emit\(\s*VisionDiagnosticSignal signal,"
            r"\s*\{\s*required VisionSignalPlatform platform,",
        )
        self.assertNotRegex(self.active, r"String\s+(?:error|message|uid|token|details|amount)")
        self.assertIn("area: signal.area", self.active)
        self.assertIn("code: signal.code", self.active)
        self.assertIn("platform: platform.name", self.active)

    def test_scoped_revocable_lease_required(self):
        self.assertIn("final VisionSessionJournalLease _lease;", self.active)
        self.assertIn("if (!_lease.isCurrent) return false;", self.active)
        self.assertIn("return _lease.record(", self.active)
        self.assertIn("return false;", self.active)

    def test_existing_authgate_generation_predicate_remains_authoritative(self):
        auth = AUTH.read_text(encoding="utf-8")
        for token in (
            "int _sessionGeneration = 0;",
            "generation == _sessionGeneration",
            "_user?.uid == profile.uid",
            "_currentUser?.uid == profile.uid",
            "activeSessionPageBuilder!",
        ):
            self.assertIn(token, auth)


if __name__ == "__main__":
    unittest.main()
