"""Contract tests for fail-closed XIX native evidence collection."""
import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "verify_xix_native_evidence", ROOT / "scripts/verify_xix_native_evidence.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class NativeEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "native-flow.pdf").write_bytes(b"%PDF-1.4\n%%EOF\n")
        (self.root / "decont-flow.pdf").write_bytes(b"%PDF-1.4\n%%EOF\n")
        self.observation = {
            "completed": True,
            "graphCreatedThroughUi": True,
            "programStartThroughUi": {
                "geocodeQueries": ["Punct plecare test", "Punct final test"],
                "serverPersistedEndpoints": True,
                "started": True,
            },
            "expenseOcrThroughUi": {
                "controlledRecognition": True,
                "manualCorrection": 150.25,
                "settlementId": "xix-receipt-settlement",
                "serverPersisted": True,
                "decontPdfBuiltFromServerExpense": True,
                "homePagePersistence": True,
            },
            "correctionThroughUi": True,
            "homeCorrectionThroughUi": 'actual app root, HomePage callback, server-confirmed edit and revert, UI permission removal',
            "productionCorrectionWriter": 'UI adapter uses HomePage persistence; stale, deleted, unauthorized and offline corrections rejected',
            "connectedFlow": {
                "expected": "11 completed Craiova Dashboard records after double taps and server reload",
                "observed": 11,
                "id": "record-1",
            },
            "craiova11": {
                "observed": 11,
                "day15": 6,
                "day16": 5,
                "uniqueIds": 11,
                "centralizerCount": 11,
                "dashboardScheduleItems": 11,
                "pdfMatchedScheduleItems": 11,
                "scheduleDatesMatchExecutions": True,
                "pdfMarkers": [f"Craiova {i:02d}" for i in range(1, 12)],
                "plannedRowName": "Craiova planificată",
                "plannedRowRecordCount": 0,
            },
            "sameAttemptRetry": "one document, identical payload accepted",
            "twoNativeClients": {
                "accepted": [True, False],
                "loser": "StateError stale baseline",
                "serverWinner": "race-0",
                "documentCount": 1,
            },
            "unauthorizedTeam": "permission-denied",
            "legacyAndDeletion": "legacy update passed; deleted baseline rejected",
            "offlineBeforeStart": "offline write rejected without queue; explicit server-backed retry after reconnect persisted once and released its lock on completion",
            "revokedProfile": "cached Auth identity cannot write after server profile deactivation",
            "restore": "admin complete/repeat passed; readable inventory followed by denied mixed batch rolled back allowed update and deletions; oversized restore changed no records",
            "pdf": "11 Firestore-reloaded Craiova records rendered; planned row retained",
        }
        self.save()

    def save(self):
        (self.root / "observations.json").write_text(json.dumps(self.observation))

    def test_complete_evidence_passes(self):
        module.verify(self.root)

    def test_missing_ui_graph_evidence_fails(self):
        self.observation.pop("graphCreatedThroughUi")
        self.save()
        with self.assertRaisesRegex(AssertionError, "UI"):
            module.verify(self.root)

    def test_ui_graph_evidence_requires_boolean_true(self):
        for invalid in (False, 1, "true", None):
            with self.subTest(value=invalid):
                self.observation["graphCreatedThroughUi"] = invalid
                self.save()
                with self.assertRaisesRegex(AssertionError, "UI"):
                    module.verify(self.root)

    def test_program_start_requires_controlled_geocode_and_server_persistence(self):
        self.observation.pop("programStartThroughUi")
        self.save()
        with self.assertRaisesRegex(AssertionError, "Program START"):
            module.verify(self.root)

    def test_program_start_rejects_missing_server_persistence(self):
        self.observation["programStartThroughUi"]["serverPersistedEndpoints"] = False
        self.save()
        with self.assertRaisesRegex(AssertionError, "Program START"):
            module.verify(self.root)

    def test_expense_requires_review_correction_and_server_persistence(self):
        self.observation.pop("expenseOcrThroughUi")
        self.save()
        with self.assertRaisesRegex(AssertionError, "Expenses OCR"):
            module.verify(self.root)

    def test_expense_requires_server_persisted_corrected_value(self):
        self.observation["expenseOcrThroughUi"]["serverPersisted"] = False
        self.save()
        with self.assertRaisesRegex(AssertionError, "Expenses OCR"):
            module.verify(self.root)

    def test_expense_requires_production_home_persistence(self):
        for invalid in (None, False, 1, "true"):
            with self.subTest(value=invalid):
                self.observation["expenseOcrThroughUi"]["homePagePersistence"] = invalid
                self.save()
                with self.assertRaisesRegex(AssertionError, "Expenses OCR"):
                    module.verify(self.root)

    def test_missing_correction_ui_evidence_fails(self):
        self.observation.pop("correctionThroughUi")
        self.save()
        with self.assertRaisesRegex(AssertionError, "correction through UI"):
            module.verify(self.root)

    def test_correction_ui_evidence_requires_boolean_true(self):
        for invalid in (False, 1, "true", None):
            with self.subTest(value=invalid):
                self.observation["correctionThroughUi"] = invalid
                self.save()
                with self.assertRaisesRegex(AssertionError, "correction through UI"):
                    module.verify(self.root)

    def test_prior_general_writer_artifact_is_rejected(self):
        self.observation.pop("productionCorrectionWriter")
        self.save()
        with self.assertRaisesRegex(AssertionError, "Production correction writer"):
            module.verify(self.root)

    def test_unproven_production_correction_marker_is_rejected(self):
        for invalid in (True, "ok", None):
            self.observation["productionCorrectionWriter"] = invalid
            self.save()
            with self.assertRaisesRegex(AssertionError, "Production correction writer"):
                module.verify(self.root)

    def test_component_only_correction_artifact_is_rejected(self):
        self.observation.pop("homeCorrectionThroughUi")
        self.save()
        with self.assertRaisesRegex(AssertionError, "HomePage correction UI"):
            module.verify(self.root)

    def test_home_correction_marker_requires_complete_probe(self):
        self.observation["homeCorrectionThroughUi"] = "ok"
        self.save()
        with self.assertRaisesRegex(AssertionError, "HomePage correction UI"):
            module.verify(self.root)

    def test_missing_pdf_fails(self):
        (self.root / "native-flow.pdf").unlink()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_decont_pdf_fails(self):
        (self.root / "decont-flow.pdf").unlink()
        with self.assertRaisesRegex(AssertionError, "decont PDF"):
            module.verify(self.root)

    def test_incomplete_scenario_fails(self):
        self.observation["completed"] = False
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_assertion_fails(self):
        self.observation.pop("restore")
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_permission_denial_fails(self):
        self.observation["unauthorizedTeam"] = "success"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_unproven_restore_fails(self):
        self.observation["restore"] = "ok"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_both_clients_accepted_fails(self):
        self.observation["twoNativeClients"]["accepted"] = [True, True]
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_numeric_client_results_do_not_pass_as_booleans(self):
        self.observation["twoNativeClients"]["accepted"] = [1, 0]
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_boolean_connected_count_does_not_pass_as_integer(self):
        self.observation["connectedFlow"]["observed"] = True
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_unproven_retry_marker_fails(self):
        self.observation["sameAttemptRetry"] = "ok"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_unproven_pdf_marker_fails(self):
        self.observation["pdf"] = "ok"
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_wrong_craiova_day_totals_fail(self):
        self.observation["craiova11"]["day15"] = 5
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_graph_to_record_join_fails(self):
        self.observation["craiova11"]["pdfMatchedScheduleItems"] = 10
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_schedule_date_mismatch_fails(self):
        self.observation["craiova11"]["scheduleDatesMatchExecutions"] = False
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_planned_row_must_have_no_execution_record(self):
        self.observation["craiova11"]["plannedRowRecordCount"] = 1
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_duplicate_craiova_pdf_marker_fails(self):
        self.observation["craiova11"]["pdfMarkers"][-1] = self.observation["craiova11"]["pdfMarkers"][0]
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)

    def test_missing_unexecuted_pdf_row_fails(self):
        self.observation["craiova11"]["plannedRowName"] = ""
        self.save()
        with self.assertRaises(AssertionError):
            module.verify(self.root)


class NativeWorkflowContractTest(unittest.TestCase):
    def test_native_scenario_opens_active_graph_before_dashboard_execution(self):
        source = (ROOT / "integration_test/xix_native_test.dart").read_text()
        program_page = (ROOT / "lib/schedule/program_page.dart").read_text()
        self.assertIn("app.ProgramPage(", source)
        self.assertIn("expect(schedule.graphName,'Craiova XIX')", source)
        self.assertIn("final graphLocations=List<app.Location>.generate(11", source)
        self.assertIn("locations:graphLocations", source)
        self.assertIn("find.text('Craiova 01')", source)
        self.assertIn("find.text('Craiova 11')", source)
        self.assertIn("tester.takeException()", source)
        self.assertIn("await createGraphThroughUi();", source)
        self.assertIn("await pendingScheduleWrite!.timeout(const Duration(seconds:30));", source)
        self.assertIn("\'closed\':entry.closed", source)
        self.assertIn("find.text('Creează grafic')", source)
        self.assertIn("find.widgetWithText(CheckboxListTile,location.name)", source)
        self.assertIn("tester.enterText(search,'Craiova')", source)
        self.assertIn("controller.text,'Craiova'", source)
        self.assertIn("tile.hitTestable()", source)
        self.assertIn("pickerState.position.minScrollExtent", source)
        self.assertIn("Scrollable.ensureVisible(tester.element(tile),alignment:.5)", source)
        self.assertIn("Every selected location must remain visible in order", source)
        self.assertIn("height:MediaQuery.sizeOf(c).height*.58", program_page)
        self.assertIn("of:find.byType(CustomScrollView).last", source)
        self.assertIn("expect(tile,findsOneWidget", source)
        self.assertLess(source.index("await graphPage();"), source.index("await dashboard();"))

    def test_cumulative_candidate_keeps_native_gate_when_retargeted_to_main(self):
        workflow = (ROOT / '.github/workflows/xix-native-candidate.yml').read_text()
        native_job = workflow.split('  native:', 1)[1].split('    steps:', 1)[0]
        self.assertIn("github.head_ref == 'codex/xix-home-locality-label-20261021'", native_job)

    def test_release_test_apk_compiles_for_pull_request_validation(self):
        workflow = (ROOT / ".github/workflows/xix-native-candidate.yml").read_text()
        step = re.search(
            r"(?ms)^      - name: Compile release candidate without production signing or publication\n"
            r"        if: ([^\n]+)\n        run: \|\n(.*?)(?=^      - name:|\Z)",
            workflow,
        )
        self.assertIsNotNone(step, "release test APK build step must remain present")
        self.assertEqual(step.group(1), "github.event_name == 'pull_request'")
        self.assertIn("flutter build apk --release", step.group(2))
        self.assertIn("release-test-metadata.txt", step.group(2))
        self.assertIn("release-test-cert.txt", step.group(2))
        self.assertNotIn("operational-release-test.apk", step.group(2))
        self.assertNotRegex(step.group(2), r"cp\s+.+app-release\.apk\s+xix-evidence")

    def test_decont_pdf_e2e_reloads_the_expense_from_firestore(self):
        source = (ROOT / "integration_test/xix_native_test.dart").read_text()
        self.assertIn(".get(const GetOptions(source:Source.server))", source)
        self.assertIn("app.buildDecontPdfBytes(", source)
        self.assertIn("decontPdfBuiltFromServerExpense':true", source)
        validator = (ROOT / "scripts/verify_xix_decont_pdf_text.py").read_text()
        for marker in ("Decont E2E", "12345", "150.25 lei", "Bon fiscal"):
            self.assertIn(marker, validator)


if __name__ == "__main__":
    unittest.main()
