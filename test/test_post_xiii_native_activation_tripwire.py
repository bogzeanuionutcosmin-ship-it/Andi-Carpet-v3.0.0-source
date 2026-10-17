"""Source-level tripwire for accidental activation of XIII native candidate.

This checks actual Dart source, not a synthetic finance model. It does not
prove platform security, but fails CI if the explicit release refusal vanishes.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "lib/finance/native_xiii/native_journal_xiii.dart"
SQLITE = ROOT / "lib/finance/native_xiii/sqlite_xiii.dart"


class NativeActivationTripwireTest(unittest.TestCase):
    def test_factory_is_explicitly_closed(self):
        source = NATIVE.read_text(encoding="utf-8")
        pattern = (
            r"HistoryV2Journal\s+createNativeHistoryXiiiJournal\(\)\s*=>\s*"
            r"throw\s+const\s+FinanceRefusal\("
            r"\s*'native_v2_platform_release_blocked'\s*\)"
        )
        self.assertRegex(source, pattern)

    def test_android_requires_explicit_packaged_library(self):
        source = SQLITE.read_text(encoding="utf-8")
        self.assertIn("DynamicLibrary.open('libandi_finance_sqlite3.so')", source)
        self.assertIn("Platform.isAndroid", source)

    def test_native_transaction_guards_still_present(self):
        source = NATIVE.read_text(encoding="utf-8")
        for requirement in ("locking_mode=EXCLUSIVE", "BEGIN IMMEDIATE",
                            "journal_mode=DELETE", "synchronous=EXTRA"):
            with self.subTest(requirement=requirement):
                self.assertIn(requirement, source)


if __name__ == "__main__":
    unittest.main()
