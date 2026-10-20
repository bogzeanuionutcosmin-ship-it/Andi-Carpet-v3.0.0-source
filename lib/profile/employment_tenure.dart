import 'dart:math' as math;

({int years, int months, int days, int totalDays}) calculateEmploymentParts(
  DateTime start, {
  required DateTime now,
}) {
  if (start.isAfter(now)) return (years: 0, months: 0, days: 0, totalDays: 0);

  var totalMonths = (now.year - start.year) * 12 + (now.month - start.month);
  DateTime anchorFor(int months) {
    final year = start.year + ((start.month - 1 + months) ~/ 12);
    final month = ((start.month - 1 + months) % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = math.min(start.day, lastDay);
    return DateTime(year, month, day);
  }

  var anchor = anchorFor(totalMonths);
  if (anchor.isAfter(now)) {
    totalMonths--;
    anchor = anchorFor(totalMonths);
  }
  return (
    years: totalMonths ~/ 12,
    months: totalMonths % 12,
    days: now.difference(anchor).inDays,
    totalDays: now.difference(start).inDays,
  );
}
