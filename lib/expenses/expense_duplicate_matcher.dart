import '../utils/date_formatters.dart';

/// Returns the first existing expense that matches the legacy duplicate policy.
///
/// Field selectors keep the comparison independent of the application's
/// expense model, while preserving the original team, settlement, fingerprint,
/// document number, date, and amount checks.
T? findPotentialExpenseDuplicate<T>({
  required Iterable<T> existing,
  required T candidate,
  required String Function(T entry) teamId,
  required String? Function(T entry) settlementId,
  required String Function(T entry) imageFingerprint,
  required String Function(T entry) documentNumber,
  required DateTime Function(T entry) date,
  required double Function(T entry) amount,
}) {
  for (final entry in existing) {
    if (teamId(entry) != teamId(candidate)) continue;
    final sameSettlement =
        (settlementId(entry) ?? '') == (settlementId(candidate) ?? '');
    if (!sameSettlement) continue;
    final candidateFingerprint = imageFingerprint(candidate);
    if (candidateFingerprint.isNotEmpty &&
        imageFingerprint(entry) == candidateFingerprint) {
      return entry;
    }
    final candidateDocumentNumber =
        _normalizedDocumentNumber(documentNumber(candidate));
    final existingDocumentNumber =
        _normalizedDocumentNumber(documentNumber(entry));
    if (candidateDocumentNumber.isNotEmpty &&
        candidateDocumentNumber == existingDocumentNumber &&
        sameDay(date(candidate), date(entry)) &&
        (amount(candidate) - amount(entry)).abs() < .02) {
      return entry;
    }
  }
  return null;
}

String _normalizedDocumentNumber(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
