import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/finance/intents/finance_checked_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_home_candidate.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/finance_atomic_fixture.dart';
import 'support/finance_home_candidate_fixture.dart';
import 'finance_intent_device_storage_test.dart' show DeviceFixture;

Future<void> create(WidgetTester t, HomeCandidateFixture h) async {
  await t.tap(find.text('Nouă')); await t.pumpAndSettle();
  await h.page.enter(t, 'Denumire', 'Candidate trip');
  await t.tap(find.widgetWithText(FilledButton, 'Creează')); await t.pumpAndSettle();
}
Future<void> receipt(WidgetTester t, HomeCandidateFixture h, String amount) async {
  await t.ensureVisible(find.text('Primit la plecare'));
  await t.tap(find.text('Primit la plecare')); await t.pumpAndSettle();
  await h.page.enter(t, 'Valoare', amount); await h.page.enter(t, 'De la cine', 'Synthetic');
  await t.tap(find.widgetWithText(FilledButton, 'Adaugă')); await t.pumpAndSettle();
}
HomeCandidateFixture harness(FinanceAtomicFixture db, DeviceFixture storage) =>
  HomeCandidateFixture(uid: 'worker', teamId: 'team', port: db, deviceStorage: storage);
FinanceIntentJournal journal(DeviceFixture d) => FinanceIntentJournal(ownerUid: 'worker',
  sessionIsCurrent: () => true,
  storage: FinanceCheckedJournalStorage.singleWriterCandidate(storage: d,
    ownerUid: 'worker', sessionIsCurrent: () => true));

void main() {
  for (final amount in ['200', '200.00', '200,00']) {
    testWidgets('Home opt-in original create receipt edit close reopen amount=$amount', (t) async {
      final db = FinanceAtomicFixture(), storage = DeviceFixture(), h = harness(db, storage);
      expect(db.calls, 0); expect(db.serverReads, 0); expect(storage.reads, 0);
      await h.page.mount(t); await create(t, h); await receipt(t, h, amount);
      expect(h.page.settlementOverride!.receivedDeparture, 200);
      expect(h.page.settlementOverride!.revision, 2);
      await t.ensureVisible(find.text('Editează deplasarea'));
      await t.tap(find.text('Editează deplasarea')); await t.pumpAndSettle();
      await h.page.enter(t, 'Denumire', 'Candidate revised');
      await t.tap(find.widgetWithText(FilledButton, 'Salvează')); await t.pumpAndSettle();
      await t.ensureVisible(find.text('Închide decontul'));
      await t.tap(find.text('Închide decontul')); await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Închide')); await t.pumpAndSettle();
      expect(h.page.settlementOverride!.closed, true);
      await t.ensureVisible(find.text('Redeschide')); await t.tap(find.text('Redeschide'));
      await t.pumpAndSettle();
      expect(h.page.settlementOverride!.closed, false);
      expect(h.page.settlementOverride!.revision, 5);
      expect(h.page.logs, hasLength(5)); expect(db.calls, 5); expect(db.writes, 10);
      expect(db.serverReads, 5); expect(await journal(storage).pending(), isEmpty);
      await t.pumpWidget(const SizedBox()); h.candidate.dispose();
    });
  }
  testWidgets('Home opt-in cancel and rebuild do no I/O; pending double click cannot create second intent', (t) async {
    final db = FinanceAtomicFixture(), storage = DeviceFixture(), h = harness(db, storage);
    await h.page.mount(t); await t.tap(find.text('Nouă')); await t.pumpAndSettle();
    await t.tap(find.text('Anulează')); await t.pumpAndSettle();
    h.page.rebuild(() {}); await t.pumpAndSettle();
    expect(db.calls, 0); expect(storage.reads, 0); await create(t, h);
    db.commitThenThrow = true; await receipt(t, h, '200');
    final original = (await journal(storage).pending()).single;
    await t.tap(find.text('Primit la plecare')); await t.pumpAndSettle();
    expect(find.text('Adaugă sumă primită la plecare'), findsNothing);
    expect(db.calls, 2); expect(h.page.logs, hasLength(1));
    expect((await journal(storage).pending()).single.digest, original.digest);
    await h.candidate.reconcileExplicitly(original.targetPath); await t.pumpAndSettle();
    expect(db.calls, 2); expect(h.page.logs, hasLength(2));
    expect(h.page.settlementOverride!.receivedEntries, hasLength(1));
    await t.pumpWidget(const SizedBox()); h.candidate.dispose();
  });
  testWidgets('Home team change during delayed commit hides pending and never installs or audits late result', (t) async {
    final db = FinanceAtomicFixture(), storage = DeviceFixture(), h = harness(db, storage);
    await h.page.mount(t); await create(t, h);
    final entered = Completer<void>(), release = Completer<void>();
    db.beforeCommit = () async { entered.complete(); await release.future; };
    await receipt(t, h, '200'); await entered.future;
    h.current = false; expect(h.candidate.sessionIsCurrent(), false);
    h.current = true; // A2 / same UID cannot revive the previous generation.
    expect(h.candidate.sessionIsCurrent(), false); release.complete(); await t.pumpAndSettle();
    expect(h.refreshes, 1); expect(h.page.logs, hasLength(1));
    expect(h.candidate.pendingCodes, isEmpty); expect(await journal(storage).pending(), hasLength(1));
    await t.pumpWidget(const SizedBox()); h.candidate.dispose();
  });
  testWidgets('Home explicit recovery across composition recreation never resends committed receipt', (t) async {
    final db = FinanceAtomicFixture(), storage = DeviceFixture(), first = harness(db, storage);
    await first.page.mount(t); await create(t, first); db.commitThenThrow = true;
    await receipt(t, first, '200'); final original = (await journal(storage).pending()).single;
    await t.pumpWidget(const SizedBox()); first.candidate.dispose();
    final reads = db.serverReads, writes = storage.writes;
    final second = harness(db, storage); await second.page.mount(t);
    expect(storage.writes, writes); expect(db.serverReads, reads); expect(db.calls, 2);
    await second.candidate.loadPendingForReviewExplicitly();
    expect(db.calls, 2); expect(db.serverReads, reads);
    expect(second.candidate.pendingCodes.keys.single, original.targetPath);
    await second.candidate.reconcileExplicitly(original.targetPath); await t.pumpAndSettle();
    expect(db.calls, 2); expect(db.serverReads, reads + 2);
    expect(second.page.logs, isEmpty); expect(second.page.settlementOverride!.revision, 2);
    expect(second.page.settlementOverride!.receivedDeparture, 200);
    expect(await journal(storage).pending(), isEmpty);
    await t.pumpWidget(const SizedBox()); second.candidate.dispose();
  });
  test('Home bound team rejects foreign model and foreign pending journal before adoption', () async {
    final db = FinanceAtomicFixture(), storage = DeviceFixture();
    final h = harness(db, storage);
    final foreign = TravelSettlement(id: 'trip', teamId: 'other', name: 'Foreign', startDate: DateTime.utc(2026));
    expect(() => h.candidate.saveSettlement(foreign), throwsA(isA<FinanceSaveRejected>()));
    expect(storage.reads, 0); expect(db.calls, 0);
    final intent = FinanceIntent(operationId: 'a' * 32, actorUid: 'worker', teamId: 'other',
      collection: 'settlements', documentId: 'trip', baseRevision: 0, kind: FinanceIntentKind.receipt,
      changes: {'kind': 'departure', 'amount': 200, 'method': 'Cash', 'fromName': 'Synthetic', 'date': DateTime.utc(2026)});
    await journal(storage).prepare(intent); final bytes = storage.values.values.single;
    await expectLater(h.candidate.loadPendingForReviewExplicitly(), throwsA(isA<FinanceSaveRejected>()));
    expect(h.candidate.pendingCodes, isEmpty); expect(storage.values.values.single, bytes);
    expect(db.calls, 0); expect(db.serverReads, 0); h.candidate.dispose();
  });
  test('Home unobserved existing target is never overwritten as a create', () async {
    final db = FinanceAtomicFixture(), storage = DeviceFixture(), h = harness(db, storage);
    final date = DateTime.utc(2026);
    db.seed('settlements/trip', {'teamId': 'team', 'name': 'Original'});
    final model = TravelSettlement(id: 'trip', teamId: 'team', name: 'Attempt',
      startDate: date, createdAt: date, managerId: 'worker');
    // A revision conflict remains unresolved; no false rejection/rollback.
    unawaited(h.candidate.saveSettlement(model));
    for (var n = 0; n < 30; n++) { await Future<void>.delayed(Duration.zero); }
    expect(db.calls, 1); expect(db.writes, 0);
    expect(db.documents['settlements/trip']!['name'], 'Original');
    expect(h.candidate.pendingCodes.values.single, 'finance_revision_conflict');
    expect(await journal(storage).pending(), hasLength(1)); h.candidate.dispose();
  });
}
