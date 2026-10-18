import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/ui/money_card.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

dynamic receiptTarget(WidgetTester tester, bool legacy) {
  final page = tester.widget<ExpensePage>(find.byType(ExpensePage));
  return legacy ? page.finances.single : page.settlements.single;
}
Map<String, Object?> receiptFields(dynamic target) => {
  'departure': target.receivedDeparture, 'during': target.receivedDuring,
  'manager': target.managerId, 'rate': target.perDiemRate,
  'entries': [for (final ReceivedMoneyEntry e in target.receivedEntries)
    {'id': e.id, 'kind': e.kind, 'amount': e.amount, 'method': e.method, 'from': e.fromName, 'date': e.date}],
};
ReceivedMoneyEntry oldEntry(String id, String kind, double amount) => ReceivedMoneyEntry(
  id: id, kind: kind, amount: amount, method: 'Cash', fromName: 'Synthetic historical payer', date: DateTime(2026, 10, 1),
);
void seed(dynamic target) {
  target.receivedEntries.addAll([oldEntry('old-departure', 'departure', 25), oldEntry('old-during', 'during', 10)]);
  target.receivedDeparture = 25.0; target.receivedDuring = 10.0;
}
Future<void> openReceipt(WidgetTester tester, ExpenseDocumentFixture fixture, bool departure) async {
  final label = departure ? 'Primit la plecare' : 'Primit în timpul deplasării';
  await tester.ensureVisible(find.text(label)); await tester.tap(find.text(label)); await tester.pumpAndSettle();
  await fixture.enter(tester, 'Valoare', '200,00'); await fixture.enter(tester, 'De la cine', 'Synthetic payer');
}
Future<void> confirmReceipt(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Adaugă')); await tester.pumpAndSettle();
}
int eventCount() => VisionErrorTelemetry.log.entries.where((e) => e.area == 'finance' && e.code == 'received_amount_save_failed').fold(0, (n, e) => n + e.count);

void main() {
  for (final legacy in [false, true]) {
    for (final departure in [false, true]) {
      for (final outcome in ['success', 'definite', 'generic', 'committed-then-throws']) {
        testWidgets('receipt legacy=$legacy departure=$departure $outcome retains financial evidence', (tester) async {
          final gate = Completer<void>(); var saves = 0; late dynamic target;
          Map<String, Object?>? durable;
          Future<void> save(dynamic value) async {
            expect(identical(value, target), isTrue); saves++; await gate.future;
            if (outcome == 'success') return;
            if (outcome == 'committed-then-throws') durable = receiptFields(value);
            if (outcome == 'definite') throw FinanceSaveRejected('synthetic before-write rejection');
            throw StateError('PRIVATE unclassified failure');
          }
          final fixture = ExpenseDocumentFixture(''); fixture.legacyFinance = legacy;
          fixture.saveSettlementOverride = (s) => save(s); fixture.saveFinanceOverride = (f) => save(f);
          await fixture.mount(tester); target = receiptTarget(tester, legacy); seed(target);
          final before = receiptFields(target); final events = eventCount();
          await openReceipt(tester, fixture, departure);
          expect(receiptFields(target), before); expect(saves, 0);
          await confirmReceipt(tester);
          expect(saves, 1); expect(fixture.logs, isEmpty);
          expect(target.receivedEntries, hasLength(3));
          expect(target.receivedDeparture, departure ? 225.0 : 25.0);
          expect(target.receivedDuring, departure ? 10.0 : 210.0);
          final attempted = receiptFields(target);
          gate.complete(); await tester.pumpAndSettle();
          expect(receiptFields(target), outcome == 'definite' ? before : attempted);
          if (outcome == 'committed-then-throws') expect(durable, attempted);
          expect(eventCount(), events + (outcome == 'success' ? 0 : 1));
          expect(fixture.logs.length, outcome == 'success' ? 1 : 0);
          expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
          expect(saves, 1); expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('legacy aggregate-only values survive definite receipt rejection unchanged', (tester) async {
    var saves = 0; final fixture = ExpenseDocumentFixture(''); fixture.legacyFinance = true;
    fixture.saveFinanceOverride = (_) async { saves++; throw FinanceSaveRejected('before write'); };
    await fixture.mount(tester); final target = receiptTarget(tester, true); final before = receiptFields(target);
    expect(target.receivedEntries, isEmpty); expect(target.receivedDeparture, 1);
    await openReceipt(tester, fixture, true); await confirmReceipt(tester);
    expect(receiptFields(target), before); expect(saves, 1); expect(fixture.logs, isEmpty);
    expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });
  for (final legacy in [false, true]) {
    for (final mode in ['newer', 'revoked']) {
      testWidgets('receipt legacy=$legacy $mode does not restore stale snapshot', (tester) async {
        final gate = Completer<void>(); var active = true; var saves = 0; late dynamic target;
        Future<void> save(dynamic value) async {
          saves++; await gate.future;
          if (mode == 'newer') {
            value.receivedEntries..clear()..add(oldEntry('server-newer', 'departure', 500));
            value.receivedDeparture = 500.0; value.receivedDuring = 0.0;
          }
          throw FinanceSaveRejected('before write');
        }
        final fixture = ExpenseDocumentFixture(''); fixture.legacyFinance = legacy;
        fixture.diagnosticSessionIsCurrent = () => active;
        fixture.saveSettlementOverride = (s) => save(s); fixture.saveFinanceOverride = (f) => save(f);
        await fixture.mount(tester); target = receiptTarget(tester, legacy); seed(target);
        final events = eventCount(); await openReceipt(tester, fixture, true); await confirmReceipt(tester);
        final attempted = receiptFields(target);
        if (mode == 'revoked') active = false;
        gate.complete(); await tester.pumpAndSettle();
        if (mode == 'revoked') { expect(receiptFields(target), attempted); expect(eventCount(), events); }
        if (mode == 'newer') {
          expect(target.receivedEntries, hasLength(1)); expect(target.receivedEntries.single.id, 'server-newer');
          expect(target.receivedDeparture, 500); expect(target.receivedDuring, 0);
        }
        expect(saves, 1); expect(fixture.logs, isEmpty); expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets('duplicate departure/during entrypoints legacy=$legacy cannot create two writes', (tester) async {
      var saves = 0; final gate = Completer<void>();
      final fixture = ExpenseDocumentFixture(''); fixture.legacyFinance = legacy;
      fixture.saveSettlementOverride = (_) async { saves++; await gate.future; };
      fixture.saveFinanceOverride = (_) async { saves++; await gate.future; };
      await fixture.mount(tester);
      final departure = tester.widget<MoneyCard>(find.widgetWithText(MoneyCard, 'Primit la plecare'));
      final during = tester.widget<MoneyCard>(find.widgetWithText(MoneyCard, 'Primit în timpul deplasării'));
      departure.onTap!(); during.onTap!(); await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await fixture.enter(tester, 'Valoare', '200'); await fixture.enter(tester, 'De la cine', 'Synthetic payer');
      final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Adaugă'));
      confirm.onPressed!(); confirm.onPressed!(); await tester.pumpAndSettle();
      expect(saves, 1); gate.complete(); await tester.pumpAndSettle();
      expect(saves, 1); expect(fixture.logs, hasLength(1));
      expect(receiptTarget(tester, legacy).receivedEntries, hasLength(1));
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('definite receipt rejection releases pending key for an intentional recovery', (tester) async {
    var saves = 0; final fixture = ExpenseDocumentFixture('');
    fixture.saveSettlementOverride = (_) async { saves++; if (saves == 1) throw FinanceSaveRejected('before write'); };
    await fixture.mount(tester); final target = receiptTarget(tester, false); final before = receiptFields(target);
    await openReceipt(tester, fixture, true); await confirmReceipt(tester);
    expect(receiptFields(target), before); expect(saves, 1); expect(fixture.logs, isEmpty);
    await openReceipt(tester, fixture, false); await confirmReceipt(tester);
    expect(saves, 2); expect(fixture.logs, hasLength(1)); expect(target.receivedEntries, hasLength(1));
    expect(target.receivedDuring, 200); expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });
  for (final returnToA in [false, true]) {
    testWidgets('pending receipt A cannot block successor A-B-A2=$returnToA', (tester) async {
      final oldGate = Completer<void>(); final newGate = Completer<void>(); var oldSaves = 0; var newSaves = 0;
      final first = ExpenseDocumentFixture('', userId: 'A');
      first.saveSettlementOverride = (_) async { oldSaves++; await oldGate.future; throw FinanceSaveRejected('old before write'); };
      await first.mount(tester); final state = tester.state(find.byType(ExpensePage));
      await openReceipt(tester, first, true); await confirmReceipt(tester);
      final second = ExpenseDocumentFixture('', userId: 'B'); await second.mount(tester);
      final third = ExpenseDocumentFixture('', userId: 'A');
      final successor = returnToA ? third : second;
      successor.saveSettlementOverride = (_) async { newSaves++; await newGate.future; };
      if (returnToA) { await third.mount(tester); } else { await second.mount(tester); }
      expect(identical(tester.state(find.byType(ExpensePage)), state), isTrue);
      await openReceipt(tester, successor, false); await confirmReceipt(tester);
      expect(oldSaves, 1); expect(newSaves, 1);
      final events = eventCount(); oldGate.complete(); await tester.pumpAndSettle();
      expect(eventCount(), events); expect(successor.logs, isEmpty); expect(first.logs, isEmpty);
      newGate.complete(); await tester.pumpAndSettle();
      expect(successor.logs, hasLength(1)); expect(oldSaves, 1); expect(newSaves, 1);
      expect(receiptTarget(tester, false).receivedDuring, 200);
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }
  for (final exit in ['cancel', 'back', 'barrier']) {
    testWidgets('receipt $exit releases key without mutation or save', (tester) async {
      var saves = 0; final fixture = ExpenseDocumentFixture('');
      fixture.saveSettlementOverride = (_) async { saves++; };
      await fixture.mount(tester); final target = receiptTarget(tester, false); final before = receiptFields(target);
      await openReceipt(tester, fixture, true);
      if (exit == 'cancel') await tester.tap(find.text('Anulează'));
      if (exit == 'back') await tester.binding.handlePopRoute();
      if (exit == 'barrier') await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle(); expect(receiptFields(target), before); expect(saves, 0); expect(fixture.logs, isEmpty);
      await openReceipt(tester, fixture, false); await confirmReceipt(tester);
      expect(saves, 1); expect(fixture.logs, hasLength(1)); expect(target.receivedDuring, 200);
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }

}
