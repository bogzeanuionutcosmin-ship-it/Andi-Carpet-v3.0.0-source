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

  test('every Romanian weekday and month remains mapped correctly', () {
    const days = ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'];
    const months = ['ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'];
    for (var day = 1; day <= 7; day++) {
      expect(formatDate(DateTime(2026, 6, day)), '${days[day - 1]}-$day-iunie-2026');
    }
    for (var month = 1; month <= 12; month++) {
      expect(formatMonth(DateTime(2026, month, 1)), '${months[month - 1]}-2026');
    }
  });

  test('formatters preserve midnight, minute truncation and duration sign', () {
    expect(timeText(DateTime(2026, 1, 1)), '00:00');
    expect(timeText(DateTime(2026, 1, 1, 23, 59)), '23:59');
    expect(durationText(Duration.zero), '0h 00 min');
    expect(durationText(const Duration(seconds: 59)), '0h 00 min');
    expect(durationText(const Duration(seconds: -59)), '0h 00 min');
    expect(durationText(const Duration(hours: 25, minutes: 1)), '25h 01 min');
    expect(two(123), '123');
  });

  test('sameDay distinguishes adjacent years and months', () {
    expect(sameDay(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), isFalse);
    expect(sameDay(DateTime(2026, 2, 28), DateTime(2026, 3, 1)), isFalse);
    expect(sameDay(DateTime(2024, 2, 29, 12), DateTime(2024, 2, 29, 0)), isTrue);
  });

  test('sameDay preserves caller timezone calendar semantics', () {
    final utc = DateTime.utc(2026, 10, 18, 23, 30);
    final local = DateTime(2026, 10, 18, 0, 15);
    // This helper compares displayed calendar fields, not instants.
    expect(sameDay(utc, local), isTrue);
    expect(sameDay(utc, DateTime(2026, 10, 19)), isFalse);
  });

  test('formatters do not alter DateTime instances', () {
    final date = DateTime.utc(2026, 12, 31, 23, 59, 59);
    final before = date.microsecondsSinceEpoch;
    expect(formatDate(date), 'joi-31-decembrie-2026');
    expect(formatMonth(date), 'decembrie-2026');
    expect(timeText(date), '23:59');
    expect(date.microsecondsSinceEpoch, before);
    expect(date.isUtc, isTrue);
  });

  test('sameDay compares calendar date without timezone conversion', () {
    expect(sameDay(DateTime(2026, 10, 18, 0), DateTime(2026, 10, 18, 23)), isTrue);
    expect(sameDay(DateTime(2026, 10, 18), DateTime(2026, 10, 19)), isFalse);
  });
}
