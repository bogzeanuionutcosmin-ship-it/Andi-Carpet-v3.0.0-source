"""Source boundary: coordinator is explicit, pure, and does not mutate AuthGate."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CODE = (ROOT / 'lib/vision/vision_session_lifecycle_coordinator.dart').read_text()
AUTH = (ROOT / 'lib/auth/auth_gate.dart').read_text()


class VisionSessionLifecycleCoordinatorContract(unittest.TestCase):
    def test_only_local_dependency(self):
        self.assertEqual(
            [s for s in CODE.splitlines() if s.startswith("import ")],
            ["import 'vision_session_journal.dart';"],
        )

    def test_no_transport_global_log_or_navigation(self):
        for bad in ("Firebase", "Navigator", "VisionErrorTelemetry.",
                    "http.", "Timer(", "Future.delayed(", "Clipboard",
                    "SharedPreferences", "FlutterSecureStorage"):
            with self.subTest(bad=bad):
                self.assertNotIn(bad, CODE)

    def test_replaces_epochs_and_rejects_use_after_dispose(self):
        for fragment in (
            "if (_disposed) throw StateError",
            "_journal.startSession(",
            "required bool Function() isSessionCurrent",
            "final lease = _journal.startSession(",
            "_journal.revoke();",
            "if (_disposed) return null;",
        ):
            self.assertIn(fragment, CODE)

    def test_real_authgate_has_uid_plus_generation_predicate(self):
        for fragment in (
            "int _sessionGeneration = 0;",
            "final generation = _sessionGeneration;",
            "generation == _sessionGeneration",
            "_user?.uid == profile.uid",
            "_currentUser?.uid == profile.uid",
            "activeSessionPageBuilder!",
        ):
            self.assertIn(fragment, AUTH)


if __name__ == "__main__":
    unittest.main()
