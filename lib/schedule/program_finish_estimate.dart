/// Estimates the end time for already-selected pending Program items.
///
/// Callers keep ownership of item selection, average-duration lookup, and record
/// status interpretation. A missing average makes the estimate unknown.
DateTime? estimateProgramFinish<TItem, TRecord>({
  required DateTime now,
  required Iterable<TItem> pendingItems,
  required Duration? Function(TItem item) averageDurationForItem,
  required TRecord? Function(TItem item) latestRecordForItem,
  required bool Function(TRecord? record) isRunning,
  required DateTime? Function(TRecord? record) startedAt,
}) {
  var seconds = 0;
  for (final item in pendingItems) {
    final average = averageDurationForItem(item);
    if (average == null) return null;
    final record = latestRecordForItem(item);
    final start = isRunning(record) ? startedAt(record) : null;
    if (start != null) {
      final elapsed = now.difference(start).inSeconds;
      seconds += (average.inSeconds - elapsed)
          .clamp(0, average.inSeconds)
          .toInt();
    } else {
      seconds += average.inSeconds;
    }
  }
  return now.add(Duration(seconds: seconds));
}
