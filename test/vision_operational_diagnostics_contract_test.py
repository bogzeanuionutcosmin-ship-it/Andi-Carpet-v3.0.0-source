"""Vision V0 regression contracts for observational-only error hooks.

These are source contracts; business flows are validated separately in Flutter,
Firebase emulator and manual device tests. No production database is accessed.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOME_PATHS = ["lib/home/home_push_notifications.dart", "lib/home/home_live_location.dart", "lib/home/home_financial_sync.dart"]
HOME = "\n".join((ROOT / p).read_text(encoding="utf-8") for p in HOME_PATHS)
EXPENSE_PATHS = ["lib/expenses/expense_settlement_actions.dart", "lib/expenses/expense_per_diem_actions.dart", "lib/expenses/expense_document_actions.dart"]
EXPENSE = "\n".join((ROOT / p).read_text(encoding="utf-8") for p in EXPENSE_PATHS)
MAIN = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
TELEMETRY = (ROOT / "lib/vision/vision_error_telemetry.dart").read_text(
    encoding="utf-8"
)

class VisionOperationalDiagnosticsContracts(unittest.TestCase):
    def test_gps_and_fcm_errors_observed(self):
        for code in (
            "background_stream_failed",
            "background_start_failed",
            "location_update_failed",
            "initialization_failed",
            "token_refresh_failed",
        ):
            self.assertIn(f"code: '{code}'", HOME)
        self.assertIn("Geolocator.getPositionStream", HOME)
        self.assertIn("await FirebaseFirestore.instance.collection('liveLocations')", HOME)
        self.assertIn("onError: (Object e)", HOME)

    def test_financial_sync_failure_observed_without_changing_query(self):
        self.assertIn("code: 'sync_failed'", HOME)
        self.assertIn("coreSyncError='Diurne: $e'", HOME)
        self.assertIn(".collection('perDiems').where('teamId',isEqualTo:scope)", HOME)

    def test_ocr_and_finance_errors_observed(self):
        for code in (
            "automatic_recognition_failed",
            "recognition_failed",
            "document_save_failed",
            "received_amount_save_failed",
            "acknowledge_failed",
            "distribution_save_failed",
            "supplementary_save_failed",
        ):
            self.assertIn(f"code: '{code}'", EXPENSE)
        self.assertIn("await widget.savePerDiem(entry)", EXPENSE)
        self.assertIn("await widget.saveExpense(e)", EXPENSE)
        self.assertIn("parsed = parseFiscalOcr(text)", EXPENSE)

    def test_observations_are_fixed_codes_not_raw_exceptions(self):
        # Never inject $e / interpolation or OCR/GPS/financial payload in report.
        for source in (HOME, EXPENSE):
            calls = re.findall(
                r"VisionErrorTelemetry\.report\((.*?)\);",
                source,
                flags=re.DOTALL,
            )
            self.assertGreater(len(calls), 3)
            for call in calls:
                self.assertRegex(call, r"area:\s*'[a-z_]+'")
                self.assertRegex(call, r"code:\s*'[a-z_]+'")
                self.assertNotIn("$", call)
        self.assertNotIn("FirebaseFirestore.instance", TELEMETRY)
        self.assertNotIn("exception.toString()", TELEMETRY)
        self.assertEqual(MAIN.count("startVisionDiagnostics();"), 1)
        bootstrap = (ROOT / "lib/vision/vision_bootstrap.dart").read_text()
        self.assertIn("VisionErrorTelemetry.installFlutterHandlers", bootstrap)
        self.assertIn("unawaited", bootstrap)

    def test_user_facing_behavior_is_preserved(self):
        self.assertIn("showErrorMessage(context, 'Nu s-a putut salva diurna: $e')", EXPENSE)
        self.assertIn("showErrorMessage(context, 'Nu s-a putut salva documentul: $err')", EXPENSE)
        self.assertIn("showErrorMessage(context, 'Nu s-a putut salva confirmarea diurnei: $e')", EXPENSE)
        self.assertIn("debugPrint('[location] Actualizarea locației a eșuat: $e')", HOME)

    def test_every_operational_code_has_one_guarded_hook_in_its_real_module(self):
        expected = {
            HOME_PATHS[0]: ["initialization_failed", "token_refresh_failed"],
            HOME_PATHS[1]: ["background_stream_failed", "background_start_failed", "location_update_failed"],
            HOME_PATHS[2]: ["sync_failed"],
            EXPENSE_PATHS[0]: ["received_amount_save_failed"],
            EXPENSE_PATHS[1]: ["acknowledge_failed", "distribution_save_failed", "supplementary_save_failed"],
            EXPENSE_PATHS[2]: ["automatic_recognition_failed", "recognition_failed", "document_save_failed"],
        }
        all_runtime = "\n".join(p.read_text() for p in (ROOT / "lib").rglob("*.dart"))
        for path, codes in expected.items():
            source = (ROOT / path).read_text()
            for code in codes:
                with self.subTest(path=path, code=code):
                    self.assertEqual(source.count(f"code: '{code}'"), 1)
                    self.assertEqual(all_runtime.count(f"code: '{code}'"), 1)
            self.assertIn("_sessionActive" if path.startswith("lib/home") else "_visionSessionActive", source)
        self.assertIn("diagnosticSessionIsCurrent: () => _sessionActive", (ROOT / "lib/home/home_page.dart").read_text())

    def test_no_verifier_backend_or_public_device_wide_ui_route(self):
        runtime = [p for p in (ROOT / "lib").rglob("*.dart") if "vision" not in p.parts]
        for path in runtime:
            source = path.read_text()
            self.assertNotIn("VisionExpenseSaveVerifier", source)
            self.assertNotIn("VisionDiagnosticsPage", source)
        self.assertNotIn("runtimeType.toString()", TELEMETRY)
        self.assertIn("if (!_persistenceStarted) return;", TELEMETRY)
        self.assertIn("maxEntries: 150", TELEMETRY)
        self.assertIn("maxBytes: 48 * 1024", TELEMETRY)
        self.assertIn("Duration(days: 7)", TELEMETRY)

    def test_device_wide_ui_fails_closed_and_checks_live_owner_before_and_after_copy(self):
        page = (ROOT / "lib/vision/vision_diagnostics_page.dart").read_text()
        self.assertIn("identical(widget.log, VisionErrorTelemetry.log)", page)
        self.assertIn("widget.isSessionCurrent?.call() == true", page)
        self.assertIn("if (!_canInspect)", page)
        self.assertIn("if (!mounted || !_canInspect) return;", page)
        self.assertLess(page.index("if (!_canInspect)"), page.index("VisionDiagnosticAdvisor.assess"))
        self.assertGreaterEqual(page.count("if (!_canInspect)"), 4)


if __name__ == "__main__":
    unittest.main()
