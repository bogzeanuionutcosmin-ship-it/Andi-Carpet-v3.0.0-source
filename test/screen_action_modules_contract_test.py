"""Source contracts for unchanged screen actions; no production services invoked."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULES = {'lib/expenses/expense_settlement_actions.dart': ('_ExpensePageState', '_ExpenseSettlementActions', ['_settlementSelector', '_shortDate', '_createSettlement', '_editSettlement', '_toggleSettlementClosed', '_showGeneralCalculations', '_money']), 'lib/expenses/expense_per_diem_actions.dart': ('_ExpensePageState', '_ExpensePerDiemActions', ['_pendingPerDiemCard', '_confirmPerDiemAmount', '_answerPerDiem', '_manager', '_perDiemRate', '_saveFinance', '_respondToPerDiemDifference', '_resolvePerDiemDispute', '_perDiemDisputeActions', '_supplementaryPayment', '_distribute']), 'lib/expenses/expense_document_actions.dart': ('_ExpensePageState', '_ExpenseDocumentActions', ['_pickDocumentImage', '_compressDocumentImage', '_fingerprint', '_normalizedDocNo', '_duplicateOf', '_duplicateAllowed', '_manual', '_scan', '_expenseAmountBani', '_expenseDialog', '_saveNewExpense', '_groupedExpenses', '_showExpenseImage', '_confirmExpense', '_pdf']), 'lib/schedule/program_route_learning_actions.dart': ('_ProgramPageState', '_ProgramRouteLearningActions', ['_latestRecordForItem', '_averageDurationForLocation', '_pendingItemsForDay', '_estimatedEndForDay', '_planRiskReason', '_maybeRaisePlanAlert', '_locationById', '_currentAnchor', '_routeKmFrom', '_learningExecutionCount', '_lastOperationalLocationId', '_executionTransitionCounts', '_manualRoutingTransitionCounts', '_recordRoutingChoice', '_improveLearnedRoute', '_recalculateRemainingRoute', '_transferRemainingToNextDay']), 'lib/schedule/program_graph_actions.dart': ('_ProgramPageState', '_ProgramGraphActions', ['_newGraph', '_addLocations', '_cloneSchedule', '_saveWithFeedback', '_applyGraphState', '_geocodeTripPoint', '_startGraph', '_pauseGraph', '_resumeGraph', '_closeGraph', '_postponeGraph', '_removeItem', '_reorder', '_locationDialog', '_navigateToItem', '_openNavigation', '_openOmv', '_exportPdf', '_exportJpeg']), 'lib/map/map_verified_import_actions.dart': ('_MapPageState', '_MapVerifiedImportActions', ['_locationForVerifiedFix', '_showVerifiedImportPreview', '_applyVerifiedImport']), 'lib/map/map_location_actions.dart': ('_MapPageState', '_MapLocationActions', ['_copyLocation', '_validMapPoint', '_invalidMapPointNotice', '_chooseLocationAt', '_confirmAndPlace', '_placeLocation', '_details', '_adjustLocation', '_openNavigationForLocation', '_add', '_newLocationForm']), 'lib/dashboard/dashboard_work_actions.dart': ('_DashboardPageState', '_DashboardWorkActions', ['_copySchedule', '_dashboardGeocodeTripPoint', '_toggleProgram', '_startLocation', '_finishLocation', '_markWaiting', '_reasonDialog', '_markOutcome'])}


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


class ScreenActionContracts(unittest.TestCase):
    def test_methods_have_one_definition_and_parts_are_linked(self):
        main = source('lib/main.dart')
        for path, (state, extension, methods) in MODULES.items():
            with self.subTest(path=path):
                module = source(path)
                self.assertTrue(module.startswith("part of '../main.dart';"))
                self.assertEqual(main.count(f"part '{path[4:]}';"), 1)
                self.assertIn(f'extension {extension} on {state} {{', module)
                # Scoped to each State: identical private names in other States are valid.
                page_name = {'_ExpensePageState': 'expense_page.dart', '_ProgramPageState': 'program_page.dart', '_MapPageState': 'map_page.dart', '_DashboardPageState': 'dashboard_page.dart'}[state]
                page = ROOT / Path(path).parent / page_name
                scope = page.read_text() + '\n'.join(source(p) for p, spec in MODULES.items() if spec[0] == state)
                self.assertIn('Widget build(BuildContext context)', page.read_text())
                self.assertNotIn('@override', module)
                for method in methods:
                    signature = rf'^  (?:Future<[^\n]+?>|List<[^\n]+?>|Map<[^\n]+?>|String|int|double|bool|void|Widget|Location|Expense|WorkSchedule|CentralizerRecord|Duration|DateTime|Uint8List)\?? {method}\('
                    self.assertEqual(len(re.findall(signature, module, re.M)), 1, method)
                    self.assertEqual(len(re.findall(signature, scope, re.M)), 1, method)
                    self.assertFalse(re.search(signature, page.read_text(), re.M), method)

    def test_per_diem_beneficiary_rollback_and_disputes_preserved(self):
        module = source('lib/expenses/expense_per_diem_actions.dart')
        for item in ('entry.memberId != widget.currentUser.id',
                     'entry.status != PerDiemStatus.awaitingConfirmation', '_savingPerDiemIds.contains(entry.id)',
                     'entry.actualReceivedAmount = amountReceived == 0 ? null : amountReceived;',
                     'entry.received = previousReceived;', 'entry.status = previousStatus;',
                     'entry.actualReceivedAmount = previousAmount;', '_savingPerDiemIds.remove(entry.id);',
                     "collection('perDiemDisputes').doc(entry.id)", 'if (!widget.isAdmin) return;',
                     "snap.data()?['status'] != 'disputed'", 'if (beneficiary == managerId)',
                     'parsePerDiemBani(amount.text, allowZero: false)'):
            self.assertIn(item, module)
        self.assertEqual(module.count('FirebaseFirestore.instance.runTransaction('), 2)

    def test_ocr_deduplication_and_save_order_preserved(self):
        module = source('lib/expenses/expense_document_actions.dart')
        for item in ('e.teamId != candidate.teamId', "(e.settlementId ?? '') == (candidate.settlementId ?? '')",
                     'e.imageFingerprint == candidate.imageFingerprint', 'sameDay(candidate.date, e.date)',
                     'LearningMode.automatic', 'recognizeTextFromImage(raw, path: picked.path)',
                     'parseFiscalOcr(text)', "const photoBase64 = '';", "ocrRawText: ''",
                     'final value = bani / 100.0;', 'formKey.currentState?.validate()',
                     'if (!await _duplicateAllowed(e)) return;', 'await widget.saveExpense(e);'):
            self.assertIn(item, module)
        save = module.split('  Future<void> _saveNewExpense(Expense e)', 1)[1]
        self.assertLess(save.index('await _duplicateAllowed(e)'), save.index('await widget.saveExpense(e)'))

    def test_general_totals_keep_confirmed_receipts_and_transfer_deduplication(self):
        module = source('lib/expenses/expense_settlement_actions.dart')
        for item in ('expenseIds.add(e.id)', 'paymentIds.add(d.id)', 'd.received==true',
                     'd.actualReceivedAmount!.isFinite', 'dateOk(d.confirmedAt??d.date)',
                     'seenTransferIds.add(transfer.id)', 'else if(allTime)',
                     'await widget.saveSettlement(result);', 'await widget.saveFinance(finance);',
                     'value: _ExpensePageState._legacySettlementKey'):
            self.assertIn(item, module)

    def test_program_route_protects_active_items_and_incomplete_gps(self):
        module = source('lib/schedule/program_route_learning_actions.dart')
        for item in ('includeActive: false', 'WorkAttemptStatus.running', 'WorkAttemptStatus.waitingAccess',
                     'difference(day.planAlertAt!).inMinutes < 60',
                     'difference(updated.lastRecalculatedAt!).inMinutes >= 30',
                     'if (withoutGps.isNotEmpty)', '_learningExecutionCount(i.locationId) < 3',
                     'List.generate(movable.length', 'await widget.saveSchedule(current);',
                     'await widget.saveSchedule(next);'):
            self.assertIn(item, module)
        transfer = module.split('  Future<void> _transferRemainingToNextDay', 1)[1]
        self.assertLess(transfer.index('await widget.saveSchedule(current);'), transfer.index('await widget.saveSchedule(next);'))

    def test_map_import_and_marker_validation_preserved(self):
        module = source('lib/map/map_verified_import_actions.dart')
        for item in ('if (!widget.isAdmin || saving) return;',
                     '(l.latitude == null || l.longitude == null) && fix.hasGps',
                     'if (touched > 0) await batch.commit();', 'SetOptions(merge:true)'):
            self.assertIn(item, module)
        placement = source('lib/map/map_location_actions.dart')
        for item in ('point.latitude.isFinite && point.longitude.isFinite',
                     'point.latitude >= -90 && point.latitude <= 90',
                     'if (!widget.isAdmin || saving || !_validMapPoint(point))',
                     'if (replace != true) return;', 'await widget.saveLocation(updated);'):
            self.assertIn(item, placement)

    def test_dashboard_manual_finish_requires_confirmation_and_keeps_undo(self):
        module = source('lib/dashboard/dashboard_work_actions.dart')
        for item in ('if (facadeDone == null) return;', 'barrierDismissible: false',
                     'status: WorkAttemptStatus.completed', 'widget.settings.allowUndo',
                     'await widget.saveRecord(source);', 'if (value.isEmpty) return;',
                     'refusalReason: reason', 'await widget.saveRecord(r);'):
            self.assertIn(item, module)
        finish = module.split('  Future<void> _finishLocation', 1)[1].split('  Future<void> _markWaiting', 1)[0]
        self.assertLess(finish.index('if (facadeDone == null) return;'), finish.index('await widget.saveRecord(r);'))
