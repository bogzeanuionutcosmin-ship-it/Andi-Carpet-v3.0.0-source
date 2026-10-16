import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

// A stale completion must not mutate a shared model observed by the successor.
// Keep current-session unknown-result behavior out of this session-only fix.
void main() {
  for (final transition in ['revoked', 'unmounted', 'A-B', 'A-B-A2']) {
    for (final timeout in [false, true]) {
      testWidgets('stale close $transition timeout=$timeout cannot mutate shared observation', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gate = Completer<void>(); var active = true; var saves = 0;
        final shared = TravelSettlement(id: 'settlement', teamId: 'team',
          name: 'Synthetic shared trip', startDate: DateTime(2026, 10, 1), managerId: 'A');
        final first = ExpenseDocumentFixture('', userId: 'A');
        first.settlementOverride = shared; first.diagnosticSessionIsCurrent = () => active;
        first.saveSettlementOverride = (_) async {
          saves++; await gate.future;
          if (timeout) throw TimeoutException('PRIVATE_OLD_CLOSE');
          throw StateError('PRIVATE_OLD_CLOSE');
        };
        await first.mount(tester); final state = tester.state(find.byType(ExpensePage));
        await tester.ensureVisible(find.text('Închide decontul')); await tester.tap(find.text('Închide decontul'));
        await tester.pumpAndSettle(); await tester.tap(find.widgetWithText(FilledButton, 'Închide'));
        await tester.pumpAndSettle(); expect(saves, 1); expect(shared.closed, true);
        if (transition == 'revoked') active = false;
        if (transition == 'unmounted') await tester.pumpWidget(const SizedBox());
        final second = ExpenseDocumentFixture('', userId: 'B'); second.settlementOverride = shared;
        final third = ExpenseDocumentFixture('', userId: 'A'); third.settlementOverride = shared;
        if (transition.startsWith('A-B')) {
          await second.mount(tester); if (transition == 'A-B-A2') await third.mount(tester);
          expect(identical(tester.state(find.byType(ExpensePage)), state), isTrue);
        }
        // A newer observed value on the same object must survive the old catch.
        shared.closed = true; shared.endDate = DateTime(2026, 10, 14);
        gate.complete(); await tester.pumpAndSettle();
        expect(first.logs, isEmpty); expect(second.logs, isEmpty); expect(third.logs, isEmpty);
        expect(find.textContaining('PRIVATE_OLD_CLOSE'), findsNothing);
        expect(saves, 1); expect(tester.takeException(), isNull);
        expect(shared.closed, true, reason: 'STALE_CLOSE_MUTATED_SHARED_OBSERVATION');
        expect(shared.endDate, DateTime(2026, 10, 14));
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
