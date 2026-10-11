import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  group('Operational work day and overnight schedule', () {
    test('switches operational date at 23:30', () {
      expect(app.operationalWorkDate(DateTime(2026, 10, 10, 23, 29)),
          DateTime(2026, 10, 10));
      expect(app.operationalWorkDate(DateTime(2026, 10, 10, 23, 30)),
          DateTime(2026, 10, 11));
      expect(app.operationalWorkDate(DateTime(2026, 10, 11, 2)),
          DateTime(2026, 10, 11));
    });

    test('work window spans midnight and includes boundaries', () {
      final day = DateTime(2026, 10, 11);
      expect(app.workWindowStart(day), DateTime(2026, 10, 10, 23, 30));
      expect(app.workWindowEnd(day), DateTime(2026, 10, 11, 9, 30));
      expect(app.isInsideWorkWindow(DateTime(2026, 10, 10, 23, 30), day), isTrue);
      expect(app.isInsideWorkWindow(DateTime(2026, 10, 11, 9, 30), day), isTrue);
      expect(app.isInsideWorkWindow(DateTime(2026, 10, 10, 23, 29), day), isFalse);
      expect(app.isInsideWorkWindow(DateTime(2026, 10, 11, 9, 31), day), isFalse);
    });

    test('day matching ignores clock time', () {
      expect(app.sameDay(DateTime(2026, 10, 11, 0), DateTime(2026, 10, 11, 23)), isTrue);
      expect(app.sameDay(DateTime(2026, 10, 10, 23), DateTime(2026, 10, 11)), isFalse);
    });
  });

  group('Dashboard display helpers', () {
    test('formats Romanian dates and months', () {
      expect(app.formatDate(DateTime(2026, 10, 11)), 'duminică-11-octombrie-2026');
      expect(app.formatMonth(DateTime(2026, 1, 2)), 'ianuarie-2026');
    });

    test('formats missing, short and overnight durations', () {
      expect(app.durationText(null), '--');
      expect(app.durationText(const Duration(minutes: 5)), '0h 05 min');
      expect(app.durationText(const Duration(hours: 9, minutes: 30)), '9h 30 min');
    });

    test('formats missing and zero-padded clock times', () {
      expect(app.timeText(null), '--:--');
      expect(app.timeText(DateTime(2026, 10, 11, 2, 7)), '02:07');
    });
  });
}
