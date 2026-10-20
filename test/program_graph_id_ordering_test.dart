import 'package:andi_carpeta/schedule/program_graph_id_ordering.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScheduleRow {
  const _ScheduleRow(this.graphId, this.date);

  final String graphId;
  final DateTime date;
}

void main() {
  group('orderedProgramGraphIds', () {
    test('deduplicates IDs and orders by earliest scheduled date descending', () {
      final schedules = <_ScheduleRow>[
        _ScheduleRow('graph-a', DateTime(2026, 10, 1)),
        _ScheduleRow('graph-c', DateTime(2026, 10, 4)),
        _ScheduleRow('graph-b', DateTime(2026, 10, 5)),
        _ScheduleRow('graph-a', DateTime(2026, 10, 8)),
      ];

      final ids = orderedProgramGraphIds<_ScheduleRow>(
        schedules: schedules,
        graphIdOf: (schedule) => schedule.graphId,
        dateOf: (schedule) => schedule.date,
      );

      expect(ids, ['graph-b', 'graph-c', 'graph-a']);
      expect(schedules.map((schedule) => schedule.graphId).toList(),
          ['graph-a', 'graph-c', 'graph-b', 'graph-a']);
    });

    test('preserves an empty graph ID and handles a single schedule', () {
      final ids = orderedProgramGraphIds<_ScheduleRow>(
        schedules: [_ScheduleRow('', DateTime(2026, 10, 2))],
        graphIdOf: (schedule) => schedule.graphId,
        dateOf: (schedule) => schedule.date,
      );

      expect(ids, ['']);
    });

    test('returns an empty list for no schedules', () {
      final ids = orderedProgramGraphIds<_ScheduleRow>(
        schedules: const <_ScheduleRow>[],
        graphIdOf: (schedule) => schedule.graphId,
        dateOf: (schedule) => schedule.date,
      );

      expect(ids, isEmpty);
    });
  });
}
