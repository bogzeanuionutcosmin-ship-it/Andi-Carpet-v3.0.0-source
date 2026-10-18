import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/settlement_edit_probe.dart';

Future<void> requestToggle(WidgetTester tester, bool wasClosed) async {
  final label = wasClosed ? 'Redeschide' : 'Închide decontul';
  await tester.ensureVisible(find.text(label)); await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  if (!wasClosed) {
    await tester.tap(find.widgetWithText(FilledButton, 'Închide')); await tester.pumpAndSettle();
  }
}

void main() {
  for (final wasClosed in [false, true]) {
    for (final hasEnd in [false, true]) {
      for (final rejected in [false, true]) {
        testWidgets('close=$wasClosed existing-end=$hasEnd definite-reject=$rejected', (tester) async {
          final gate = Completer<void>(); var saves = 0;
          final fixture = ExpenseDocumentFixture('');
          fixture.initialSettlementClosed = wasClosed;
          fixture.initialSettlementEnd = hasEnd ? DateTime(2026, 10, 9) : null;
          fixture.saveSettlementOverride = (_) async {
            saves++; await gate.future;
            if (rejected) throw FinanceSaveRejected('synthetic before-write rejection');
          };
          await fixture.mount(tester);
          final original = currentSettlement(tester); final before = settlementFields(original);
          await requestToggle(tester, wasClosed);
          expect(saves, 1); expect(fixture.logs, isEmpty); expect(original.closed, !wasClosed);
          final attempted = settlementFields(original);
          if (!wasClosed) expect(original.endDate, isNotNull);
          if (hasEnd) expect(original.endDate, before['endDate']);
          gate.complete(); await tester.pumpAndSettle();
          expect(settlementFields(original), rejected ? before : attempted);
          expect(saves, 1); expect(fixture.logs.length, rejected ? 0 : 1);
          expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  for (final exit in ['cancel', 'back', 'barrier']) {
    testWidgets('close $exit does not save or change dates', (tester) async {
      var saves = 0;
      final fixture = ExpenseDocumentFixture(''); fixture.saveSettlementOverride = (_) async { saves++; };
      await fixture.mount(tester);
      final original = currentSettlement(tester); final before = settlementFields(original);
      await tester.ensureVisible(find.text('Închide decontul')); await tester.tap(find.text('Închide decontul'));
      await tester.pumpAndSettle();
      if (exit == 'cancel') await tester.tap(find.text('Anulează'));
      if (exit == 'back') await tester.binding.handlePopRoute();
      if (exit == 'barrier') await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(settlementFields(original), before); expect(saves, 0); expect(fixture.logs, isEmpty);
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }
  for (final wasClosed in [false, true]) {
    testWidgets('duplicate close/reopen handler wasClosed=$wasClosed saves once', (tester) async {
      var saves = 0; final gate = Completer<void>();
      final fixture = ExpenseDocumentFixture(''); fixture.initialSettlementClosed = wasClosed;
      fixture.saveSettlementOverride = (_) async { saves++; await gate.future; };
      await fixture.mount(tester);
      final label = wasClosed ? 'Redeschide' : 'Închide decontul';
      await tester.ensureVisible(find.text(label));
      final outer = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label));
      outer.onPressed!(); outer.onPressed!(); await tester.pumpAndSettle();
      if (!wasClosed) {
        expect(find.byType(AlertDialog), findsOneWidget);
        final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Închide'));
        confirm.onPressed!(); confirm.onPressed!(); await tester.pumpAndSettle();
      }
      expect(saves, 1); expect(fixture.logs, isEmpty);
      gate.complete(); await tester.pumpAndSettle();
      expect(saves, 1); expect(fixture.logs, hasLength(1));
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('close definite failure can recover on a separate intentional action', (tester) async {
    var saves = 0; final fixture = ExpenseDocumentFixture('');
    fixture.saveSettlementOverride = (_) async { saves++; if (saves == 1) throw FinanceSaveRejected('before write'); };
    await fixture.mount(tester); final original = currentSettlement(tester);
    await requestToggle(tester, false); expect(original.closed, isFalse); expect(original.endDate, isNull);
    expect(saves, 1); expect(fixture.logs, isEmpty);
    await requestToggle(tester, false); expect(original.closed, isTrue); expect(original.endDate, isNotNull);
    expect(saves, 2); expect(fixture.logs, hasLength(1));
    expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });
  for (final mode in ['newer', 'revoked', 'committed-then-throws']) {
    testWidgets('close $mode does not erase newer data or rewrite server', (tester) async {
      final gate = Completer<void>(); var active = true; var saves = 0;
      Map<String, Object?>? durable;
      final fixture = ExpenseDocumentFixture(''); fixture.diagnosticSessionIsCurrent = () => active;
      fixture.saveSettlementOverride = (s) async {
        saves++; await gate.future;
        if (mode == 'newer') { s.closed = false; s.endDate = DateTime(2026, 11, 1); }
        if (mode == 'committed-then-throws') { durable = settlementFields(s); throw StateError('unclassified after commit'); }
        throw FinanceSaveRejected('before write');
      };
      await fixture.mount(tester); final original = currentSettlement(tester);
      await requestToggle(tester, false);
      final attempted = settlementFields(original);
      if (mode == 'revoked') active = false;
      gate.complete(); await tester.pumpAndSettle();
      if (mode == 'newer') { expect(original.closed, isFalse); expect(original.endDate, DateTime(2026, 11, 1)); }
      if (mode == 'revoked') expect(settlementFields(original), attempted);
      if (mode == 'committed-then-throws') {
        expect(durable, attempted); expect(original.closed, isFalse); expect(original.endDate, attempted['endDate']);
      }
      expect(saves, 1); expect(fixture.logs, isEmpty); expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
