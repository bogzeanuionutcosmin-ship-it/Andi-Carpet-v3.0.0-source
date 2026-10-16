import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/integration/finance_vision_outcome_observer.dart';
import 'package:andi_carpeta/vision/vision_scoped_signal_sink.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enum-only callback and original observer have identical safe signals', () {
    for (final status in FinanceIntentStatus.values) {
      final oldJournal = VisionSessionJournal();
      final newJournal = VisionSessionJournal();
      final oldLease = oldJournal.startSession(isSessionCurrent: () => true);
      final newLease = newJournal.startSession(isSessionCurrent: () => true);
      final original = FinanceVisionOutcomeObserver.observe(
        result: FinanceIntentResult(
          status, 'raw_SERVER_error_must_never_be_exported',
        ),
        sink: VisionScopedSignalSink(oldLease),
        platform: VisionSignalPlatform.web,
      );
      final minimal = FinanceVisionOutcomeObserver.observeStatus(
        status: status,
        sink: VisionScopedSignalSink(newLease),
        platform: VisionSignalPlatform.web,
      );
      expect(minimal, original);
      expect(
        newLease.entries.map((e) => e.fingerprint).toList(),
        oldLease.entries.map((e) => e.fingerprint).toList(),
      );
      expect(newLease.buildReport(),
          isNot(contains('raw_SERVER_error_must_never_be_exported')));
      expect(newLease.entries.length, lessThanOrEqualTo(1));
    }
  });

  test('enum status alone never invents a permission incident', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    final sink = VisionScopedSignalSink(lease);
    expect(FinanceVisionOutcomeObserver.observeStatus(
      status: FinanceIntentStatus.rejectedBeforeWrite,
      sink: sink, platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(FinanceVisionOutcomeObserver.observeStatus(
      status: FinanceIntentStatus.confirmed,
      sink: sink, platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(lease.entries, isEmpty);
  });

  test('A1 revoked sink cannot emit a finance outcome to B or A2', () {
    final journal = VisionSessionJournal();
    var generation = 1;
    final a1 = journal.startSession(
      isSessionCurrent: () => generation == 1,
    );
    final sinkA = VisionScopedSignalSink(a1);
    generation = 2;
    final b = journal.startSession(
      isSessionCurrent: () => generation == 2,
    );
    expect(FinanceVisionOutcomeObserver.observeStatus(
      status: FinanceIntentStatus.uncertain,
      sink: sinkA, platform: VisionSignalPlatform.windows,
    ), isFalse);
    expect(b.entries, isEmpty);
    generation = 3;
    final a2 = journal.startSession(
      isSessionCurrent: () => generation == 3,
    );
    expect(FinanceVisionOutcomeObserver.observeStatus(
      status: FinanceIntentStatus.conflict,
      sink: sinkA, platform: VisionSignalPlatform.windows,
    ), isFalse);
    expect(a1.entries, isEmpty);
    expect(a2.entries, isEmpty);
    expect(FinanceVisionOutcomeObserver.observeStatus(
      status: FinanceIntentStatus.uncertain,
      sink: VisionScopedSignalSink(a2),
      platform: VisionSignalPlatform.android,
    ), isTrue);
    expect(a2.entries.single.fingerprint,
        'finance/operation_uncertain/android');
  });
}
