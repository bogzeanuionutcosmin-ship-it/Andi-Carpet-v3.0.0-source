from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AdminApkUrlSourceContractTests(unittest.TestCase):
    def test_admin_uses_same_public_https_validator_as_apk_consumer(self):
        source = (ROOT / "lib/admin/admin_settings_actions.dart").read_text(encoding="utf-8")
        editor = source.split("Future<void> _editAndroidDownloadUrl()", 1)[1].split(
            "Future<void> _editSmsPreviousDayTime()", 1
        )[0]
        self.assertIn("validatedAndroidApkUrl(value)", editor)
        self.assertNotIn("uri.scheme=='http'", editor)


    def test_shared_settings_writer_cannot_bypass_apk_url_validation(self):
        source = (ROOT / "lib/admin/admin_settings_actions.dart").read_text(encoding="utf-8")
        writer = source.split("Future<void> _saveUiSettings()", 1)[1].split(
            "Future<void> _editDaysSetting", 1
        )[0]
        self.assertIn("final androidDownloadUrl = settings.androidDownloadUrl.trim();", writer)
        self.assertIn("validatedAndroidApkUrl(androidDownloadUrl)", writer)
        self.assertIn("'androidDownloadUrl': androidDownloadUrl", writer)
        self.assertLess(
            writer.index("validatedAndroidApkUrl(androidDownloadUrl)"),
            writer.index("await FirebaseFirestore.instance"),
        )
        self.assertLess(writer.index("return;"), writer.index("await FirebaseFirestore.instance"))


if __name__ == "__main__":
    unittest.main()
