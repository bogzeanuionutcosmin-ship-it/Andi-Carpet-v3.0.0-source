/// Selects schedule items that still need attention, preserving their input order.
///
/// Callers own record lookup and status interpretation. This keeps operational
/// work-date selection and persistence outside the policy.
List<TItem> pendingProgramItems<TItem, TRecord>({
  required Iterable<TItem> items,
  required TRecord? Function(TItem item) latestRecordForItem,
  required bool Function(TRecord? record) isTerminal,
  required bool Function(TRecord? record) isActive,
  bool includeActive = true,
}) {
  final pending = <TItem>[];
  for (final item in items) {
    final record = latestRecordForItem(item);
    if (isTerminal(record)) continue;
    if (!includeActive && isActive(record)) continue;
    pending.add(item);
  }
  return pending;
}
