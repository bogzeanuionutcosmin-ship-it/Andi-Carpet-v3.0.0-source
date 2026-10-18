"""Static guard for the opt-in Android Vision avatar preview workflow.

Source contracts complement GitHub Actions and an actual APK compile; they
are not Android instrumentation tests and do not certify native SDK traffic.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/vision-avatar-android-preview.yml"
ENTRY = ROOT / "lib/vision/vision_avatar_preview_main.dart"


class VisionAvatarAndroidPreviewContract(unittest.TestCase):
    def setUp(self):
        self.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_compiles_only_the_offline_preview_entrypoint(self):
        self.assertIn(
            "flutter build apk --debug --target lib/vision/vision_avatar_preview_main.dart",
            self.workflow,
        )
        self.assertNotIn("flutter build apk --release", self.workflow)
        self.assertIn("flutter test test/vision_assistant_avatar_test.dart "
                      "test/vision_avatar_preview_app_test.dart", self.workflow)
        self.assertIn("void main()", ENTRY.read_text(encoding="utf-8"))

    def test_only_own_pr_head_can_execute(self):
        self.assertIn(
            "if: github.head_ref == 'ci/vision-avatar-offline-android-20261015'",
            self.workflow,
        )
        self.assertIn("pull_request:", self.workflow)
        self.assertIn("contents: read", self.workflow)
        self.assertIn("cancel-in-progress: true", self.workflow)

    def test_no_publication_install_or_credentials(self):
        executable_lines = "\n".join(
            line for line in self.workflow.splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        )
        for disallowed in (
            "upload-artifact", "flutter install", "firebase deploy",
            "gh release", "actions/create-release", "play-store",
            "secrets.", "FIREBASE_TOKEN", "google-github-actions/auth",
            "flutter build appbundle", "flutter build apk --release",
        ):
            with self.subTest(disallowed=disallowed):
                self.assertNotIn(disallowed, executable_lines)

    def test_apk_metadata_is_inspected_without_upload(self):
        self.assertIn("test -s build/app/outputs/flutter-apk/app-debug.apk",
                      self.workflow)
        self.assertIn("dump badging", self.workflow)
        self.assertIn("dump permissions", self.workflow)
        self.assertIn("com.example.andi_carpeta", self.workflow)


if __name__ == "__main__":
    unittest.main()
