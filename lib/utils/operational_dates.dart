part of '../main.dart';

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
