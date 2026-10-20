/// Selects the exact expense rows currently included by the decont PDF.
///
/// Settlement matching, first-seen ID reconciliation, finite/nonnegative
/// amounts, and ascending date order are preserved through caller accessors.
List<T> selectDecontPdfExpenses<T>({
  required Iterable<T> expenses,
  required String teamId,
  String? selectedSettlementId,
  bool legacyOnly = false,
  required String Function(T expense) teamIdOf,
  required bool Function(T expense) confirmedOf,
  required double Function(T expense) amountOf,
  required String? Function(T expense) settlementIdOf,
  required String Function(T expense) idOf,
  required DateTime Function(T expense) dateOf,
}) {
  bool matchesSettlement(String? id) {
    if (selectedSettlementId != null) return id == selectedSettlementId;
    if (legacyOnly) return id == null || id.isEmpty;
    return true;
  }

  final seenIds = <String>{};
  return expenses.where((expense) {
    final amount = amountOf(expense);
    return teamIdOf(expense) == teamId &&
        confirmedOf(expense) &&
        amount.isFinite &&
        amount >= 0 &&
        matchesSettlement(settlementIdOf(expense)) &&
        seenIds.add(idOf(expense));
  }).toList()
    ..sort((a, b) => dateOf(a).compareTo(dateOf(b)));
}

/// Selects the exact received per-diem rows currently included by the decont
/// PDF. The caller supplies the existing persisted-status check; this helper
/// does not calculate per-diem rates or amounts.
List<T> selectDecontPdfPerDiems<T>({
  required Iterable<T> entries,
  required String teamId,
  String? selectedSettlementId,
  bool legacyOnly = false,
  required String Function(T entry) teamIdOf,
  required bool Function(T entry) confirmedOf,
  required bool Function(T entry) receivedOf,
  required double? Function(T entry) actualAmountOf,
  required String? Function(T entry) settlementIdOf,
  required String Function(T entry) idOf,
  required DateTime Function(T entry) dateOf,
}) {
  bool matchesSettlement(String? id) {
    if (selectedSettlementId != null) return id == selectedSettlementId;
    if (legacyOnly) return id == null || id.isEmpty;
    return true;
  }

  final seenIds = <String>{};
  return entries.where((entry) {
    final amount = actualAmountOf(entry);
    return teamIdOf(entry) == teamId &&
        confirmedOf(entry) &&
        receivedOf(entry) &&
        amount != null &&
        amount.isFinite &&
        amount >= 0 &&
        matchesSettlement(settlementIdOf(entry)) &&
        seenIds.add(idOf(entry));
  }).toList()
    ..sort((a, b) => dateOf(a).compareTo(dateOf(b)));
}

/// Reconciles received transfer entries shown and totaled by the decont PDF.
List<T> selectDecontPdfReceivedEntries<T>({
  required Iterable<T> entries,
  required double Function(T entry) amountOf,
  required String Function(T entry) idOf,
}) {
  final seenIds = <String>{};
  return entries.where((entry) {
    final amount = amountOf(entry);
    return amount.isFinite && amount >= 0 && seenIds.add(idOf(entry));
  }).toList();
}
