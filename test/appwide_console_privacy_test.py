"""App-owned console privacy guard with explicit protected known-unsafe cases.

Source-level checks cannot certify SDK/OS logger behavior. Two Dashboard
geocoding leaks are fixed; four Routing/Learning leaks remain KNOWN UNSAFE in
two files pinned by the project's immutable 116-SHA manifest. Never hide
these exceptions or change the manifest merely to make this test pass.
"""
from collections import Counter
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

DIRECT_DEBUG = re.compile(r"\bdebugPrint\s*\((.*?)\)\s*;", re.DOTALL)
DIRECT_PRINT = re.compile(r"(?<![\w.])print\s*\(", re.DOTALL)
DIRECT_STACK = re.compile(r"\bdebugPrintStack\s*\(", re.DOTALL)
# Reject a concatenation that happens to begin/end with quotes. This is
# deliberately lexical: a Dart parser, dynamic logger, SDK and OS are outside
# the scope of this source guard.
SINGLE_LITERAL = re.compile(
    r"""(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")""", re.DOTALL
)

# Exactly one occurrence per pinned source path. Duplicate copies of an
# old unsafe string must fail; a set() would silently hide duplicates.
KNOWN_UNSAFE_ROUTING = {
    ("lib/schedule/program_graph_actions.dart", "'[geocode] Server fallback: $e'"),
    ("lib/schedule/program_graph_actions.dart", "'[geocode] Nominatim $value: $e'"),
    ("lib/schedule/program_route_learning_actions.dart",
     "'[learning] Istoricul manual de rutare nu a putut fi citit: $e'"),
    ("lib/schedule/program_route_learning_actions.dart",
     "'[learning] Alegerea traseului nu a putut fi jurnalizată: $e'"),
}
EXPECTED_UNSAFE = Counter({entry: 1 for entry in KNOWN_UNSAFE_ROUTING})

DASHBOARD_CODES = (
    "[geocode] dashboard_server_failed",
    "[geocode] dashboard_nominatim_failed",
)


def inspect_direct_debug(relative_path, source):
    """Return inspected call count, protected-known occurrences, other leaks."""
    found = 0
    known = Counter()
    unsafe = []
    for match in DIRECT_DEBUG.finditer(source):
        found += 1
        expr = match.group(1).strip()
        site = (relative_path, expr)
        if site in KNOWN_UNSAFE_ROUTING:
            known[site] += 1
            continue
        if SINGLE_LITERAL.fullmatch(expr) is None or "$" in expr:
            unsafe.append(site)
    return found, known, unsafe


class AppWideConsolePrivacy(unittest.TestCase):
    def test_all_other_debug_print_calls_use_fixed_literals(self):
        found = 0
        observed_unsafe = Counter()
        unapproved = []
        for path in sorted(LIB.rglob("*.dart")):
            relative = str(path.relative_to(ROOT))
            count, known, leaks = inspect_direct_debug(
                relative, path.read_text(encoding="utf-8")
            )
            found += count
            observed_unsafe.update(known)
            unapproved.extend(leaks)
        self.assertGreaterEqual(found, 18, "Unexpected change in coverage")
        self.assertFalse(unapproved, "Unapproved dynamic console logging: " + repr(unapproved))
        self.assertEqual(
            observed_unsafe, EXPECTED_UNSAFE,
            "Four protected Routing leaks must stay individually enumerated "
            "until a separately approved, freeze-safe remediation",
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

    def test_synthetic_unsafe_logging_is_not_mistaken_for_static_codes(self):
        # This mutation-style fixture verifies the validator itself. Never
        # inject sample tokens/addresses into actual app logs or CI artifacts.
        for expr in ("'[push] $uid'", "'[geocode] $value: $error'",
                     "'prefix' + privateValue + 'suffix'", "privateValue"):
            with self.subTest(expr=expr):
                _, known, leaks = inspect_direct_debug(
                    "lib/mock_fixture.dart", f"debugPrint({expr});"
                )
                self.assertFalse(known)
                self.assertEqual(leaks, [("lib/mock_fixture.dart", expr)])
        count, known, leaks = inspect_direct_debug(
            "lib/mock_fixture.dart", "debugPrint('[push] event_code');"
        )
        self.assertEqual((count, len(known), len(leaks)), (1, 0, 0))

    def test_duplicate_protected_known_unsafe_site_must_fail_exact_count(self):
        # Regression against using a set() which drops duplicate occurrences.
        path, expr = "lib/schedule/program_graph_actions.dart", (
            "'[geocode] Server fallback: $e'"
        )
        _, known, leaks = inspect_direct_debug(
            path, f"debugPrint({expr}); debugPrint({expr});"
        )
        self.assertFalse(leaks)
        self.assertEqual(known[(path, expr)], 2)
        self.assertNotEqual(known, Counter({(path, expr): 1}))


if __name__ == "__main__":
    unittest.main()
