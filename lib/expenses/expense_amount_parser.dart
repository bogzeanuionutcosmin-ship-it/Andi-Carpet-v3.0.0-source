import '../finance/per_diem_money.dart';

/// Parses the expense form's positive lei amount using the shared integer-bani
/// conversion while retaining the form's existing input limits.
int? parseExpenseAmountBani(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final bani = parseLeiToBani(normalized);
  return bani > 0 ? bani : null;
}
