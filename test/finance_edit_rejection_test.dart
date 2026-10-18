import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/settlement_edit_probe.dart';

void main() {
  test('definite rejection is explicit and preserves StateError compatibility', () {
    final error = FinanceSaveRejected('synthetic before-write denial');
    expect(error, isA<StateError>());
    expect(error.toString(), contains('synthetic before-write denial'));
    expect(StateError('unclassified'), isNot(isA<FinanceSaveRejected>()));
    expect(TimeoutException('unclassified'), isNot(isA<FinanceSaveRejected>()));
  });

  for (final mode in ['definite', 'generic', 'committed-then-throws', 'newer-observation', 'revoked']) {
    testWidgets('edit $mode preserves its outcome boundary with one save', (tester) async {
      final gate = Completer<void>();
      var active = true;
      var saves = 0;
      Map<String, Object?>? durable;
      final fixture = ExpenseDocumentFixture('');
      fixture.diagnosticSessionIsCurrent = () => active;
      fixture.saveSettlementOverride = (s) async {
        saves++;
        await gate.future;
        if (mode == 'committed-then-throws') durable = settlementFields(s);
        if (mode == 'newer-observation') {
          s.name = 'Synthetic newer revision';
          s.startDate = DateTime(2026, 9, 2);
          s.endDate = DateTime(2026, 10, 11);
          s.closed = true;
        }
        if (mode == 'generic' || mode == 'committed-then-throws') throw StateError('unclassified failure');
        throw FinanceSaveRejected('synthetic rejected before write');
      };
      await fixture.mount(tester);
      final original = currentSettlement(tester)..endDate = DateTime(2026, 10, 9);
      final before = settlementFields(original);
      await submitSyntheticEdit(tester, fixture);
      expect(saves, 1); expect(fixture.logs, isEmpty);
      expect(original.name, 'Synthetic revised trip'); expect(original.endDate, isNull);
      final attempted = settlementFields(original);
      if (mode == 'revoked') active = false;
      gate.complete(); await tester.pumpAndSettle();
      expect(saves, 1); expect(fixture.logs, isEmpty);
      if (mode == 'definite') {
        expect(settlementFields(original), before);
      } else if (mode == 'newer-observation') {
        expect(original.name, 'Synthetic newer revision');
        expect(original.startDate, DateTime(2026, 9, 2));
        expect(original.endDate, DateTime(2026, 10, 11)); expect(original.closed, isTrue);
      } else {
        // An unclassified failure is deliberately NOT converted to no-write.
        expect(settlementFields(original), attempted);
        if (mode == 'committed-then-throws') expect(durable, attempted);
      }
      if (mode == 'revoked') expect(find.textContaining('Nu s-a putut salva:'), findsNothing);
      await tester.pump(const Duration(seconds: 1)); expect(saves, 1);
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('definite rejection restores a changed start date and existing closed state', (tester) async {
    final gate = Completer<void>();
    var saves = 0;
    final fixture = ExpenseDocumentFixture('');
    fixture.saveSettlementOverride = (_) async { saves++; await gate.future; throw FinanceSaveRejected('before write'); };
    await fixture.mount(tester);
    final original = currentSettlement(tester)..endDate = DateTime(2026, 10, 9)..closed = true;
    final before = settlementFields(original);
    await tester.ensureVisible(find.text('Editează deplasarea')); await tester.tap(find.text('Editează deplasarea'));
    await tester.pumpAndSettle();
    await fixture.enter(tester, 'Denumire', 'Synthetic changed dates');
    await tester.tap(find.text('Alege').first); await tester.pumpAndSettle();
    await tester.tap(find.text('7')); await tester.tap(find.text('OK')); await tester.pumpAndSettle();
    await tester.tap(find.text('Salvează')); await tester.pumpAndSettle();
    expect(saves, 1); expect(original.startDate, DateTime(2026, 10, 7));
    gate.complete(); await tester.pumpAndSettle();
    expect(settlementFields(original), before); expect(fixture.logs, isEmpty); expect(saves, 1);
    expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });
}
