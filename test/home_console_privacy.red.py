"""Former KNOWN RED assertions from PR #49, now mandatory GREEN on the fix branch.

Tests inspect the real Home source; PR #49 keeps the original RED evidence. No fake exception is fed to
Firebase or GPS, so these are SOURCE characterization tests, not evidence of
actual console exfiltration, production logs or real device behavior.

Run explicitly: python3 test/home_console_privacy.red.py TestHomeConsolePrivacy.test_no_uid_in_push_console
They intentionally aren't matched by unittest discover -p '*test.py';\n# the dedicated fix workflow runs the unchanged assertions explicitly.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    "lib/home/home_page.dart",
    "lib/home/home_live_location.dart",
    "lib/home/home_push_notifications.dart",
)


class TestHomeConsolePrivacy(unittest.TestCase):
    def test_no_uid_in_push_console(self):
        source = (ROOT / FILES[2]).read_text(encoding="utf-8")
        exposed = [
            f"{number}: {line.strip()}"
            for number, line in enumerate(source.splitlines(), 1)
            if re.search(r"\bdebugPrint\s*\(", line)
            and re.search(r"\$(?:currentUserId|\{currentUserId\})\b", line)
        ]
        self.assertFalse(
            exposed,
            "HOME_CONSOLE_RAW_UID\n" + "\n".join(exposed),
        )

    def test_no_raw_sdk_errors_or_stack_in_home_console(self):
        exposed = []
        # Only application-owned debugPrint calls are checked. SDK/internal
        # Flutter logging remains outside the scope of this characterization.
        for path in FILES:
            source = (ROOT / path).read_text(encoding="utf-8")
            for number, line in enumerate(source.splitlines(), 1):
                if not re.search(r"\bdebugPrint(?:Stack)?\s*\(", line):
                    continue
                if re.search(r"\$(?:e|error|err|st)\b", line) or re.search(
                    r"\bdebugPrintStack\s*\(", line
                ):
                    exposed.append(f"{path}:{number}: {line.strip()}")
        self.assertFalse(
            exposed,
            "HOME_CONSOLE_RAW_SDK_EXCEPTION\n" + "\n".join(exposed),
        )

    def test_positive_vision_reports_still_use_constant_area_and_code(self):
        # Characterization is not allowed to imply the local Vision log emits
        # raw exceptions: the existing report() calls use fixed event codes.
        sources = "\n".join((ROOT / path).read_text(encoding="utf-8") for path in FILES)
        reports = re.findall(r"VisionErrorTelemetry\.report\((.*?)\);", sources, re.S)
        self.assertGreaterEqual(len(reports), 5)
        for report in reports:
            self.assertRegex(report, r"area:\s*'[a-z_]+'")
            self.assertRegex(report, r"code:\s*'[a-z_]+'")
            self.assertNotIn("$", report)


if __name__ == "__main__":
    unittest.main()
