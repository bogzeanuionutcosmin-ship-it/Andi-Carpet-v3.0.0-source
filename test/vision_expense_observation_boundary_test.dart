import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/vision/vision_diagnostic_advisor.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:andi_carpeta/vision/vision_expense_save_verifier.dart';
import 'support/expense_document_fixture.dart';

int occurrences(String code) => VisionErrorTelemetry.log.entries.where(
  (e) => e.area == 'ocr' && e.code == code).fold(0, (n, e) => n + e.count);
const document = 'PRIVATE SUPPLIER\nBON FISCAL BF NR 12345\nDATA 05.10.2026\nTOTAL 209.17 LEI';

void main() {
  testWidgets('per-diem acknowledgement failure signals once and preserves rollback without retry', (tester) async {
    final before = VisionErrorTelemetry.log.entries.where((e) => e.area == 'per_diem' && e.code == 'acknowledge_failed').fold(0, (n, e) => n + e.count);
    var saves = 0;
    final entry = PerDiemEntry(id: 'pending', teamId: 'team', memberId: 'worker',
      date: DateTime(2026, 10, 5), settlementId: 'settlement', amount: 50,
      status: PerDiemStatus.awaitingConfirmation);
    final fixture = ExpenseDocumentFixture(document)..perDiems.add(entry)
      ..savePerDiemOverride = (_) async { saves++; throw StateError('PRIVATE amount 50'); };
    await fixture.mount(tester);
    final button = find.widgetWithText(OutlinedButton, 'Nu am primit').first;
    await tester.ensureVisible(button); await tester.tap(button); await tester.pumpAndSettle();
    expect(saves, 1); expect(entry.status, PerDiemStatus.awaitingConfirmation);
    expect(entry.received, isNull); expect(entry.actualReceivedAmount, isNull);
    final after = VisionErrorTelemetry.log.entries.where((e) => e.area == 'per_diem' && e.code == 'acknowledge_failed').fold(0, (n, e) => n + e.count);
    expect(after, before + 1); expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
    await tester.pump(const Duration(seconds: 1)); expect(saves, 1);
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });

  testWidgets('possible local mutation then exception yields prudent signal without retry or server claim', (tester) async {
    final before = occurrences('document_save_failed');
    final fixture = ExpenseDocumentFixture(document)..failSave = true..updateLocallyBeforeFailure = true;
    await fixture.mount(tester); await fixture.scan(tester); await fixture.submit(tester);
    expect(fixture.attempts, hasLength(1)); expect(fixture.expenses, hasLength(1));
    expect(occurrences('document_save_failed'), before + 1);
    final check = VisionExpenseSaveVerifier.evaluate(expectedBani: 20917,
      serverConfirmed: false, documentExists: true,
      savedBani: (fixture.expenses.single.amount * 100).round());
    expect(check.status, VisionExpenseSaveStatus.awaitingServerEvidence);
    expect(check.diagnosticCode, isNull);
    final isolated = VisionErrorLog()..record(area: 'ocr', code: 'document_save_failed', platform: 'android');
    final explanation = VisionDiagnosticAdvisor.assess(isolated).single;
    expect(explanation.explanation, contains('ar putea'));
    expect(explanation.explanation, contains('Verifică evidența'));
    expect(explanation.explanation, isNot(contains('PRIVATE')));
    expect(occurrences('saved_document_missing'), 0);
    expect(VisionErrorTelemetry.log.encode(), isNot(contains('209.17')));
    expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
    await tester.pump(const Duration(seconds: 1)); expect(fixture.attempts, hasLength(1));
    expect(fixture.logs.where((e) => e.contains('introdus')), isEmpty);
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });

  testWidgets('owner revoked during failed save suppresses only diagnostic observation', (tester) async {
    var owner = true; final before = occurrences('document_save_failed');
    final fixture = ExpenseDocumentFixture(document)..failSave = true
      ..saveGate = Completer<void>()..diagnosticSessionIsCurrent = () => owner;
    await fixture.mount(tester); await fixture.scan(tester); await fixture.submit(tester);
    expect(fixture.attempts, hasLength(1)); owner = false;
    fixture.saveGate!.complete(); await tester.pumpAndSettle();
    expect(occurrences('document_save_failed'), before);
    expect(fixture.expenses, isEmpty); expect(fixture.attempts, hasLength(1));
    // The diagnostic guard does not invent financial authorization or cancel
    // an operation already dispatched. Existing business feedback is kept.
    expect(find.textContaining('Nu s-a putut salva documentul:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });

  testWidgets('wrong parsed amount without exception emits no invented missing-document signal', (tester) async {
    final before = occurrences('document_save_failed');
    final fixture = ExpenseDocumentFixture(document.replaceAll('209.17', '1.234,56'));
    await fixture.mount(tester); await fixture.scan(tester); await fixture.submit(tester);
    expect(fixture.attempts, hasLength(1));
    expect((fixture.expenses.single.amount * 100).round(), 123); // Known parser defect remains.
    expect(occurrences('document_save_failed'), before);
    expect(occurrences('saved_document_missing'), 0);
    final result = VisionExpenseSaveVerifier.evaluate(expectedBani: 123456,
      serverConfirmed: false, documentExists: true, savedBani: 123);
    expect(result.status, VisionExpenseSaveStatus.awaitingServerEvidence);
    expect(result.diagnosticCode, isNull);
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });
}
