import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/main.dart';

CentralizerRecord _record({
  required DateTime startedAt,
  DateTime? finishedAt,
}) =>
    CentralizerRecord(
      id: 'execution-1',
      teamId: 'craiova',
      locationId: 'sala-1',
      type: LocationType.magic,
      locationNameSnapshot: 'Sala 1',
      addressSnapshot: 'Craiova',
      startedAt: startedAt,
      finishedAt: finishedAt,
      status: WorkAttemptStatus.completed,
    );

void main() {
  test('real daytime and late-evening executions do not expire at 12:30', () {
    for(final hour in [13,22]) {
      final record=_record(startedAt:DateTime(2026,10,16,hour));
      expect(recordBelongsToWorkDate(record,DateTime(2026,10,16)),isTrue);
      expect(recordBelongsToWorkDate(record,DateTime(2026,10,17)),isFalse);
    }
  });
  test('operational date rolls over at the configured 23:30 boundary', () {
    expect(operationalWorkDate(DateTime(2026, 10, 15, 23, 29)),
        DateTime(2026, 10, 15));
    expect(operationalWorkDate(DateTime(2026, 10, 15, 23, 30)),
        DateTime(2026, 10, 16));
    expect(operationalWorkDate(DateTime(2026, 10, 16, 0, 20)),
        DateTime(2026, 10, 16));
  });

  test('overnight execution is matched to the next operational schedule day', () {
    final record = _record(
      startedAt: DateTime(2026, 10, 15, 23, 55),
      finishedAt: DateTime(2026, 10, 16, 0, 20),
    );

    expect(recordEventTime(record), DateTime(2026, 10, 16, 0, 20));
    expect(recordBelongsToWorkDate(record, DateTime(2026, 10, 16)), isTrue);
    expect(recordBelongsToWorkDate(record, DateTime(2026, 10, 15)), isFalse);
  });

  test('date projection falls back to START when FINAL is absent', () {
    final record = _record(startedAt: DateTime(2026, 10, 16, 1, 5));

    expect(recordEventTime(record), DateTime(2026, 10, 16, 1, 5));
    expect(recordBelongsToWorkDate(record, DateTime(2026, 10, 16)), isTrue);
  });
}
