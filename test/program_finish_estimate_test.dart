import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/schedule/program_finish_estimate.dart';

class _Record {
  const _Record(this.running, this.startedAt);

  final bool running;
  final DateTime? startedAt;
}

void main() {
  final now = DateTime(2026, 10, 21, 9);

  DateTime? estimate(
    List<String> items,
    Map<String, Duration?> averages,
    Map<String, _Record?> records,
  ) =>
      estimateProgramFinish<String, _Record>(
        now: now,
        pendingItems: items,
        averageDurationForItem: (item) => averages[item],
        latestRecordForItem: (item) => records[item],
        isRunning: (record) => record?.running == true,
        startedAt: (record) => record?.startedAt,
      );

  test('returns now for an empty pending list without querying callbacks', () {
    var lookups = 0;
    expect(
      estimateProgramFinish<String, _Record>(
        now: now,
        pendingItems: const [],
        averageDurationForItem: (_) {
          lookups++;
          return const Duration(minutes: 1);
        },
        latestRecordForItem: (_) => null,
        isRunning: (_) => false,
        startedAt: (_) => null,
      ),
      now,
    );
    expect(lookups, 0);
  });

  test('returns unknown on missing average and stops before record lookup', () {
    var recordLookups = 0;
    var averageLookups = 0;
    expect(
      estimateProgramFinish<String, _Record>(
        now: now,
        pendingItems: const ['known', 'unknown', 'later'],
        averageDurationForItem: (item) {
          averageLookups++;
          return item == 'unknown' ? null : const Duration(minutes: 1);
        },
        latestRecordForItem: (_) {
          recordLookups++;
          return null;
        },
        isRunning: (_) => false,
        startedAt: (_) => null,
      ),
      isNull,
    );
    expect(averageLookups, 2);
    expect(recordLookups, 1);
  });

  test('subtracts elapsed time only for a running item', () {
    final result = estimate(
      ['running', 'waiting'],
      {
        'running': const Duration(minutes: 10),
        'waiting': const Duration(minutes: 10),
      },
      {
        'running': _Record(true, now.subtract(const Duration(minutes: 2))),
        'waiting': _Record(false, now.subtract(const Duration(minutes: 2))),
      },
    );
    expect(result, now.add(const Duration(minutes: 18)));
  });

  test('clamps future and overlong running durations to the average bounds', () {
    final result = estimate(
      ['future', 'overlong'],
      {
        'future': const Duration(minutes: 10),
        'overlong': const Duration(minutes: 10),
      },
      {
        'future': _Record(true, now.add(const Duration(minutes: 2))),
        'overlong': _Record(true, now.subtract(const Duration(minutes: 12))),
      },
    );
    expect(result, now.add(const Duration(minutes: 10)));
  });

  test('uses the full average when a running record has no start time', () {
    expect(
      estimate(
        ['running'],
        {'running': const Duration(seconds: 125)},
        {'running': const _Record(true, null)},
      ),
      now.add(const Duration(seconds: 125)),
    );
  });
}
