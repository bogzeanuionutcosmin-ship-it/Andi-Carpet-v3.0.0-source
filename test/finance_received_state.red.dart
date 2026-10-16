// VII-06: distinguishes local receipt integrity from repaired controller lifetime.
// Strict synthetic rejection; no assertion about whether a real server committed.
import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

void main() {
  testWidgets('rejected receipt save must preserve confirmed local receipt totals', (tester) async {
    final gate = Completer<void>();
    var attempts = 0;
    final fixture = ExpenseDocumentFixture('')..saveSettlementOverride = (_) async {
      attempts++; await gate.future; throw FinanceSaveRejected('synthetic rejection before persistence');
    };
    await fixture.mount(tester);
    final original = tester.widget<ExpensePage>(find.byType(ExpensePage)).settlements.single;
    final before = [original.receivedEntries.length, original.receivedDeparture, original.receivedDuring];
    await tester.ensureVisible(find.text('Primit la plecare')); await tester.tap(find.text('Primit la plecare'));
    await tester.pumpAndSettle();
    await fixture.enter(tester, 'Valoare', '200'); await fixture.enter(tester, 'De la cine', 'Synthetic payer');
    expect([original.receivedEntries.length, original.receivedDeparture, original.receivedDuring], before);
    await tester.tap(find.text('Adaugă')); await tester.pumpAndSettle();
    expect(attempts, 1); expect(fixture.logs, isEmpty);
    gate.complete(); await tester.pumpAndSettle();
    expect(attempts, 1); expect(fixture.logs, isEmpty); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugPrint('RECEIPT_REJECTION_PRECONDITIONS_PASS');
    expect([original.receivedEntries.length, original.receivedDeparture, original.receivedDuring], before,
      reason: 'RECEIPT_CONFIRMED_LOCAL_STATE_NOT_PRESERVED');
  });
}
