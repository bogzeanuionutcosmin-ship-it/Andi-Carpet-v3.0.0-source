"""Read-only acceptance boundaries for real app-root Vision navigation tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
DART = (ROOT / "test/vision_root_navigator_session_acceptance_test.dart").read_text()
APP = (ROOT / "lib/ui/app_root_theme.dart").read_text()


class VisionRootNavigatorAcceptanceContract(unittest.TestCase):
    def test_uses_real_app_root_and_synthetic_firestore_sources(self):
        for statement in (
            "await tester.pumpWidget(AndiCarpetaApp(",
            "authSources: AuthGateSources(",
            "homeBuilder: (key, profile, isCurrent)",
            "SessionAuth()",
            "SessionFirestore()",
            "VisionScopedDiagnosticsPage(lease: lease)",
        ):
            with self.subTest(statement=statement):
                self.assertIn(statement, DART)
        for unsafe in ("FirebaseAuth.instance", "FirebaseFirestore.instance",
                       "firebase deploy", "flutter build apk --release"):
            self.assertNotIn(unsafe, DART)

    def test_app_root_has_per_uid_navigator_and_messenger_replacement(self):
        for statement in (
            "GlobalKey<NavigatorState> _sessionNavigatorKey",
            "GlobalKey<ScaffoldMessengerState> _sessionMessengerKey",
            "if (_navigationUid == uid) return false;",
            "_sessionNavigatorKey = GlobalKey<NavigatorState>();",
            "_sessionMessengerKey = GlobalKey<ScaffoldMessengerState>();",
            "onSessionChanged: _replaceSessionNavigator",
            "activeSessionPageBuilder: widget.homeBuilder",
        ):
            with self.subTest(statement=statement):
                self.assertIn(statement, APP)

    def test_real_routes_cover_a_b_a2_logout_and_transient_same_uid(self):
        for statement in (
            "auth.switchTo('b');", "auth.switchTo('a');",
            "auth.switchTo(null);", "auth.events.add(null);",
            "auth.events.add(SessionUser('a'));",
            "expect(find.byType(VisionScopedDiagnosticsPage), findsNothing);",
            "expect(a1.buildReport(), isNull);",
            "expect(old.buildReport(), isNull);",
            "expect(leases.length, 3);",
            "expect(leases.length, 1);",
        ):
            with self.subTest(statement=statement):
                self.assertIn(statement, DART)


if __name__ == "__main__":
    unittest.main()
