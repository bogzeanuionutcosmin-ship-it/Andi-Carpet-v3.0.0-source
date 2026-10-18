import 'package:andi_carpeta/finance/intents/finance_checked_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_coordinator.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/integration/finance_vision_outcome_observer.dart';
import 'package:andi_carpeta/vision/vision_diagnostic_advisor.dart';
import 'package:andi_carpeta/vision/vision_scoped_signal_sink.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/finance_atomic_fixture.dart';

class _SyntheticDeviceStorage implements FinanceJournalStorage {
  final Map<String, String> snapshots = {};
  int writes = 0;
  @override
  Future<String?> read(String key) async => snapshots[key];
  @override
  Future<void> write(String key, String value) async {
    writes++;
    snapshots[key] = value;
  }
}

FinanceIntent _receipt() => FinanceIntent(
  operationId: '11111111111111111111111111111111',
  actorUid: 'A',
  teamId: 'team',
  collection: 'settlements',
  documentId: 'trip',
  baseRevision: 0,
  kind: FinanceIntentKind.receipt,
  changes: {
    'kind': 'departure',
    'amount': 200,
    'method': 'Cash',
    'fromName': 'Synthetic',
    'date': DateTime.utc(2026, 10, 16),
  },
);

FinanceIntentCoordinator _coordinator(
  FinanceAtomicFixture db,
  _SyntheticDeviceStorage storage,
  bool Function() owner,
) {
  final checked = FinanceCheckedJournalStorage.singleWriterCandidate(
    storage: storage,
    ownerUid: 'A',
    sessionIsCurrent: owner,
  );
  return FinanceIntentCoordinator(
    repository: FinanceRepository(
      port: db,
      ownerUid: 'A',
      sessionIsCurrent: owner,
    ),
    journal: FinanceIntentJournal(
      storage: checked,
      ownerUid: 'A',
      sessionIsCurrent: owner,
    ),
  );
}

void main() {
  test('lost server acknowledgment yields only a scoped uncertain warning, '
      'then original intent reconciles without duplicate submission', () async {
    var ownerA = true;
    bool belongsToA() => ownerA;
    final db = FinanceAtomicFixture()
      ..seed('settlements/trip', <String, Object?>{
        'teamId': 'team',
        'closed': false,
        'receivedDeparture': 0,
        'receivedDuring': 0,
        'receivedEntries': <Object?>[],
      })
      ..commitThenThrow = true;
    final device = _SyntheticDeviceStorage();
    final journal = VisionSessionJournal();
    final leaseA = journal.startSession(isSessionCurrent: belongsToA);
    final sinkA = VisionScopedSignalSink(leaseA);
    final intent = _receipt();

    final financeA1 = _coordinator(db, device, belongsToA);
    final initial = await financeA1.executeExplicitly(intent);
    expect(initial.result.status, FinanceIntentStatus.uncertain);
    expect(initial.journalPending, isTrue);
    expect(db.calls, 1);
    expect(db.documents['settlements/trip']!['receivedEntries'], hasLength(1));

    expect(FinanceVisionOutcomeObserver.observe(
      result: initial.result,
      sink: sinkA,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    expect(leaseA.entries.single.fingerprint,
        'finance/operation_uncertain/android');
    final advice = VisionDiagnosticAdvisor.assess(
      leaseA.snapshotForDisplay()!,
    ).single;
    expect(advice.title, 'Rezultat financiar incert');
    expect(advice.explanation, contains('Nu retrimite automat'));
    expect(leaseA.buildReport(), isNot(contains('Synthetic')));
    expect(leaseA.buildReport(), isNot(contains('200')));

    // Account switch discards the old Vision report immediately. Finance
    // evidence remains intentionally durable for that owner, not user B.
    ownerA = false;
    journal.revoke();
    expect(FinanceVisionOutcomeObserver.observe(
      result: initial.result,
      sink: sinkA,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(leaseA.entries, isEmpty);
    expect(leaseA.buildReport(), isNull);

    final leaseB = journal.startSession(isSessionCurrent: () => true);
    expect(leaseB.entries, isEmpty);
    final checkedB = FinanceCheckedJournalStorage.singleWriterCandidate(
      storage: device, ownerUid: 'B', sessionIsCurrent: () => true,
    );
    final journalB = FinanceIntentJournal(
      storage: checkedB, ownerUid: 'B', sessionIsCurrent: () => true,
    );
    expect(await journalB.pending(), isEmpty);
    expect(device.snapshots.keys, isNot(contains('finance_intents_v1_B')));

    // A logs in anew: Vision A2 is blank, but the exact stored finance intent
    // can be reconciled. No second server transaction may be issued.
    journal.revoke();
    ownerA = true;
    final leaseA2 = journal.startSession(isSessionCurrent: belongsToA);
    expect(leaseA2.entries, isEmpty);
    db.commitThenThrow = false;
    final financeA2 = _coordinator(db, device, belongsToA);
    final pending = await financeA2.journal.pending();
    expect(pending, hasLength(1));
    expect(pending.single.operationId, intent.operationId);
    final reconciled = await financeA2.reconcileExplicitly(pending.single);
    expect(reconciled.result.status, FinanceIntentStatus.confirmed);
    expect(db.calls, 1);
    expect(db.documents['settlements/trip']!['receivedEntries'], hasLength(1));
    expect(await financeA2.journal.pending(), isEmpty);
    expect(FinanceVisionOutcomeObserver.observe(
      result: reconciled.result,
      sink: VisionScopedSignalSink(leaseA2),
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(leaseA2.entries, isEmpty);
  });

  test('only uncertain/conflict creates a technical signal, '
      'never confirmed or generic pre-write rejection', () {
    final lease = VisionSessionJournal().startSession(
      isSessionCurrent: () => true,
    );
    final sink = VisionScopedSignalSink(lease);
    for (final status in [
      FinanceIntentStatus.confirmed,
      FinanceIntentStatus.rejectedBeforeWrite,
    ]) {
      expect(FinanceVisionOutcomeObserver.observe(
        result: FinanceIntentResult(status, 'opaque'),
        sink: sink, platform: VisionSignalPlatform.web,
      ), isFalse);
    }
    expect(lease.entries, isEmpty);
    expect(FinanceVisionOutcomeObserver.observe(
      result: const FinanceIntentResult(
        FinanceIntentStatus.conflict, 'finance_conflict',
      ),
      sink: sink, platform: VisionSignalPlatform.web,
    ), isTrue);
    expect(lease.entries.single.fingerprint,
        'finance/revision_conflict/web');
  });

  test('callback revocation during observe forbids stale user signal', () {
    var valid = true;
    final lease = VisionSessionJournal().startSession(
      isSessionCurrent: () => valid,
    );
    valid = false;
    expect(FinanceVisionOutcomeObserver.observe(
      result: const FinanceIntentResult(
        FinanceIntentStatus.uncertain, 'finance_ack_lost',
      ),
      sink: VisionScopedSignalSink(lease),
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(lease.entries, isEmpty);
  });
}
