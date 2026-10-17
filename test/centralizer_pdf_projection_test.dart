import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/main.dart';

CentralizerRecord _record({
  required String id,
  required DateTime startedAt,
  required DateTime finishedAt,
  bool facadeDone = false,
}) =>
    CentralizerRecord(
      id: id,
      teamId: 'craiova',
      locationId: 'sala-$id',
      type: LocationType.magic,
      locationNameSnapshot: 'Sala $id',
      addressSnapshot: 'Craiova',
      startedAt: startedAt,
      finishedAt: finishedAt,
      status: WorkAttemptStatus.completed,
      facadePlanned: facadeDone,
      facadeDone: facadeDone,
    );

void main() {
  test('Centralizator PDF projection keeps 11 executions and actual day totals', () {
    final records = <CentralizerRecord>[
      for (var index = 1; index <= 11; index++)
        _record(
          id: '$index',
          startedAt: DateTime(2026, 10, index <= 6 ? 15 : 16, 10),
          finishedAt: DateTime(2026, 10, index <= 6 ? 15 : 16, 11),
          facadeDone: index == 6,
        ),
    ];

    final rows = centralizerPdfExecutionRows(
      records: records,
      type: LocationType.magic,
      teamId: 'craiova',
    );

    expect(rows, hasLength(11));
    expect(rows.where((row) => row.date.day == 15), hasLength(6));
    expect(rows.where((row) => row.date.day == 16), hasLength(5));
    expect(rows.map((row) => row.record.id).toSet(), hasLength(11));
    expect(rows.singleWhere((row) => row.record.id == '6').record.facadeDone,
        isTrue);
  });

  test('overnight PDF row uses event date and retains stable intervention data', () {
    final record = _record(
      id: 'overnight',
      startedAt: DateTime(2026, 10, 15, 23, 55),
      finishedAt: DateTime(2026, 10, 16, 0, 20),
      facadeDone: true,
    );

    final rows = centralizerPdfExecutionRows(
      records: [record],
      type: LocationType.magic,
      from: DateTime(2026, 10, 16),
      to: DateTime(2026, 10, 16),
    );

    expect(rows, hasLength(1));
    expect(rows.single.date, DateTime(2026, 10, 16, 0, 20));
    expect(rows.single.record.id, 'overnight');
    expect(rows.single.record.startedAt, DateTime(2026, 10, 15, 23, 55));
    expect(rows.single.record.finishedAt, DateTime(2026, 10, 16, 0, 20));
    expect(rows.single.record.facadeDone, isTrue);
  });
}
