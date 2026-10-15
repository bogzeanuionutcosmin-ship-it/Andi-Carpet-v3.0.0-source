"""Privacy baseline: prevent *growth* of pre-existing raw Home console sinks.

This is a characterization guard, NOT a security pass: the limits 1 and 9 are
known-unsafe baseline findings in Issue #47. PR #49 has explicit RED tests
requiring *zero* raw emissions, and a later fix must make those GREEN.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    "lib/home/home_page.dart",
    "lib/home/home_live_location.dart",
    "lib/home/home_push_notifications.dart",
)


def raw_console_sites():
    raw_uid = []
    raw_sdk = []
    for path in SOURCES:
        source = (ROOT / path).read_text(encoding="utf-8")
        for line_no, line in enumerate(source.splitlines(), 1):
            if not re.search(r"\bdebugPrint(?:Stack)?\s*\(", line):
                continue
            if re.search(r"\$(?:currentUserId|\{currentUserId\})\b", line):
                raw_uid.append((path, line_no))
            if re.search(r"\$(?:e|error|err|st)\b", line) or re.search(r"\bdebugPrintStack\s*\(", line):
                raw_sdk.append((path, line_no))
    return raw_uid, raw_sdk


class HomeConsolePrivacyBaseline(unittest.TestCase):
    def test_known_unsafe_console_sinks_must_not_increase(self):
        uid, raw = raw_console_sites()
        # Captured from actual PR #46 HEAD; a smaller count is an improvement.
        # These allowances MUST NOT be interpreted as a privacy guarantee.
        self.assertLessEqual(len(uid), 1, f"additional raw UID logging: {uid}")
        self.assertLessEqual(len(raw), 9, f"additional raw SDK logging: {raw}")

    def test_local_vision_log_remains_payload_free(self):
        combined = "\n".join((ROOT / p).read_text(encoding="utf-8") for p in SOURCES)
        reports = re.findall(r"VisionErrorTelemetry\.report\((.*?)\);", combined, re.S)
        self.assertGreaterEqual(len(reports), 5)
        for report in reports:
            self.assertRegex(report, r"area:\s*'[a-z_]+'")
            self.assertRegex(report, r"code:\s*'[a-z_]+'")
            self.assertNotIn("$", report)


if __name__ == "__main__":
    unittest.main()
