"""Vision session widget admission: no UID-only reconnect, no backend access."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "lib/vision/vision_authenticated_session_scope.dart"
AUTH = ROOT / "lib/auth/auth_gate.dart"


class VisionAuthenticatedScopeContract(unittest.TestCase):
    def setUp(self):
        self.s = SOURCE.read_text(encoding="utf-8")
        self.statements = "\n".join(
            x for x in self.s.splitlines()
            if not x.lstrip().startswith("///")
            and not x.lstrip().startswith("//")
        )

    def test_only_flutter_material_and_pure_session_models(self):
        imports = re.findall(r"^import '([^']+)';$", self.s, re.MULTILINE)
        self.assertEqual(imports, [
            "package:flutter/material.dart",
            "vision_session_journal.dart",
            "vision_session_lifecycle_coordinator.dart",
        ])

    def test_widget_requires_independent_session_epoch_not_uid(self):
        self.assertIn("required this.sessionEpochKey", self.s)
        self.assertIn("final Object sessionEpochKey;", self.s)
        self.assertIn("required this.sessionIsCurrent", self.s)
        self.assertIn(
            "identical(oldWidget.sessionEpochKey, widget.sessionEpochKey)",
            self.s,
        )
        self.assertIn("void _checkExistingEpoch()", self.s)
        self.assertIn("_coordinator.clear();", self.s)
        self.assertNotIn("_lease = _coordinator.replaceSession(\n"
                         "        isSessionCurrent: widget.sessionIsCurrent,\n"
                         "      );\n    }\n  }\n\n  @override\n"
                         "  Widget build", self.s)

    def test_session_denied_before_exposing_child_and_disposal(self):
        self.assertIn("if (!_authoritativeCurrent(widget.sessionIsCurrent) ||",
                      self.s)
        self.assertIn("_lease?.isCurrent != true", self.s)
        self.assertIn("widget.builder(context, null)", self.s)
        self.assertIn("_coordinator.activeLease", self.s)
        self.assertIn("_coordinator.dispose();", self.s)

    def test_no_backend_global_log_navigator_or_timers(self):
        for bad in ("FirebaseFirestore", "FirebaseAuth", "VisionErrorTelemetry.",
                    "http.get", "http.post", "Navigator.", "Timer(",
                    "SharedPreferences", "FlutterSecureStorage", "Clipboard."):
            with self.subTest(bad=bad):
                self.assertNotIn(bad, self.statements)

    def test_authgate_already_checks_uid_and_generation(self):
        auth = AUTH.read_text(encoding="utf-8")
        for marker in (
            "int _sessionGeneration = 0;",
            "generation == _sessionGeneration",
            "_user?.uid == profile.uid",
            "_currentUser?.uid == profile.uid",
            "activeSessionPageBuilder!",
        ):
            self.assertIn(marker, auth)


if __name__ == "__main__":
    unittest.main()
