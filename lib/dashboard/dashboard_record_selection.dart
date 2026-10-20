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
    r.locationId == item.locationId &&
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
