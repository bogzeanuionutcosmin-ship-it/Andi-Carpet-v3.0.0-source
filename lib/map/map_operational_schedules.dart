/// Returns the started schedules that the Map includes for today's work day.
/// Closed schedules intentionally remain eligible so completed markers stay
/// visible after the graph is closed.
List<T> todayMapOperationalSchedules<T>(
  Iterable<T> schedules, {
  required bool isAdmin,
  required String? teamId,
  required bool Function(T) startedOf,
  required bool Function(T) isWorkDayOf,
  required String Function(T) teamIdOf,
}) =>
    schedules
        .where((schedule) =>
            startedOf(schedule) &&
            isWorkDayOf(schedule) &&
            (isAdmin ||
                (teamId != null && teamIdOf(schedule) == teamId)))
        .toList();
