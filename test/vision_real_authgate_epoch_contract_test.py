"""Source guard for real AuthGate-to-Vision integration acceptance fixtures.

These tests do not wire up production Home. They ensure our synthetic
Firebase widget tests use actual AuthGate and its real session ownership API.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "test/vision_real_authgate_epoch_integration_test.dart"
GATE = ROOT / "lib/auth/auth_gate.dart"


class VisionRealAuthGateAcceptanceContract(unittest.TestCase):
    def setUp(self):
        self.fixture = FIXTURE.read_text(encoding="utf-8")
        self.gate = GATE.read_text(encoding="utf-8")

    def test_uses_actual_gate_with_synthetic_sources_and_owner_closure(self):
        for piece in (
            "home: AuthGate(", "sources: AuthGateSources(",
            "activeSessionPageBuilder: harness.buildPage",
            "onSessionChanged: harness.onSessionChanged",
            "SessionAuth()", "SessionFirestore()",
            "VisionScopedDiagnosticsPage(key: key, lease: active!)",
            "journal.revoke();",
            "isSessionCurrent: sessionIsCurrent",
        ):
            with self.subTest(piece=piece):
                self.assertIn(piece, self.fixture)
        self.assertNotIn("FirebaseAuth.instance", self.fixture)
        self.assertNotIn("FirebaseFirestore.instance", self.fixture)

    def test_real_gate_predicate_is_uid_plus_epoch_not_uid_only(self):
        for piece in (
            "int _sessionGeneration = 0;",
            "final generation = _sessionGeneration;",
            "generation == _sessionGeneration",
            "_user?.uid == profile.uid",
            "_currentUser?.uid == profile.uid",
            "activeSessionPageBuilder!(ValueKey(profile.uid), profile, sessionIsCurrent)",
        ):
            with self.subTest(piece=piece):
                self.assertIn(piece, self.gate)
        self.assertIn("if (hadSession) _sessionGeneration++;", self.gate)
        self.assertIn("if (changedUser) {", self.gate)
        self.assertIn("return widget.activeSessionPageBuilder!", self.gate)

    def test_acceptance_covers_epoch_churn_logout_and_transient_reconnect(self):
        for piece in (
            "auth.switchTo('b');",
            "auth.switchTo('a');",
            "db.lateProfile('a', 0, 'Stale Original Alice');",
            "auth.switchTo(null);",
            "auth.events.add(null);",
            "auth.events.add(SessionUser('a'));",
            "expect(firstA.buildReport(), isNull);",
            "expect(old.buildReport(), isNull);",
            "expect(harness.epochs, 3);",
            "expect(harness.epochs, 1);",
        ):
            with self.subTest(piece=piece):
                self.assertIn(piece, self.fixture)


if __name__ == "__main__":
    unittest.main()
