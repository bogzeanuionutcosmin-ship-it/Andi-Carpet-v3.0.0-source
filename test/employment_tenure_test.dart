import 'package:flutter_test/flutter_test.dart';

import '../lib/profile/employment_tenure.dart';

void main() {
  test('future hire dates produce zero tenure', () {
    expect(
      calculateEmploymentParts(
        DateTime(2026, 10, 21),
        now: DateTime(2026, 10, 20),
      ),
      (years: 0, months: 0, days: 0, totalDays: 0),
    );
  });

  test('end-of-month starts clamp to the last day of shorter months', () {
    expect(
      calculateEmploymentParts(
        DateTime(2025, 1, 31),
        now: DateTime(2025, 2, 28),
      ),
      (years: 0, months: 1, days: 0, totalDays: 28),
    );
    expect(
      calculateEmploymentParts(
        DateTime(2025, 1, 31),
        now: DateTime(2025, 2, 27),
      ),
      (years: 0, months: 0, days: 27, totalDays: 27),
    );
  });

  test('leap-year hire dates reach one year on the clamped anniversary', () {
    expect(
      calculateEmploymentParts(
        DateTime(2024, 2, 29),
        now: DateTime(2025, 2, 28),
      ),
      (years: 1, months: 0, days: 0, totalDays: 365),
    );
  });

  test('reports complete years, months and remaining days', () {
    expect(
      calculateEmploymentParts(
        DateTime(2023, 5, 10),
        now: DateTime(2026, 10, 20),
      ),
      (years: 3, months: 5, days: 10, totalDays: 1259),
    );
  });
}
