part of '../main.dart';

/// Returns the intervention records shown for one Dashboard location and work date.
/// Ordering and inclusion match the existing Dashboard behavior.
List<CentralizerRecord> dashboardRecordsForItem(
  Iterable<CentralizerRecord> records, {
  required String teamId,
  required ScheduleItem item,
  required DateTime workDate,
}) {
  final out = records.where((r) =>
    r.teamId == teamId &&
    r.locationId == item.locationId && recordMatchesIntervention(r, item) &&
    (recordHasOpenAttempt(r) || recordBelongsToWorkDate(r, workDate))
  ).toList();
  out.sort((a, b) {
    final active = (recordHasOpenAttempt(a) ? 1 : 0).compareTo(recordHasOpenAttempt(b) ? 1 : 0);
    return active != 0 ? active : recordEventTime(a).compareTo(recordEventTime(b));
  });
  return out;
}

/// Returns completed, timed records used by Dashboard duration history.
List<CentralizerRecord> dashboardCompletedHistory(
  Iterable<CentralizerRecord> records, {
  required String locationId,
}) =>
    records
        .where((r) => r.locationId == locationId && r.completed && r.duration != null)
        .toList();


/// Selects the open running attempts shown in Dashboard, newest event first.
List<CentralizerRecord> dashboardRunningRecords(
  Iterable<CentralizerRecord> records, {
  required String teamId,
}) {
  final selected = records
      .where((record) =>
          record.teamId == teamId &&
          record.status == WorkAttemptStatus.running &&
          record.startedAt != null &&
          record.finishedAt == null)
      .toList();
  selected.sort((a, b) => recordEventTime(b).compareTo(recordEventTime(a)));
  return selected;
}

/// Selects same-team open waiting attempts on the requested operational work date.
List<CentralizerRecord> dashboardWaitingRecords(
  Iterable<CentralizerRecord> records, {
  required String teamId,
  required DateTime workDate,
}) {
  final selected = records
      .where((record) =>
          record.teamId == teamId &&
          recordBelongsToWorkDate(record, workDate) &&
          record.status == WorkAttemptStatus.waitingAccess &&
          record.waitingStartedAt != null &&
          record.waitingEndedAt == null)
      .toList();
  selected.sort((a, b) => recordEventTime(b).compareTo(recordEventTime(a)));
  return selected;
}
