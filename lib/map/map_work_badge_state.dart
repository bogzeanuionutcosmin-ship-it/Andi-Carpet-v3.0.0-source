part of '../main.dart';

/// The presentation states used by the Map's daily work badge.
enum MapWorkBadgeState { completed, nextOrRunning, notCompleted }

/// Resolves the existing Map badge state for one location.
///
/// The callback keeps record scoping and operational-date filtering at the
/// caller, where the Map already owns those concerns.
MapWorkBadgeState? mapWorkBadgeState({
  required Iterable<WorkSchedule> schedules,
  required String locationId,
  required Iterable<CentralizerRecord> Function(String locationId, String teamId)
      recordsForLocation,
}) {
  var assignments = 0;
  var finishedAssignments = 0;
  var nextOrRunning = false;

  for (final day in schedules) {
    final ordered = [...day.items]
      ..sort((a, b) => a.order.compareTo(b.order));
    ScheduleItem? nextItem;

    for (final item in ordered) {
      final records = recordsForLocation(item.locationId, day.teamId);
      final done = records.any((record) => record.completed);
      final running = records.any((record) =>
          record.status == WorkAttemptStatus.running ||
          record.status == WorkAttemptStatus.waitingAccess);
      final cancelled = records.isNotEmpty &&
          records.every((record) =>
              record.status == WorkAttemptStatus.refused ||
              record.status == WorkAttemptStatus.notCompleted);

      if (item.locationId == locationId) {
        assignments++;
        if (done) finishedAssignments++;
        if (!done && running) nextOrRunning = true;
      }
      if (nextItem == null && !done && !cancelled) nextItem = item;
    }
    if (nextItem?.locationId == locationId) nextOrRunning = true;
  }

  if (assignments == 0) return null;
  // A completed assignment stays green unless another assignment is pending.
  if (finishedAssignments == assignments) return MapWorkBadgeState.completed;
  if (nextOrRunning) return MapWorkBadgeState.nextOrRunning;
  return MapWorkBadgeState.notCompleted;
}
