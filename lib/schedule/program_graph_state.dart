part of '../main.dart';

/// Builds an isolated schedule snapshot with only the requested graph-state
/// flags changed. Persistence and user-visible effects remain with ProgramPage.
List<WorkSchedule> projectProgramGraphState({
  required Iterable<WorkSchedule> schedules,
  required WorkSchedule Function(WorkSchedule) clone,
  bool? started,
  bool? closed,
  bool? paused,
}) {
  final updated = schedules.map(clone).toList();
  for (final schedule in updated) {
    if (started != null) schedule.started = started;
    if (closed != null) schedule.closed = closed;
    if (paused != null) schedule.paused = paused;
  }
  return updated;
}
