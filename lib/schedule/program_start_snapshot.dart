part of '../main.dart';

/// Builds the same unsaved Program schedule copies used when START is
/// confirmed. Persistence and user-facing feedback stay with ProgramPage.
List<WorkSchedule> buildStartedProgramScheduleSnapshot({
  required Iterable<WorkSchedule> schedules,
  required String departureName,
  required double departureLatitude,
  required double departureLongitude,
  required String returnName,
  required double returnLatitude,
  required double returnLongitude,
}) {
  final items = schedules.map(cloneWorkSchedule).toList();
  for (final schedule in items) {
    schedule.started = true;
    schedule.closed = false;
    schedule.paused = false;
    schedule.departureName = departureName;
    schedule.departureLatitude = departureLatitude;
    schedule.departureLongitude = departureLongitude;
    schedule.returnName = returnName;
    schedule.returnLatitude = returnLatitude;
    schedule.returnLongitude = returnLongitude;
  }
  return items;
}
