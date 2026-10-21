part of '../main.dart';

/// Generated once when a new planned visit is created. Order, date and team
/// transfers never regenerate this identity. Legacy visits remain explicit.
String newInterventionId() => base64Url.encode(List<int>.generate(
  16, (_) => math.Random.secure().nextInt(256))).replaceAll('=', '');

bool recordMatchesIntervention(CentralizerRecord record, ScheduleItem item) =>
  item.interventionId.isNotEmpty
    ? record.interventionId == item.interventionId
    : record.interventionId.isEmpty && record.locationId == item.locationId;

/// Both manual and arrival START choose the same slot after an uncertain ACK
/// or a process restart. A finished refusal consumes a slot; waiting does not.
String nextInterventionRecordId(ScheduleItem item, Iterable<CentralizerRecord> records) {
  if (item.interventionId.isEmpty) return idNow();
  final finished = records.where((r) => r.interventionId == item.interventionId &&
    r.finishedAt != null).length;
  return 'iv_${item.interventionId}_${finished + 1}';
}
