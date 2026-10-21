part of '../main.dart';

class ProgramGraphClosureReadiness {
  final List<String> blockers;
  const ProgramGraphClosureReadiness(this.blockers);
  bool get canClose => blockers.isEmpty;
}

/// Checks every carpet intervention in every day of a graph before official
/// STOP. A refused or in-progress attempt remains open; only a completed
/// attempt or a not-completed result with a recorded explanation is final.
/// Planned facade work is additional, but it does not replace the primary
/// carpet intervention represented by its ScheduleItem.
ProgramGraphClosureReadiness programGraphClosureReadiness({
  required Iterable<WorkSchedule> schedules,
  required Iterable<CentralizerRecord> records,
}) {
  final allRecords = records.toList(growable: false);
  final blockers = <String>[];
  for (final schedule in schedules) {
    for (final item in schedule.items) {
      final matching = allRecords.where((record) =>
        record.teamId == schedule.teamId &&
        record.locationId == item.locationId &&
        recordBelongsToWorkDate(record, schedule.date));
      final attempts = matching.toList()
        ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
      final latest = attempts.isEmpty ? null : attempts.last;
      final completed = latest?.status == WorkAttemptStatus.completed &&
          latest!.completed;
      final explainedNotCompleted =
          latest?.status == WorkAttemptStatus.notCompleted &&
          latest?.finishedAt != null &&
          (latest?.refusalReason?.trim().isNotEmpty ?? false);
      if (!completed && !explainedNotCompleted) {
        final status = latest == null
            ? 'neîncepută'
            : latest.status == WorkAttemptStatus.refused
                ? 'refuzată, încă restantă'
                : latest.status == WorkAttemptStatus.notCompleted
                    ? 'nerealizată fără explicație'
                    : 'în desfășurare';
        blockers.add('${item.locationNameSnapshot} · ${formatDate(schedule.date)} · $status');
      }
    }
  }
  return ProgramGraphClosureReadiness(List.unmodifiable(blockers));
}

/// Identifies complete graphs for a reminder, without mutating or persisting
/// schedules. The current work day anchors the reminder; readiness covers all
/// days of the same team's graph, including future or postponed interventions.
List<WorkSchedule> programGraphsReadyForOfficialStop({
  required Iterable<WorkSchedule> schedules,
  required Iterable<CentralizerRecord> records,
  required String teamId,
  required DateTime workDate,
}) {
  final teamSchedules=schedules.where((day)=>day.teamId==teamId).toList();
  final allRecords=records.toList();
  final candidates=teamSchedules.where((day)=>
    day.started && !day.closed && sameDay(day.date,workDate));
  final seen=<String>{};
  final ready=<WorkSchedule>[];
  for(final candidate in candidates){
    if(!seen.add(candidate.graphId))continue;
    final graphDays=teamSchedules.where((day)=>day.graphId==candidate.graphId).toList();
    if(!graphDays.any((day)=>day.items.isNotEmpty))continue;
    if(programGraphClosureReadiness(schedules:graphDays,records:allRecords).canClose){
      ready.add(candidate);
    }
  }
  return List.unmodifiable(ready);
}
