"""App-wide privacy regression for direct, application-owned console logging.

The tests inspect Dart source, not runtime OS/SDK logs. They only prove that
the application does not pass dynamic data to direct debugPrint() or print().
Vision's local diagnostic events and normal operational audit are separate.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

# All current direct debugPrint calls are simple fixed string literals.
DIRECT_DEBUG = re.compile(r"\bdebugPrint\s*\((.*?)\)\s*;", re.DOTALL)
DIRECT_PRINT = re.compile(r"(?<![\w.])print\s*\(", re.DOTALL)
DIRECT_STACK = re.compile(r"\bdebugPrintStack\s*\(", re.DOTALL)

REQUIRED_CODES = {
    "lib/dashboard/dashboard_work_actions.dart": (
        "[geocode] dashboard_server_failed",
        "[geocode] dashboard_nominatim_failed",
    ),
    "lib/schedule/program_graph_actions.dart": (
        "[geocode] program_server_failed",
        "[geocode] program_nominatim_failed",
    ),
    "lib/schedule/program_route_learning_actions.dart": (
        "[learning] routing_history_read_failed",
        "[learning] routing_choice_write_failed",
    ),
}


class AppWideConsolePrivacy(unittest.TestCase):
    def test_all_application_debug_print_arguments_are_fixed_literals(self):
        found = 0
        for path in sorted(LIB.rglob("*.dart")):
            source = path.read_text(encoding="utf-8")
            for match in DIRECT_DEBUG.finditer(source):
                found += 1
                expr = match.group(1).strip()
                with self.subTest(path=str(path.relative_to(ROOT)), expression=expr[:65]):
                    self.assertRegex(
                        expr,
                        r"^(['\"]).*\1$",
                        "A direct debugPrint expression must be a single literal",
                    )
                    self.assertNotIn(
                        "$", expr,
                        "Private runtime values must never reach the app-owned console",
                    )
        self.assertGreaterEqual(found, 18, "Unexpected loss of logging coverage")

    def test_no_direct_print_or_unfiltered_stack_dump(self):
        for path in sorted(LIB.rglob("*.dart")):
            source = path.read_text(encoding="utf-8")
            with self.subTest(path=str(path.relative_to(ROOT))):
                self.assertIsNone(DIRECT_PRINT.search(source), "Raw print() is prohibited")
                self.assertIsNone(
                    DIRECT_STACK.search(source),
                    "Unfiltered debugPrintStack() is prohibited",
                )

    def test_geo_and_route_errors_have_context_free_codes(self):
        for relative_path, codes in REQUIRED_CODES.items():
            source = (ROOT / relative_path).read_text(encoding="utf-8")
            for code in codes:
                with self.subTest(path=relative_path, code=code):
                    self.assertIn(f"debugPrint('{code}')", source)
                    self.assertEqual(source.count(f"debugPrint('{code}')"), 1)


if __name__ == "__main__":
    unittest.main()
