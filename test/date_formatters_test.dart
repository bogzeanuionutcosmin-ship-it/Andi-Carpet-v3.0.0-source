import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/date_formatters.dart';

void main() {
  test('Romanian date and month formats remain stable', () {
    final date = DateTime(2026, 10, 18);
    expect(formatDate(date), 'duminică-18-octombrie-2026');
    expect(formatMonth(date), 'octombrie-2026');
    expect(formatDate(DateTime(2026, 1, 5)), 'luni-5-ianuarie-2026');
  });

  test('time and duration formatting retain null and negative behavior', () {
    expect(two(3), '03');
    expect(timeText(null), '--:--');
    expect(timeText(DateTime(2026, 10, 18, 9, 7)), '09:07');
    expect(durationText(null), '--');
    expect(durationText(const Duration(minutes: 125)), '2h 05 min');
    expect(durationText(const Duration(minutes: -65)), '1h 05 min');
  });

  test('sameDay compares calendar date without timezone conversion', () {
    expect(sameDay(DateTime(2026, 10, 18, 0), DateTime(2026, 10, 18, 23)), isTrue);
    expect(sameDay(DateTime(2026, 10, 18), DateTime(2026, 10, 19)), isFalse);
  });
}
