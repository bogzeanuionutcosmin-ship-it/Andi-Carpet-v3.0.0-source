"""Structural guard for static Vision mascot in session-gated diagnostics.

These are source invariants, not a substitute for the widget tests proving
behavior under logout and cross-account session invalidation.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
DIAGNOSTICS = ROOT / "lib/vision/vision_diagnostics_page.dart"
AVATAR = ROOT / "lib/vision/vision_assistant_avatar.dart"


class VisionDiagnosticsAvatarBoundary(unittest.TestCase):
    def setUp(self):
        self.source = DIAGNOSTICS.read_text(encoding="utf-8")

    def test_static_avatar_is_header_only_in_both_gated_views(self):
        self.assertIn("import 'vision_assistant_avatar.dart';", self.source)
        self.assertEqual(self.source.count("VisionAssistantAvatar("), 2)
        self.assertEqual(self.source.count("key: Key('vision-diagnostics-avatar')"), 2)
        self.assertIn("size: 40,", self.source)
        self.assertIn("if (!_canInspect) {", self.source)
        self.assertLess(self.source.index("if (!_canInspect) {"),
                        self.source.index("final currentLog"))
        self.assertIn("final entries = currentLog.entries;", self.source)

    def test_fail_closed_owner_and_installation_log_checks_unchanged(self):
        self.assertIn(
            "if (widget.log == null || identical(widget.log, VisionErrorTelemetry.log)) {",
            self.source,
        )
        self.assertIn("return widget.isSessionCurrent?.call() == true;",
                      self.source)
        self.assertIn("} catch (_) {\n      return false;", self.source)
        self.assertIn("if (!_canInspect) {", self.source)
        self.assertIn("if (!_canInspect) {\n                _denyStaleSession();",
                      self.source)

    def test_no_new_transport_or_sensitivity_in_avatar_or_page_imports(self):
        self.assertEqual(
            len(re.findall(r"^import 'vision_assistant_avatar.dart';$",
                           self.source, flags=re.MULTILINE)),
            1,
        )
        for forbidden in (
            "FirebaseFirestore", "FirebaseFunctions",
            "http.get(", "http.post(", "AnimationController",
            "Timer(", "ImagePicker", "Geolocator",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, AVATAR.read_text(encoding="utf-8"))
        self.assertIn("class VisionAssistantAvatar extends StatelessWidget",
                      AVATAR.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
