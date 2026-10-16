"""Characterize opt-in Vision AuthGate bridge without touching installed app."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT / "lib/vision/vision_auth_session_host.dart").read_text()
GATE = (ROOT / "lib/auth/auth_gate.dart").read_text()
TEST = (ROOT / "test/vision_authgate_session_host_integration_test.dart").read_text()


class VisionAuthGateHostContract(unittest.TestCase):
    def test_local_imports_only(self):
        self.assertEqual(
            [line for line in SRC.splitlines() if line.startswith("import ")],
            ["import 'package:flutter/material.dart';",
             "import 'vision_session_journal.dart';",
             "import 'vision_session_lifecycle_coordinator.dart';"],
        )

    def test_no_backend_global_log_or_route_impersonation(self):
        code = "\n".join(line for line in SRC.splitlines()
                         if not line.lstrip().startswith("///")
                         and not line.lstrip().startswith("//"))
        for forbidden in (
            "FirebaseAuth", "FirebaseFirestore", "VisionErrorTelemetry",
            "Navigator.", "Clipboard.", "http.get", "http.post",
            "Timer(", "Future.delayed(", "SharedPreferences",
            "FlutterSecureStorage",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, code)

    def test_actual_authgate_exposes_authoritative_callback(self):
        for fragment in (
            "final generation = _sessionGeneration;",
            "generation == _sessionGeneration",
            "_user?.uid == profile.uid",
            "_currentUser?.uid == profile.uid",
            "widget.activeSessionPageBuilder!",
            "sessionIsCurrent: sessionIsCurrent",
        ):
            self.assertIn(fragment, GATE)

    def test_scope_disposes_and_checks_epoch_before_builder(self):
        for fragment in (
            "_coordinator.dispose();",
            "var lease = _coordinator.activeLease;",
            "if (!_validOwner())",
            "_coordinator.clear();",
            "lease ??= _coordinator.replaceSession(",
            "if (!lease.isCurrent)",
            "return widget.builder(context, lease);",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, SRC)

    def test_widget_integrates_actual_authgate_not_fake_lease_only(self):
        self.assertIn("harness.mount(tester, auth, db", TEST)
        self.assertIn("auth.switchTo('b')", TEST)
        self.assertIn("auth.switchTo('a')", TEST)
        self.assertIn("auth.switchTo(null)", TEST)
        self.assertIn("VisionScopedDiagnosticsPage(lease: lease)", TEST)
        self.assertIn("expect(a1.buildReport(), isNull)", TEST)


if __name__ == "__main__":
    unittest.main()
