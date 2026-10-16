// KNOWN RED: pre-existing financial dialog lifecycle defect; NOT a Vision acceptance.
// Run explicitly in CI; assertions preserved from lot6, no runtime fix authorized.
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
  testWidgets('settlement receipt failure is observed without a second save or value in journal', (tester) async {
    final before = VisionErrorTelemetry.log.entries.where((e) => e.area == 'finance' && e.code == 'received_amount_save_failed').fold(0, (n, e) => n + e.count);
    var saves = 0;
    final fixture = ExpenseDocumentFixture(document)
      ..saveSettlementOverride = (_) async { saves++; throw StateError('PRIVATE 321.09 supplier'); };
    await fixture.mount(tester);
    await tester.ensureVisible(find.text('Primit la plecare')); await tester.tap(find.text('Primit la plecare'));
    await tester.pumpAndSettle();
    await fixture.enter(tester, 'Valoare', '321.09'); await fixture.enter(tester, 'De la cine', 'PRIVATE supplier');
    await tester.tap(find.widgetWithText(FilledButton, 'Adaugă')); await tester.pumpAndSettle();
    expect(saves, 1);
    final after = VisionErrorTelemetry.log.entries.where((e) => e.area == 'finance' && e.code == 'received_amount_save_failed').fold(0, (n, e) => n + e.count);
    expect(after, before + 1); expect(VisionErrorTelemetry.log.encode(), isNot(contains('321.09')));
    expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
    await tester.pump(const Duration(seconds: 1)); expect(saves, 1);
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });

}
