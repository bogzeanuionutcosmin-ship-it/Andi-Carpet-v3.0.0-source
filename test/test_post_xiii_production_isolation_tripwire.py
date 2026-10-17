"""Regression tripwire: XIII candidate remains disconnected from live entrypoints.

This checks direct import/wiring only; it does not establish full dependency
closure or security of the running application.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENTRYPOINTS = (
    "lib/main.dart",
    "lib/home/home_page.dart",
    "lib/auth/auth_gate.dart",
)
CANDIDATES = ("native_xiii/", "session_xiii/", "journal_v2/")


class ProductionIsolationTripwireTest(unittest.TestCase):
    def test_no_direct_candidate_import_in_live_entrypoints(self):
        for name in ENTRYPOINTS:
            source = (ROOT / name).read_text(encoding="utf-8")
            for candidate in CANDIDATES:
                with self.subTest(entrypoint=name, candidate=candidate):
                    self.assertNotIn(candidate, source)


if __name__ == "__main__":
    unittest.main()
