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
