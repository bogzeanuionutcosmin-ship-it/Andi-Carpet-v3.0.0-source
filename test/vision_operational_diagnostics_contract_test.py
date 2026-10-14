"""Vision V0 regression contracts for observational-only error hooks.

These are source contracts; business flows are validated separately in Flutter,
Firebase emulator and manual device tests. No production database is accessed.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOME = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
EXPENSE = (ROOT / "lib/expenses/expense_page.dart").read_text(encoding="utf-8")
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
        # Even exception class names are dynamic inputs, not approved codes.
        self.assertNotIn("runtimeType.toString()", TELEMETRY)
        self.assertEqual(TELEMETRY.count("code: 'framework_error'"), 1)
        self.assertEqual(TELEMETRY.count("code: 'uncaught_error'"), 1)
        # Preserve error visibility for previous framework/async handlers.
        self.assertIn("previousFlutterHandler(details)", TELEMETRY)
        self.assertIn("previousAsyncHandler?.call(error, stack) ?? false", TELEMETRY)
        self.assertIn("VisionErrorTelemetry.installFlutterHandlers()", MAIN)

    def test_user_facing_behavior_is_preserved(self):
        self.assertIn("showErrorMessage(context, 'Nu s-a putut salva diurna: $e')", EXPENSE)
        self.assertIn("showErrorMessage(context, 'Nu s-a putut salva documentul: $err')", EXPENSE)
        self.assertIn("showErrorMessage(context, 'Nu s-a putut salva confirmarea diurnei: $e')", EXPENSE)
        self.assertIn("debugPrint('[location] Actualizarea locației a eșuat: $e')", HOME)


if __name__ == "__main__":
    unittest.main()
