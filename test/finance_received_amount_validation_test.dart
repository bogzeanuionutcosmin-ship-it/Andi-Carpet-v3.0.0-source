import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

void main() {
  for (final departure in [true, false]) {
    for (final raw in ['NaN', 'Infinity', '-Infinity', '1e999', 'invalid', '', '0', '-1']) {
      testWidgets('received amount $raw departure=$departure rejected with zero saves', (tester) async {
        var saves = 0;
        final fixture = ExpenseDocumentFixture('')..saveSettlementOverride = (_) async { saves++; };
        await fixture.mount(tester);
        final label = departure ? 'Primit la plecare' : 'Primit în timpul deplasării';
        await tester.ensureVisible(find.text(label)); await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await fixture.enter(tester, 'Valoare', raw);
        await fixture.enter(tester, 'De la cine', 'Synthetic payer');
        await tester.tap(find.text('Adaugă')); await tester.pumpAndSettle();
        expect(saves, 0); expect(fixture.logs, isEmpty);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
        expect(saves, 0); expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final raw in ['200', '200.00', '200,00', '0.01', '123.456']) {
    testWidgets('finite received amount $raw retains exact parser result once', (tester) async {
      final attempts = <TravelSettlement>[];
      final fixture = ExpenseDocumentFixture('')..saveSettlementOverride = (s) async { attempts.add(s); };
      await fixture.mount(tester);
      await tester.ensureVisible(find.text('Primit la plecare')); await tester.tap(find.text('Primit la plecare'));
      await tester.pumpAndSettle();
      await fixture.enter(tester, 'Valoare', raw);
      await fixture.enter(tester, 'De la cine', 'Synthetic payer');
      await tester.tap(find.text('Adaugă')); await tester.pumpAndSettle();
      expect(attempts, hasLength(1)); expect(fixture.logs, hasLength(1));
      expect(attempts.single.receivedEntries.single.amount, double.parse(raw.replaceAll(',', '.')));
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('finite amount still requires payer', (tester) async {
    var saves = 0;
    final fixture = ExpenseDocumentFixture('')..saveSettlementOverride = (_) async { saves++; };
    await fixture.mount(tester);
    await tester.ensureVisible(find.text('Primit la plecare')); await tester.tap(find.text('Primit la plecare'));
    await tester.pumpAndSettle(); await fixture.enter(tester, 'Valoare', '200');
    await tester.tap(find.text('Adaugă')); await tester.pumpAndSettle();
    expect(saves, 0); expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });
  for (final raw in ['NaN', 'Infinity', '-Infinity', '200,00']) {
    testWidgets('legacy finance receipt validation $raw uses correct save boundary', (tester) async {
      final attempts = <TeamFinance>[];
      final fixture = ExpenseDocumentFixture('')
        ..legacyFinance = true
        ..saveFinanceOverride = (f) async { attempts.add(f); };
      await fixture.mount(tester);
      await tester.ensureVisible(find.text('Primit la plecare')); await tester.tap(find.text('Primit la plecare'));
      await tester.pumpAndSettle();
      await fixture.enter(tester, 'Valoare', raw); await fixture.enter(tester, 'De la cine', 'Synthetic payer');
      await tester.tap(find.text('Adaugă')); await tester.pumpAndSettle();
      if (raw == '200,00') {
        expect(attempts, hasLength(1));
        expect(attempts.single.receivedEntries.single.amount, 200);
      } else {
        expect(attempts, isEmpty); expect(fixture.logs, isEmpty);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }

}
