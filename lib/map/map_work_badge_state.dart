/// The existing Map marker badge state for one location's assignments.
enum MapWorkBadgeState { completed, nextOrRunning, notCompleted }

/// Computes the Map badge state without depending on widgets or app models.
/// A null result means the target location has no assignments in the supplied
/// schedules.
MapWorkBadgeState? mapWorkBadgeState<TSchedule, TItem, TRecord, TStatus>(
  Iterable<TSchedule> schedules, {
  required String targetLocationId,
  required Iterable<TItem> Function(TSchedule) itemsOf,
  required int Function(TItem) orderOf,
  required String Function(TSchedule) teamIdOf,
  required String Function(TItem) locationIdOf,
  required Iterable<TRecord> Function(String locationId, String teamId)
      recordsFor,
  required bool Function(TRecord) completedOf,
  required TStatus Function(TRecord) statusOf,
  required TStatus runningStatus,
  required TStatus waitingStatus,
  required TStatus refusedStatus,
  required TStatus notCompletedStatus,
}) {
  var assignments = 0;
  var finishedAssignments = 0;
  var nextOrRunning = false;

  for (final schedule in schedules) {
    final orderedItems = itemsOf(schedule).toList()
      ..sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    String? nextItemLocationId;

    for (final item in orderedItems) {
      final locationId = locationIdOf(item);
      final records = recordsFor(locationId, teamIdOf(schedule)).toList();
      final done = records.any(completedOf);
      final running = records.any((record) {
        final status = statusOf(record);
        return status == runningStatus || status == waitingStatus;
      });
      final cancelled = records.isNotEmpty && records.every((record) {
        final status = statusOf(record);
        return status == refusedStatus || status == notCompletedStatus;
      });

      if (locationId == targetLocationId) {
        assignments++;
        if (done) finishedAssignments++;
        if (!done && running) nextOrRunning = true;
      }

      if (nextItemLocationId == null && !done && !cancelled) {
        nextItemLocationId = locationId;
      }
    }

    if (nextItemLocationId == targetLocationId) nextOrRunning = true;
  }

  if (assignments == 0) return null;
  // Keep green hidden when this location still has another unfinished visit.
  if (finishedAssignments == assignments) return MapWorkBadgeState.completed;
  if (nextOrRunning) return MapWorkBadgeState.nextOrRunning;
  return MapWorkBadgeState.notCompleted;
}
