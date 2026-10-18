import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/admin_ui_fixture.dart';
import 'support/expense_document_fixture.dart';

String receipt(String total) => 'SC SYNTHETIC SRL\nBON FISCAL NR 12345\nDATA 05.10.2026\nTOTAL $total LEI';
void main() {
  late FirebasePlatform original;
  late NoFirebaseAccess firebase;
  setUp(() {
    original = FirebasePlatform.instance; firebase = NoFirebaseAccess();
    FirebasePlatform.instance = firebase;
  });
  tearDown(() { FirebasePlatform.instance = original; });
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    expect(firebase.attempts, isEmpty);
    expect(tester.takeException(), isNull);
  }

  for (final entry in <String, int>{'200': 20000, '200.00': 20000, '200,00': 20000, '1.234,56': 123, '1,234.56': 123}.entries) {
    testWidgets('${entry.value == 123 ? "KNOWN DEFECT grouping truncation: " : ""}OCR ${entry.key} traverses actual form Expense save and displayed evidence', (tester) async {
      final fixture = ExpenseDocumentFixture(receipt(entry.key));
      await fixture.mount(tester); await fixture.scan(tester);
      expect(fixture.pickerRequests, [false]); expect(fixture.recognizes, 1);
      expect(find.text('Verifică datele citite prin OCR'), findsOneWidget);
      final amount = tester.widget<TextField>(fixture.field('Sumă')).controller!;
      expect(amount.text, (entry.value / 100).toStringAsFixed(2));
      await fixture.submit(tester);
      expect(fixture.attempts.length, 1); expect(fixture.expenses.length, 1);
      final saved = fixture.attempts.single;
      expect((saved.amount * 100).round(), entry.value);
      expect(saved.teamId, 'team'); expect(saved.settlementId, 'settlement');
      expect(saved.documentNumber, '12345'); expect(saved.date, DateTime(2026, 10, 5));
      expect(saved.documentType, ExpenseDocumentType.fiscalReceipt);
      expect(saved.confirmed, isTrue);
      expect(saved.documentImageBase64, ''); expect(saved.ocrRawText, '');
      expect(saved.imageFingerprint, isNotEmpty);
      final evidence = find.text('Bon Fiscal nr 12345');
      await tester.ensureVisible(evidence); expect(evidence, findsOneWidget);
      expect(fixture.logs.where((l) => l.contains('introdus')).length, 1);
      await finish(tester);
      // For grouped text the existing regex captures 1.23. Green means
      // characterized, not financially correct; PR #29 owns that repair.
    });
  }

  testWidgets('fuel receipt retains BF number date liters unit price and exact amount', (tester) async {
    final fixture = ExpenseDocumentFixture('${receipt('200,00')}\nMOTORINA\n25,00 L\n8,00 LEI/L');
    await fixture.mount(tester); await fixture.scan(tester); await fixture.submit(tester);
    final saved = fixture.attempts.single;
    expect(saved.category, 'Combustibil'); expect(saved.documentNumber, '12345');
    expect(saved.date, DateTime(2026, 10, 5)); expect(saved.liters, 25); expect(saved.pricePerLiter, 8);
    expect((saved.amount * 100).round(), 20000);
    await finish(tester);
  });

  testWidgets('invoice ambiguity and manual override await save before success and pending evidence', (tester) async {
    final fixture = ExpenseDocumentFixture('SC SYNTHETIC SRL\nFACTURA NR 67890\nDATA 05.10.2026\nTOTAL 200 LEI\nTOTAL 250 LEI')..manager = false;
    fixture.saveGate = Completer<void>();
    await fixture.mount(tester); await fixture.scan(tester);
    expect(tester.widget<TextField>(fixture.field('Sumă')).controller!.text, '250.00'); // existing last-total selection
    await fixture.enter(tester, 'Sumă', '1.234,56');
    await fixture.submit(tester);
    expect(find.text('Introdu o sumă pozitivă, cu maximum 2 zecimale.'), findsOneWidget);
    expect(fixture.attempts, isEmpty);
    await fixture.enter(tester, 'Sumă', '200,21');
    await fixture.submit(tester);
    expect(fixture.attempts.length, 1); expect(fixture.expenses, isEmpty);
    expect(fixture.logs.where((l) => l.contains('introdus')), isEmpty);
    expect(find.text('Documentul a fost trimis gestionarului pentru confirmare.'), findsNothing);
    fixture.saveGate!.complete(); await tester.pumpAndSettle();
    final saved = fixture.expenses.single;
    expect((saved.amount * 100).round(), 20021); expect(saved.documentNumber, '67890');
    expect(saved.documentType, ExpenseDocumentType.invoice); expect(saved.date, DateTime(2026, 10, 5));
    expect(saved.confirmed, isFalse);
    expect(find.text('Documentul a fost trimis gestionarului pentru confirmare.'), findsOneWidget);
    final evidence = find.text('Factură nr 67890');
    await tester.ensureVisible(evidence); expect(evidence, findsOneWidget);
    expect(fixture.attempts.length, 1); expect(fixture.logs.where((l) => l.contains('introdus')).length, 1);
    await finish(tester);
  });

  testWidgets('cancel after OCR and edited form performs zero save or introduced log', (tester) async {
    final fixture = ExpenseDocumentFixture(receipt('200'));
    await fixture.mount(tester); await fixture.scan(tester);
    await fixture.enter(tester, 'Sumă', '300,25');
    await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
    expect(fixture.attempts, isEmpty); expect(fixture.expenses, isEmpty);
    expect(fixture.logs.where((l) => l.contains('introdus')), isEmpty);
    await finish(tester);
  });

  testWidgets('recognition failure allows manual form; save failure reports error with no evidence or retry', (tester) async {
    final fixture = ExpenseDocumentFixture('')..failRecognition = true..failSave = true;
    await fixture.mount(tester); await fixture.scan(tester);
    expect(find.text('Textul nu a putut fi extras. Completează manual.'), findsOneWidget);
    await fixture.enter(tester, 'Nr. bon', 'MANUAL123');
    await fixture.enter(tester, 'Sumă', '200.00');
    await fixture.submit(tester);
    expect(fixture.attempts.length, 1); expect(fixture.expenses, isEmpty);
    expect((fixture.attempts.single.amount * 100).round(), 20000);
    expect(fixture.logs.where((l) => l.contains('introdus')), isEmpty);
    expect(find.textContaining('Nu s-a putut salva documentul:'), findsOneWidget);
    expect(find.text('Documentul a fost salvat.'), findsNothing);
    await tester.pump(const Duration(seconds: 1)); expect(fixture.attempts.length, 1);
    await finish(tester);
  });

  testWidgets('image selection cancellation never invokes recognition form or save', (tester) async {
    final fixture = ExpenseDocumentFixture(receipt('200'))..imageCancelled = true;
    await fixture.mount(tester); await fixture.scan(tester);
    expect(fixture.recognizes, 0); expect(fixture.attempts, isEmpty); expect(fixture.logs, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    await finish(tester);
  });
}
