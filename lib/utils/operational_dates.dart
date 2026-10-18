part of '../main.dart';

DateTime operationalWorkDate(DateTime now) {
  final startTonight = DateTime(now.year, now.month, now.day, 23, 30);
  if (!now.isBefore(startTonight)) {
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }
  return DateTime(now.year, now.month, now.day);
}

DateTime workWindowStart(DateTime workDate) => DateTime(workDate.year, workDate.month, workDate.day).subtract(const Duration(days: 1)).add(const Duration(hours: 23, minutes: 30));
DateTime workWindowEnd(DateTime workDate) => DateTime(workDate.year, workDate.month, workDate.day, 9, 30);
bool isInsideWorkWindow(DateTime now, DateTime workDate) => !now.isBefore(workWindowStart(workDate)) && !now.isAfter(workWindowEnd(workDate));
bool recordBelongsToWorkDate(CentralizerRecord r, DateTime workDate) {
  final t = r.startedAt ?? r.waitingStartedAt ?? r.finishedAt ?? r.waitingEndedAt;
  if (t == null) return false;
  // The usual work window is an indicator, not a validity cutoff for real
  // executions. A legitimate START at 13:00 or 22:00 must remain reachable.
  return sameDay(operationalWorkDate(t), workDate);
}

DateTime recordEventTime(CentralizerRecord r) =>
    r.finishedAt ?? r.startedAt ?? r.waitingStartedAt ?? r.waitingEndedAt ?? DateTime(1900);


bool recordHasOpenAttempt(CentralizerRecord r) => r.finishedAt == null &&
    (r.status == WorkAttemptStatus.running || r.status == WorkAttemptStatus.waitingAccess);
