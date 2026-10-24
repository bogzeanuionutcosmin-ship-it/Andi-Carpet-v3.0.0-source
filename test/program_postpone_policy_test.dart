import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/schedule/program_postpone_policy.dart';

class _Day {
  _Day(this.id, this.date);
  final String id;
  DateTime date;

  _Day copy() => _Day(id, date);
}

void main() {
  group('postponeProgramSchedules', () {
    test('includes the selected calendar date and shifts affected days by one day', () {
      final days = <_Day>[
        _Day('before', DateTime(2026, 10, 20)),
        _Day('selected', DateTime(2026, 10, 21)),
        _Day('after', DateTime(2026, 10, 22)),
      ];

      final affected = postponeProgramSchedules<_Day>(
        schedules: days,
        startDate: DateTime(2026, 10, 21, 18, 30),
        dateOf: (day) => day.date,
        clone: (day) => day.copy(),
        setDate: (day, date) => day.date = date,
      );

      expect(affected.map((day) => day.id), <String>['after', 'selected']);
      expect(
        affected.map((day) => day.date),
        <DateTime>[DateTime(2026, 10, 23), DateTime(2026, 10, 22)],
      );
      expect(days.map((day) => day.date), <DateTime>[
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 22),
      ]);
    });

    test('returns no schedules when every day is before the selected date', () {
      final days = <_Day>[
        _Day('first', DateTime(2026, 10, 19)),
        _Day('second', DateTime(2026, 10, 20)),
      ];

      final affected = postponeProgramSchedules<_Day>(
        schedules: days,
        startDate: DateTime(2026, 10, 21),
        dateOf: (day) => day.date,
        clone: (day) => day.copy(),
        setDate: (day, date) => day.date = date,
      );

      expect(affected, isEmpty);
      expect(days.map((day) => day.date), <DateTime>[
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
      ]);
    });

    test('normalizes schedule dates before adding one day across month boundaries', () {
      final days = <_Day>[_Day('last-day', DateTime(2026, 10, 31, 23, 45))];

      final affected = postponeProgramSchedules<_Day>(
        schedules: days,
        startDate: DateTime(2026, 10, 31),
        dateOf: (day) => day.date,
        clone: (day) => day.copy(),
        setDate: (day, date) => day.date = date,
      );

      expect(affected.single.date, DateTime(2026, 11, 1));
      expect(days.single.date, DateTime(2026, 10, 31, 23, 45));
    });
  });
}
