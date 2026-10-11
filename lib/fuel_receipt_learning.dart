/// Extragere conservatoare a valorii carburantului din liniile unui bon.
/// Nu foloseste TOTAL-ul bonului drept suma de combustibil.
class FuelReceiptLearningResult {
  final bool containsFuel;
  final int? fuelAmountBani;
  final bool needsReview;
  final List<String> matchedLines;
  const FuelReceiptLearningResult({
    required this.containsFuel,
    required this.fuelAmountBani,
    required this.needsReview,
    required this.matchedLines,
  });
}

final _fuelName = RegExp(
  r'\\b(?:MOTORIN[ĂA]|DIESEL|BENZIN[ĂA]|GASOLINA|GPL|CARBURANT|ADBLUE)\\b',
  caseSensitive: false,
);
final _moneyAtEnd = RegExp(r'([0-9]{1,7}[.,][0-9]{2})\\s*(?:RON|LEI)?\\s*$',
    caseSensitive: false);
final _summary = RegExp(
  r'\\b(?:TOTAL|SUBTOTAL|TVA|REST|CARD|NUMERAR|PLATA|PLATĂ|REDUCERE|DISCOUNT|PRET|PREȚ|LITRI)\\b',
  caseSensitive: false,
);

FuelReceiptLearningResult classifyFuelReceipt(String rawText) {
  final matched = <String>[];
  var sumBani = 0;
  var missingAmount = false;
  for (final original in rawText.split(RegExp(r'[\\r\\n]+'))) {
    final line = original.trim();
    if (!_fuelName.hasMatch(line) || _summary.hasMatch(line)) continue;
    matched.add(line);
    final match = _moneyAtEnd.firstMatch(line);
    if (match == null) {
      missingAmount = true;
      continue;
    }
    final parts = match.group(1)!.replaceAll(',', '.').split('.');
    final lei = int.tryParse(parts[0]);
    final bani = int.tryParse(parts[1]);
    if (lei == null || bani == null) {
      missingAmount = true;
      continue;
    }
    sumBani += lei * 100 + bani;
  }
  return FuelReceiptLearningResult(
    containsFuel: matched.isNotEmpty,
    fuelAmountBani: matched.isEmpty ? 0 : (missingAmount ? null : sumBani),
    needsReview: missingAmount || matched.isEmpty,
    matchedLines: List.unmodifiable(matched),
  );
}
