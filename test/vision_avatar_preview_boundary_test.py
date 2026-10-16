"""Source-level guard: Vision mascot preview must stay offline and opt-in.

This is a lexical import/dependency contract, not a substitute for inspecting
Dart transitive dependencies or OS/network traces on a real device.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "lib/vision/vision_avatar_preview_app.dart"
ENTRY = ROOT / "lib/vision/vision_avatar_preview_main.dart"
AVATAR = ROOT / "lib/vision/vision_assistant_avatar.dart"


class VisionAvatarPreviewBoundaryTest(unittest.TestCase):
    def test_preview_only_imports_flutter_material_and_static_avatar(self):
        source = PREVIEW.read_text(encoding="utf-8")
        imports = re.findall(r"^import\s+['\"]([^'\"]+)['\"];",
                             source, flags=re.MULTILINE)
        self.assertEqual(
            imports,
            ["package:flutter/material.dart", "vision_assistant_avatar.dart"],
        )
        self.assertIn("class VisionAvatarPreviewApp extends StatefulWidget", source)
        self.assertIn("VisionAssistantAvatar(size: _size)", source)

    def test_explicit_entrypoint_does_not_start_normal_app(self):
        source = ENTRY.read_text(encoding="utf-8")
        self.assertRegex(source, r"void main\(\)\s*=>\s*runApp\(")
        self.assertIn("const VisionAvatarPreviewApp()", source)
        self.assertNotIn("package:andi_carpeta/main.dart", source)
        self.assertNotIn("Firebase.initializeApp", source)

    def test_preview_has_no_app_data_network_timers_or_telemetry(self):
        source = "\n".join([
            PREVIEW.read_text(encoding="utf-8"),
            ENTRY.read_text(encoding="utf-8"),
            AVATAR.read_text(encoding="utf-8"),
        ])
        executable = "\n".join(
            line for line in source.splitlines()
            if not line.strip().startswith("//")
        )
        forbidden = [
            "Firebase", "Firestore", "VisionErrorLog", "VisionErrorTelemetry",
            "Navigator.", "http.", "Timer(", "Future.delayed",
            "Clipboard.", "Geolocator", "ImagePicker", "FlutterSecureStorage",
            "onLongPress:", "onTap:", "GestureDetector", "AnimationController",
            "StreamSubscription", "rootBundle",
        ]
        for item in forbidden:
            with self.subTest(item=item):
                self.assertNotIn(item, executable)

    def test_original_production_entrypoint_does_not_import_preview(self):
        entry = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertNotIn("vision_avatar_preview_app.dart", entry)
        self.assertNotIn("vision_avatar_preview_main.dart", entry)
        self.assertIn("vision_avatar_preview_app.dart",
                      ENTRY.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
