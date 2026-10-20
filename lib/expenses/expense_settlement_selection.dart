/// Resolves the selected Expenses settlement without changing its order.
///
/// [orderedSettlements] must retain the display order established by
/// ExpensePage: open settlements first, followed by closed settlements.
String? resolveExpenseSettlementId<T>({
  required List<T> orderedSettlements,
  required String? selectedSettlementId,
  required bool Function() hasLegacyData,
  required String legacySettlementKey,
  required String Function(T settlement) idOf,
  required bool Function(T settlement) isClosed,
}) {
  final availableIds = <String>{
    for (final settlement in orderedSettlements) idOf(settlement),
  };

  if (selectedSettlementId != null &&
      (availableIds.contains(selectedSettlementId) ||
          (selectedSettlementId == legacySettlementKey && hasLegacyData()))) {
    return selectedSettlementId;
  }

  for (final settlement in orderedSettlements) {
    if (!isClosed(settlement)) return idOf(settlement);
  }

  if (orderedSettlements.isNotEmpty) return idOf(orderedSettlements.first);
  if (hasLegacyData()) return legacySettlementKey;
  return null;
}
