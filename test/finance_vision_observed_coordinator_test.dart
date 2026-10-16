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
    expect(lease.buildReport(), isNot(contains('123')));

    db.commitThenThrow = false;
    final restored = _observed(db, storage, sink, () => true);
    final result = await restored.reconcileExplicitly(intent);
    expect(result.result.status, FinanceIntentStatus.confirmed);
    expect(db.calls, 1);
    expect(lease.entries.single.count, 1);
    expect(await restored.coordinator.journal.pending(), isEmpty);
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
