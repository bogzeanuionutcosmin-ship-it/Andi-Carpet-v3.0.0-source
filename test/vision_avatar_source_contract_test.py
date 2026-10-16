"""Static Vision avatar source guard; deliberately no device data access."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "lib/vision/vision_assistant_avatar.dart"


class VisionAvatarSourceContract(unittest.TestCase):
    def setUp(self):
        self.source = PATH.read_text(encoding="utf-8")

    def test_avatar_requires_only_flutter_material(self):
        imports = [
            line.strip() for line in self.source.splitlines()
            if line.strip().startswith("import ")
        ]
        self.assertEqual(imports, ["import 'package:flutter/material.dart';"])

    def test_no_network_storage_auth_or_telemetry_dependency(self):
        for term in (
            "FirebaseFirestore", "FirebaseAuth", "VisionErrorTelemetry",
            "VisionErrorLog", "http.get", "http.post", "Clipboard",
            "dart:io", "dart:async", "flutter_secure_storage",
        ):
            with self.subTest(term=term):
                self.assertNotIn(term, self.source)

    def test_no_animation_timer_interaction_or_route(self):
        # Inspect executable source, not Dart documentation comments.
        # The descriptive comment mentioning Navigator is not navigation code.
        code = "\n".join(line for line in self.source.splitlines()
                         if not line.lstrip().startswith("//"))
        for term in (
            "AnimationController", "TickerProvider", "Timer(",
            "Future.delayed", "GestureDetector", "InkWell(", "onTap:",
            "Navigator.", "OverlayEntry", "IconButton(", "setState(",
        ):
            with self.subTest(term=term):
                self.assertNotIn(term, code)

    def test_semantic_label_and_painter_are_explicit(self):
        self.assertIn("class VisionAssistantAvatar extends StatelessWidget",
                      self.source)
        self.assertIn("Semantics(", self.source)
        self.assertIn("label: 'Vision, asistent grafic'", self.source)
        self.assertIn("class _VisionBodyPainter extends CustomPainter",
                      self.source)


if __name__ == "__main__":
    unittest.main()
