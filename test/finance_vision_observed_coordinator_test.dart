import 'dart:async';
import 'package:andi_carpeta/finance/intents/finance_checked_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_coordinator.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/integration/finance_vision_observed_coordinator.dart';
import 'package:andi_carpeta/vision/vision_scoped_signal_sink.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/finance_atomic_fixture.dart';

class _MemoryStorage implements FinanceJournalStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
}

FinanceIntent _intent() => FinanceIntent(
  operationId: '22222222222222222222222222222222',
  actorUid: 'A',
  teamId: 'team',
  collection: 'settlements',
  documentId: 'trip',
  baseRevision: 0,
  kind: FinanceIntentKind.receipt,
  changes: {
    'kind': 'during', 'amount': 123, 'method': 'Cash',
    'fromName': 'SecretCustomer', 'date': DateTime.utc(2026, 10, 16),
  },
);

FinanceAtomicFixture _db() => FinanceAtomicFixture()..seed(
  'settlements/trip', <String, Object?>{
    'teamId': 'team', 'closed': false, 'receivedDeparture': 0,
    'receivedDuring': 0, 'receivedEntries': <Object?>[],
  },
);

FinanceVisionObservedCoordinator _observed(
  FinanceAtomicFixture db,
  _MemoryStorage storage,
  VisionScopedSignalSink sink,
  bool Function() owner,
) {
  final checked = FinanceCheckedJournalStorage.singleWriterCandidate(
    storage: storage, ownerUid: 'A', sessionIsCurrent: owner,
  );
  final core = FinanceIntentCoordinator(
    repository: FinanceRepository(
      port: db, ownerUid: 'A', sessionIsCurrent: owner,
    ),
    journal: FinanceIntentJournal(
      storage: checked, ownerUid: 'A', sessionIsCurrent: owner,
    ),
  );
  return FinanceVisionObservedCoordinator(
    coordinator: core,
    sink: sink,
    platform: VisionSignalPlatform.android,
  );
}

void main() {
  test('explicit write reports uncertain once, recovery does not resubmit', () async {
    final db = _db()..commitThenThrow = true;
    final storage = _MemoryStorage();
    final vision = VisionSessionJournal();
    final lease = vision.startSession(isSessionCurrent: () => true);
    final sink = VisionScopedSignalSink(lease);
    final observed = _observed(db, storage, sink, () => true);
    final intent = _intent();
    final first = await observed.executeExplicitly(intent);
    expect(first.result.status, FinanceIntentStatus.uncertain);
    expect(db.calls, 1);
    expect(db.documents['settlements/trip']!['receivedEntries'], hasLength(1));
    expect(lease.entries.single.fingerprint, 'finance/operation_uncertain/android');
    expect(lease.buildReport(), isNot(contains('SecretCustomer')));
    // A UTC timestamp may naturally contain "123" in milliseconds.
    // Verify structured payload exclusion instead of matching arbitrary digits.
    expect(lease.buildReport(), isNot(contains('amount=123')));
    expect(lease.buildReport(), isNot(contains(intent.operationId)));

    // A second explicit Execute on the same persisted intent must never
    // resubmit an uncertain operation. Only Reconcile is permitted.
    final secondExecute = await observed.executeExplicitly(intent);
    expect(secondExecute.result.status, FinanceIntentStatus.uncertain);
    expect(secondExecute.result.code,
        'finance_existing_intent_requires_reconciliation');
    expect(secondExecute.journalPending, isTrue);
    expect(db.calls, 1);
    expect(db.documents['settlements/trip']!['receivedEntries'], hasLength(1));

    db.commitThenThrow = false;
    final restored = _observed(db, storage, sink, () => true);
    final result = await restored.reconcileExplicitly(intent);
    expect(result.result.status, FinanceIntentStatus.confirmed);
    expect(db.calls, 1);
    expect(lease.entries.single.count, 2);
    expect(await restored.coordinator.journal.pending(), isEmpty);
  });

  test('corrupt durable journal blocks submission rather than resetting', () async {
    final db = _db();
    final storage = _MemoryStorage();
    storage.values['finance_intents_v1_A'] = '{malformed';
    final lease = VisionSessionJournal().startSession(
      isSessionCurrent: () => true,
    );
    final observed = _observed(
      db, storage, VisionScopedSignalSink(lease), () => true,
    );
    final result = await observed.executeExplicitly(_intent());
    expect(result.result.status, FinanceIntentStatus.uncertain);
    expect(result.result.code, 'finance_pending_journal_unavailable');
    expect(result.journalPending, isTrue);
    expect(db.calls, 0);
    expect(db.writes, 0);
    expect(storage.values['finance_intents_v1_A'], '{malformed');
    expect(lease.entries.single.fingerprint,
        'finance/operation_uncertain/android');
  });

  test('simultaneous taps coalesce to one journal and server call', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final db = _db()..commitThenThrow = true;
    db.beforeCommit = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    final storage = _MemoryStorage();
    final lease = VisionSessionJournal().startSession(
      isSessionCurrent: () => true,
    );
    final observed = _observed(
      db, storage, VisionScopedSignalSink(lease), () => true,
    );
    final intent = _intent();
    final calls = List.generate(30, (_) => observed.executeExplicitly(intent));
    for (final call in calls.skip(1)) {
      expect(identical(call, calls.first), isTrue);
    }
    final competing = FinanceIntent(
      operationId: '33333333333333333333333333333333',
      actorUid: intent.actorUid,
      teamId: intent.teamId,
      collection: intent.collection,
      documentId: intent.documentId,
      baseRevision: intent.baseRevision,
      kind: intent.kind,
      changes: intent.changes,
    );
    final blocked = await observed.executeExplicitly(competing);
    expect(blocked.result.status, FinanceIntentStatus.uncertain);
    expect(blocked.result.code, 'finance_operation_still_in_flight');
    expect(blocked.blockedByPendingIntent, isTrue);
    await entered.future;
    expect(db.calls, 1);
    release.complete();
    final results = await Future.wait(calls);
    expect(results.every(
      (r) => r.result.status == FinanceIntentStatus.uncertain,
    ), isTrue);
    expect(db.calls, 1);
    expect(db.documents['settlements/trip']!['receivedEntries'], hasLength(1));
    expect(lease.entries.single.count, 1);
    expect((await observed.coordinator.journal.pending()).single.operationId,
        intent.operationId);
  });

  test('two wrappers in one isolate cannot race the same financial target', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final db = _db()..commitThenThrow = true;
    db.beforeCommit = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    final storage = _MemoryStorage();
    // Two widgets for the SAME account; separate diagnostic sessions and
    // wrapper objects intentionally do not share financial Future values.
    final visionA = VisionSessionJournal().startSession(
      isSessionCurrent: () => true,
    );
    final visionB = VisionSessionJournal().startSession(
      isSessionCurrent: () => true,
    );
    final first = _observed(
      db, storage, VisionScopedSignalSink(visionA), () => true,
    );
    final second = _observed(
      db, storage, VisionScopedSignalSink(visionB), () => true,
    );
    final intent = _intent();
    final inFlight = first.executeExplicitly(intent);
    await entered.future;
    final blocked = await second.executeExplicitly(intent);
    expect(blocked.result.code, 'finance_operation_in_another_scope');
    expect(blocked.result.status, FinanceIntentStatus.uncertain);
    expect(blocked.blockedByPendingIntent, isTrue);
    final blockedRecovery = await second.reconcileExplicitly(intent);
    expect(blockedRecovery.result.code, 'finance_operation_in_another_scope');
    expect(db.calls, 1);
    expect(db.serverReads, 0);
    expect(visionB.entries, isEmpty); // No cross-session result copied.

    release.complete();
    expect((await inFlight).result.status, FinanceIntentStatus.uncertain);
    expect(db.calls, 1);
    expect(db.documents['settlements/trip']!['receivedEntries'], hasLength(1));
    expect(visionA.entries.single.fingerprint,
        'finance/operation_uncertain/android');

    // Releasing the isolate lease does NOT authorize Execute to resubmit a
    // durable uncertain operation. Explicit marker reconciliation is required.
    final replay = await second.executeExplicitly(intent);
    expect(replay.result.code,
        'finance_existing_intent_requires_reconciliation');
    expect(db.calls, 1);
    db.commitThenThrow = false;
    final confirmed = await second.reconcileExplicitly(intent);
    expect(confirmed.result.status, FinanceIntentStatus.confirmed);
    expect(db.calls, 1);
    expect(await second.coordinator.journal.pending(), isEmpty);
  });

  test('overlapping explicit reconciliation reads server only once', () async {
    final db = _db()..commitThenThrow = true;
    final storage = _MemoryStorage();
    final lease = VisionSessionJournal().startSession(
      isSessionCurrent: () => true,
    );
    final observed = _observed(
      db, storage, VisionScopedSignalSink(lease), () => true,
    );
    final intent = _intent();
    final first = await observed.executeExplicitly(intent);
    expect(first.result.status, FinanceIntentStatus.uncertain);
    db.commitThenThrow = false;
    final entered = Completer<void>(), release = Completer<void>();
    db.beforeServerReturn = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    final a = observed.reconcileExplicitly(intent);
    final b = observed.reconcileExplicitly(intent);
    expect(identical(a, b), isTrue);
    final cannotResend = await observed.executeExplicitly(intent);
    expect(cannotResend.result.code, 'finance_operation_still_in_flight');
    await entered.future;
    expect(db.serverReads, 1);
    release.complete();
    final result = await a;
    expect((await b).result.status, FinanceIntentStatus.confirmed);
    expect(result.result.status, FinanceIntentStatus.confirmed);
    expect(db.serverReads, 1); // Coordinator reads marker only; UI refresh is separate.
    expect(db.calls, 1);
    expect(await observed.coordinator.journal.pending(), isEmpty);
    expect(lease.entries.single.count, 1);
  });

  test('A1 to B to A2 cannot reopen an observer after identity denial', () async {
    final db = _db();
    final storage = _MemoryStorage();
    var a1Current = true;
    final journal = VisionSessionJournal();
    final a1 = journal.startSession(isSessionCurrent: () => a1Current);
    final observed = _observed(
      db, storage, VisionScopedSignalSink(a1), () => a1Current,
    );
    a1Current = false;
    journal.revoke(); // B owns a distinct AuthGate generation.
    final b = journal.startSession(isSessionCurrent: () => true);
    final first = await observed.executeExplicitly(_intent());
    expect(first.result.status, FinanceIntentStatus.uncertain);
    expect(first.result.code, 'finance_session_expired');
    expect(db.calls, 0);
    expect(storage.values, isEmpty);
    expect(a1.entries, isEmpty);
    expect(b.entries, isEmpty);

    a1Current = true; // Same UID returns under a NEW generation (A2).
    journal.revoke();
    final a2 = journal.startSession(isSessionCurrent: () => true);
    final returned = await observed.executeExplicitly(_intent());
    expect(returned.result.code, 'finance_session_expired');
    final recover = await observed.reconcileExplicitly(_intent());
    expect(recover.result.code, 'finance_session_expired');
    expect(db.calls, 0);
    expect(storage.values, isEmpty);
    expect(a2.entries, isEmpty);
  });

  test('disposed observer blocks all later financial entrypoints', () async {
    final db = _db();
    final storage = _MemoryStorage();
    final lease = VisionSessionJournal().startSession(
      isSessionCurrent: () => true,
    );
    final observed = _observed(
      db, storage, VisionScopedSignalSink(lease), () => true,
    );
    observed.dispose();
    observed.dispose(); // idempotent
    final x = await observed.executeExplicitly(_intent());
    final y = await observed.reconcileExplicitly(_intent());
    expect(x.result.code, 'finance_session_expired');
    expect(y.result.code, 'finance_session_expired');
    expect(db.calls, 0);
    expect(storage.values, isEmpty);
    expect(lease.entries, isEmpty);
  });

  test('late completion after logout cannot write to the old Vision lease', () async {
    final db = _db();
    final storage = _MemoryStorage();
    var authorized = true;
    final vision = VisionSessionJournal();
    final leaseA = vision.startSession(isSessionCurrent: () => authorized);
    final sinkA = VisionScopedSignalSink(leaseA);
    final observed = _observed(db, storage, sinkA, () => authorized);
    // Suspend the transaction *after* it has read server data.
    final entered = <bool>[];
    final gate = <void Function()>[];
    db.beforeCommit = () async {
      entered.add(true);
      await Future<void>(() async {
        while (gate.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        gate.single();
      });
    };
    final pending = observed.executeExplicitly(_intent());
    while (entered.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    authorized = false;
    vision.revoke();
    final leaseB = vision.startSession(isSessionCurrent: () => true);
    gate.add(() {});
    final result = await pending;
    expect(result.result.status, anyOf(
      FinanceIntentStatus.uncertain,
      FinanceIntentStatus.rejectedBeforeWrite,
      FinanceIntentStatus.confirmed,
    ));
    expect(sinkA.emit(
      VisionDiagnosticSignal.financeOperationUncertain,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(leaseA.entries, isEmpty);
    expect(leaseB.entries, isEmpty);
  });
}
