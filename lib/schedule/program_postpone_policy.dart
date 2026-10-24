/// Returns cloned schedule entries on or after [startDate], shifted forward
/// by one calendar day and ordered from latest date to earliest date.
///
/// Callers keep persistence and user feedback at their existing boundary.
List<T> postponeProgramSchedules<T>({
  required Iterable<T> schedules,
  required DateTime startDate,
  required DateTime Function(T schedule) dateOf,
  required T Function(T schedule) clone,
  required void Function(T schedule, DateTime date) setDate,
}) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final affected = schedules
      .where((schedule) => !dateOf(schedule).isBefore(start))
      .map(clone)
      .toList()
    ..sort((a, b) => dateOf(b).compareTo(dateOf(a)));

  for (final schedule in affected) {
    final date = dateOf(schedule);
    setDate(
      schedule,
      DateTime(date.year, date.month, date.day).add(const Duration(days: 1)),
    );
  }
  return affected;
}
