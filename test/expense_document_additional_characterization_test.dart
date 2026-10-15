import 'dart:typed_data';
import 'package:andi_carpeta/main.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'support/admin_ui_fixture.dart';
import 'support/expense_document_fixture.dart';

String document(String tail) => 'SC SYNTHETIC SRL\nBON FISCAL NR 12345\nDATA 05.10.2026\n$tail';
void main() {
  late FirebasePlatform original;
  late NoFirebaseAccess sdk;
  setUp(() { original = FirebasePlatform.instance; sdk = NoFirebaseAccess(); FirebasePlatform.instance = sdk; });
  tearDown(() { expect(sdk.attempts, isEmpty); FirebasePlatform.instance = original; });
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox()); expect(t.takeException(), isNull);
  }
  final cases = <({String label, String raw, int bani, bool defect})>[
    (label: 'space grouping', raw: document('TOTAL 1 234,56 LEI'), bani: 100, defect: true),
    (label: 'compact decimal comma', raw: document('TOTAL 1234,56 LEI'), bani: 123456, defect: false),
    (label: 'three digits after dot', raw: document('TOTAL 1.234 LEI'), bani: 123, defect: true),
    (label: 'subtotal after total', raw: document('TOTAL 238.00 LEI\nSUBTOTAL 200.00 LEI'), bani: 20000, defect: true),
    (label: 'TVA total after total', raw: document('TOTAL 238.00 LEI\nTOTAL TVA 38.00 LEI'), bani: 3800, defect: true),
  ];
  for (final c in cases) {
    testWidgets('${c.defect ? "KNOWN DEFECT: " : ""}${c.label} through real form and save boundary', (t) async {
      final h = ExpenseDocumentFixture(c.raw); await h.mount(t); await h.scan(t);
      expect(t.widget<TextField>(h.field('Sumă')).controller!.text, (c.bani / 100).toStringAsFixed(2));
      await h.submit(t); expect(h.attempts, hasLength(1)); expect(h.expenses, hasLength(1));
      expect((h.attempts.single.amount * 100).round(), c.bani);
      expect(h.attempts.single.documentNumber, '12345'); expect(h.attempts.single.date, DateTime(2026, 10, 5));
      expect(h.attempts.single.teamId, 'team'); expect(h.attempts.single.settlementId, 'settlement');
      expect(h.attempts.single.ocrRawText, ''); expect(h.attempts.single.documentImageBase64, '');
      await finish(t);
    });
  }

  testWidgets('KNOWN DEFECT: text containing two receipts combines first number/date with last total', (t) async {
    final h = ExpenseDocumentFixture('SC SYNTHETIC SRL\nBON FISCAL NR 11111\nDATA 05.10.2026\nTOTAL 200 LEI\nBON FISCAL NR 22222\nDATA 06.10.2026\nTOTAL 250 LEI');
    await h.mount(t); await h.scan(t); await h.submit(t);
    expect(h.attempts, hasLength(1)); final saved = h.attempts.single;
    expect(saved.documentNumber, '11111'); expect(saved.date, DateTime(2026, 10, 5));
    expect((saved.amount * 100).round(), 25000); expect(h.expenses, hasLength(1)); await finish(t);
  });

  testWidgets('fuel quantity prefill rounds three decimals but manual quantity override preserves input and exact total', (t) async {
    final h = ExpenseDocumentFixture(document('MOTORINA\n2,345 L\n8,531 LEI/L\nTOTAL 20,00 LEI'));
    await h.mount(t); await h.scan(t);
    expect(t.widget<TextField>(h.field('Litri')).controller!.text, '2.35');
    expect(t.widget<TextField>(h.field('Preț / litru')).controller!.text, '8.53');
    await h.enter(t, 'Litri', '2,345'); await h.enter(t, 'Preț / litru', '8,531'); await h.submit(t);
    final saved = h.attempts.single;
    expect(saved.liters, 2.345); expect(saved.pricePerLiter, 8.531);
    expect(saved.category, 'Combustibil'); expect((saved.amount * 100).round(), 2000); await finish(t);
  });

  testWidgets('two consecutive invoices use separate images and IDs without replacing the first expense', (t) async {
    final h = ExpenseDocumentFixture('SC SYNTHETIC SRL\nFACTURA NR 70001\nDATA 05.10.2026\nTOTAL 21.35 LEI');
    await h.mount(t); await h.scan(t); await h.submit(t);
    h.text = 'SC SYNTHETIC SRL\nFACTURA NR 70002\nDATA 06.10.2026\nTOTAL 31.47 LEI';
    final second = img.Image(width: 2, height: 2)..setPixelRgba(0, 0, 1, 2, 3, 255);
    h.imageOverride = Uint8List.fromList(img.encodePng(second));
    await h.scan(t); await h.submit(t);
    expect(h.attempts, hasLength(2)); expect(h.expenses, hasLength(2));
    expect(h.expenses.map((e) => e.documentNumber), ['70001', '70002']);
    expect(h.expenses.map((e) => (e.amount * 100).round()), [2135, 3147]);
    expect(h.expenses.map((e) => e.documentType), everyElement(ExpenseDocumentType.invoice));
    expect(h.expenses[0].id, isNot(h.expenses[1].id));
    expect(h.expenses[0].imageFingerprint, isNot(h.expenses[1].imageFingerprint));
    expect(h.logs.where((l) => l.contains('introdus')), hasLength(2)); await finish(t);
  });

  testWidgets('KNOWN DEFECT: callback updates local list then throws, leaving visible evidence without success log or retry', (t) async {
    final h = ExpenseDocumentFixture(document('TOTAL 209.17 LEI'))..failSave = true..updateLocallyBeforeFailure = true;
    await h.mount(t); await h.scan(t); await h.submit(t);
    expect(h.attempts, hasLength(1)); expect(h.expenses, hasLength(1));
    expect((h.expenses.single.amount * 100).round(), 20917);
    expect(find.textContaining('Nu s-a putut salva documentul:'), findsOneWidget);
    expect(h.logs.where((l) => l.contains('introdus')), isEmpty);
    final evidence = find.text('Bon Fiscal nr 12345'); await t.ensureVisible(evidence); expect(evidence, findsOneWidget);
    await t.pump(const Duration(seconds: 1)); expect(h.attempts, hasLength(1)); await finish(t);
    // This fake models an optimistic local mutation, not authoritative server evidence.
  });

  testWidgets('manual form Back discards inputs; reopened form saves exactly once without OCR or image fingerprint', (t) async {
    final h = ExpenseDocumentFixture('')..imageCancelled = true;
    await h.mount(t);
    Future<void> open() async {
      final b = find.widgetWithText(OutlinedButton, 'Introducere manuală');
      await t.ensureVisible(b); await t.tap(b); await t.pumpAndSettle();
    }
    await open(); await h.enter(t, 'Nr. bon', 'MANUALOLD'); await h.enter(t, 'Sumă', '100.11');
    await t.binding.handlePopRoute(); await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing); expect(h.attempts, isEmpty);
    await open(); expect(t.widget<TextField>(h.field('Nr. bon')).controller!.text, '');
    await h.enter(t, 'Nr. bon', 'MANUALNEW'); await h.enter(t, 'Sumă', '200,21'); await h.submit(t);
    expect(h.recognizes, 0); expect(h.pickerRequests, [true, true]);
    expect(h.attempts, hasLength(1)); expect(h.expenses, hasLength(1));
    final saved = h.attempts.single; expect(saved.documentNumber, 'MANUALNEW');
    expect((saved.amount * 100).round(), 20021); expect(saved.imageFingerprint, ''); expect(saved.ocrRawText, ''); await finish(t);
  });
}
