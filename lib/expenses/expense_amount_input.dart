/// Parses a manually entered expense amount into whole bani.
///
/// Keeps the form's existing decimal-text contract and avoids floating point
/// rounding while validating the amount.
int? parseExpenseAmountBani(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final lei = int.tryParse(parts.first);
  if (lei == null) return null;
  final bani = parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
  final total = lei * 100 + bani;
  return total > 0 ? total : null;
}
