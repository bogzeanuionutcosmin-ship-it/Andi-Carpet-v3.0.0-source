import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/finance_uncertain_store.dart';

dynamic target(WidgetTester tester, bool legacy) {
  final page = tester.widget<ExpensePage>(find.byType(ExpensePage));
  return legacy ? page.finances.single : page.settlements.single;
}
Future<void> receipt(WidgetTester tester, ExpenseDocumentFixture fixture,
    {String amount = '200', bool departure = true}) async {
  final label = departure ? 'Primit la plecare' : 'Primit în timpul deplasării';
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label)); await tester.pumpAndSettle();
  await fixture.enter(tester, 'Valoare', amount);
  await fixture.enter(tester, 'De la cine', 'PRIVATE_SYNTHETIC_PAYER');
  await tester.tap(find.widgetWithText(FilledButton, 'Adaugă'));
  await tester.pumpAndSettle();
}
int financeEvents() => VisionErrorTelemetry.log.entries
  .where((e) => e.area == 'finance' && e.code == 'received_amount_save_failed')
  .fold(0, (count, entry) => count + entry.count);
ExpenseDocumentFixture fixtureFor(FinanceUncertainStore store, bool legacy,
    {String uid = 'A'}) {
  final fixture = ExpenseDocumentFixture('', userId: uid);
  fixture.legacyFinance = legacy;
  fixture.saveSettlementOverride = (s) => store.save(s);
  fixture.saveFinanceOverride = (f) => store.save(f);
  return fixture;
}
void main() {
  for (final legacy in [false, true]) {
    for (final outcome in ['confirmed', 'timeout-no-commit', 'commit-then-timeout']) {
      testWidgets('CHARACTERIZATION legacy=$legacy $outcome has no implicit retry', (tester) async {
        final store = FinanceUncertainStore(); final fixture = fixtureFor(store, legacy);
        await fixture.mount(tester); final model = target(tester, legacy);
        final before = financeEvidence(model); store.durable = before;
        final events = financeEvents();
        await receipt(tester, fixture);
        expect(store.writes, hasLength(1)); expect(fixture.logs, isEmpty);
        final attempted = financeEvidence(model);
        await tester.pump(const Duration(seconds: 30));
        expect(store.writes, hasLength(1)); expect(fixture.logs, isEmpty);
        expect(financeEvents(), events); // Offline/pending alone is not a failure.
        if (outcome != 'timeout-no-commit') store.commit(0);
        store.acknowledge(0, error: outcome == 'confirmed' ? null : TimeoutException('PRIVATE_TIMEOUT'));
        await tester.pumpAndSettle();
        expect(financeEvidence(model), attempted);
        expect(store.durable, outcome == 'timeout-no-commit' ? before : attempted);
        expect(fixture.logs.length, outcome == 'confirmed' ? 1 : 0);
        expect(financeEvents(), events + (outcome == 'confirmed' ? 0 : 1));
        expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE_')));
        await tester.pump(const Duration(minutes: 1)); expect(store.writes, hasLength(1));
        expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
      });
    }
    for (final firstCommitted in [false, true]) {
      testWidgets('KNOWN UNSAFE manual reentry legacy=$legacy priorCommit=$firstCommitted duplicates intent', (tester) async {
        final store = FinanceUncertainStore(); final fixture = fixtureFor(store, legacy);
        await fixture.mount(tester); final model = target(tester, legacy);
        await receipt(tester, fixture); final firstId = model.receivedEntries.single.id;
        if (firstCommitted) store.commit(0);
        store.acknowledge(0, error: TimeoutException('synthetic unknown outcome'));
        await tester.pumpAndSettle(); expect(fixture.logs, isEmpty);
        // A second deliberate UI entry is a new operation, not automatic retry.
        await receipt(tester, fixture);
        expect(store.writes, hasLength(2)); expect(model.receivedEntries, hasLength(2));
        expect(model.receivedEntries.first.id, firstId);
        expect(model.receivedEntries.last.id, isNot(firstId));
        expect(model.departureTotal, 400);
        store.commit(1); store.acknowledge(1); await tester.pumpAndSettle();
        expect(store.durable!['departure'], 400); expect(fixture.logs, hasLength(1));
        expect(store.writes.first.payload['entries'], hasLength(1)); // frozen, not aliased
        expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
      });
    }
    for (final reverseOrder in [false, true]) {
      testWidgets('KNOWN UNSAFE two page instances legacy=$legacy reverse=$reverseOrder lose a concurrent receipt', (tester) async {
        final store = FinanceUncertainStore();
        final first = fixtureFor(store, legacy); await first.mount(tester);
        await receipt(tester, first); final firstPayload = store.writes.single.payload;
        // Dispose the first view, retaining its pending write: independent
        // devices have separate State/locks and can both submit before either ack.
        await tester.pumpWidget(const SizedBox());
        final second = fixtureFor(store, legacy); await second.mount(tester);
        await receipt(tester, second, amount: '300', departure: false);
        expect(store.writes, hasLength(2));
        final secondPayload = store.writes.last.payload;
        expect(firstPayload['departure'], 200); expect(secondPayload['during'], 300);
        for (final index in reverseOrder ? [1, 0] : [0, 1]) store.commit(index);
        expect(store.durable, reverseOrder ? firstPayload : secondPayload);
        expect(store.durable!['entries'], hasLength(1));
        expect(store.durable!['departure'], reverseOrder ? 200 : 0);
        expect(store.durable!['during'], reverseOrder ? 0 : 300);
        store.acknowledge(0); store.acknowledge(1); await tester.pumpAndSettle();
        expect(first.logs, isEmpty); expect(second.logs, hasLength(1));
        expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
      });
    }
    for (final returnToA in [false, true]) {
      testWidgets('late durable commit legacy=$legacy A-B-A2=$returnToA stays detached from successor', (tester) async {
        final store = FinanceUncertainStore(); final first = fixtureFor(store, legacy);
        await first.mount(tester); final state = tester.state(find.byType(ExpensePage));
        await receipt(tester, first); final oldPayload = store.writes.single.payload;
        final second = fixtureFor(store, legacy, uid: 'B'); await second.mount(tester);
        final third = fixtureFor(store, legacy); if (returnToA) await third.mount(tester);
        final successor = returnToA ? third : second;
        expect(identical(tester.state(find.byType(ExpensePage)), state), isTrue);
        final model = target(tester, legacy); final before = financeEvidence(model);
        final events = financeEvents(); store.commit(0);
        store.acknowledge(0, error: TimeoutException('PRIVATE_OLD_A_TIMEOUT'));
        await tester.pumpAndSettle();
        expect(store.durable, oldPayload); expect(financeEvidence(model), before);
        expect(first.logs, isEmpty); expect(successor.logs, isEmpty); expect(financeEvents(), events);
        expect(find.textContaining('PRIVATE_OLD_A'), findsNothing);
        expect(store.writes, hasLength(1)); expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('KNOWN UNSAFE close commit then timeout diverges closed from durable document', (tester) async {
    final store = FinanceUncertainStore(); final fixture = fixtureFor(store, false);
    await fixture.mount(tester); final model = target(tester, false);
    await tester.ensureVisible(find.text('Închide decontul')); await tester.tap(find.text('Închide decontul'));
    await tester.pumpAndSettle(); await tester.tap(find.widgetWithText(FilledButton, 'Închide'));
    await tester.pumpAndSettle(); expect(store.writes, hasLength(1));
    store.commit(0); store.acknowledge(0, error: TimeoutException('unknown close result'));
    await tester.pumpAndSettle();
    expect(store.durable!['closed'], true); expect(model.closed, false);
    expect(model.endDate, store.durable!['end']); expect(fixture.logs, isEmpty);
    expect(store.writes, hasLength(1)); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
