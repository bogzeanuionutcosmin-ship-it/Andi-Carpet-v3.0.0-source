"""The About screen must identify the same version as the packaged app."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class AppVersionConsistencyTest(unittest.TestCase):
    def test_displayed_version_matches_package_version(self):
        package = re.search(r'^version:\s*([^\s#]+)',
                            (ROOT / 'pubspec.yaml').read_text(), re.M)
        label = re.search(r"const String _appVersionLabel = '([^']+)';",
                          (ROOT / 'lib/main.dart').read_text())
        self.assertIsNotNone(package, 'Package version is required')
        self.assertIsNotNone(label, 'About-screen version label is required')
        self.assertEqual(label.group(1), package.group(1),
                         'About screen must match APK versionName and versionCode')


if __name__ == '__main__':
    unittest.main()
