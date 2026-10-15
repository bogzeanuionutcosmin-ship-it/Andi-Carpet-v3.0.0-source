"""App-owned console privacy guard with explicit protected known-unsafe cases.

Source-level checks cannot certify SDK/OS logger behavior. Two Dashboard
geocoding leaks are fixed; four Routing/Learning leaks remain KNOWN UNSAFE in
two files pinned by the project's immutable 116-SHA manifest. Never hide
these exceptions or change the manifest merely to make this test pass.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

DIRECT_DEBUG = re.compile(r"\bdebugPrint\s*\((.*?)\)\s*;", re.DOTALL)
DIRECT_PRINT = re.compile(r"(?<![\w.])print\s*\(", re.DOTALL)
DIRECT_STACK = re.compile(r"\bdebugPrintStack\s*\(", re.DOTALL)

# Exact, exhaustively counted exceptions. NOT permission to add more leaks.
# Their source bytes are protected by ROUTING_PDF_PROTECTED_2026-10-13.json.
KNOWN_UNSAFE_ROUTING = {
    ("lib/schedule/program_graph_actions.dart", "'[geocode] Server fallback: $e'"),
    ("lib/schedule/program_graph_actions.dart", "'[geocode] Nominatim $value: $e'"),
    ("lib/schedule/program_route_learning_actions.dart",
     "'[learning] Istoricul manual de rutare nu a putut fi citit: $e'"),
    ("lib/schedule/program_route_learning_actions.dart",
     "'[learning] Alegerea traseului nu a putut fi jurnalizată: $e'"),
}

DASHBOARD_CODES = (
    "[geocode] dashboard_server_failed",
    "[geocode] dashboard_nominatim_failed",
)


class AppWideConsolePrivacy(unittest.TestCase):
    def test_all_other_debug_print_calls_use_fixed_literals(self):
        found = 0
        observed_unsafe = set()
        for path in sorted(LIB.rglob("*.dart")):
            source = path.read_text(encoding="utf-8")
            relative = str(path.relative_to(ROOT))
            for match in DIRECT_DEBUG.finditer(source):
                found += 1
                expr = match.group(1).strip()
                with self.subTest(path=relative, expression=expr[:65]):
                    if (relative, expr) in KNOWN_UNSAFE_ROUTING:
                        observed_unsafe.add((relative, expr))
                        continue
                    self.assertRegex(
                        expr,
                        r"^(['\"]).*\1$",
                        "Direct debugPrint must receive one fixed literal",
                    )
                    self.assertNotIn(
                        "$", expr,
                        "Runtime values may not reach the direct console",
                    )
        self.assertGreaterEqual(found, 18, "Unexpected change in coverage")
        self.assertEqual(
            observed_unsafe, KNOWN_UNSAFE_ROUTING,
            "Protected Routing leaks must remain explicitly recorded until approved remediation",
        )

    def test_no_direct_print_or_unfiltered_stack_dump(self):
        for path in sorted(LIB.rglob("*.dart")):
            source = path.read_text(encoding="utf-8")
            with self.subTest(path=str(path.relative_to(ROOT))):
                self.assertIsNone(DIRECT_PRINT.search(source), "Raw print() is prohibited")
                self.assertIsNone(
                    DIRECT_STACK.search(source),
                    "Unfiltered debugPrintStack() is prohibited",
                )

    def test_dashboard_errors_have_context_free_codes(self):
        source = (ROOT / "lib/dashboard/dashboard_work_actions.dart").read_text(
            encoding="utf-8"
        )
        for code in DASHBOARD_CODES:
            with self.subTest(code=code):
                self.assertEqual(source.count(f"debugPrint('{code}')"), 1)


if __name__ == "__main__":
    unittest.main()
