/// Extrage conservator valoarea cazării din facturi HoReCa.
/// Datele ambigue nu sunt completate din totalul facturii.
class AccommodationInvoiceResult {
  final bool containsAccommodation;
  final int? accommodationAmountBani;
  final bool needsReview;
  final List<String> matchedLines;

  const AccommodationInvoiceResult({
    required this.containsAccommodation,
    required this.accommodationAmountBani,
    required this.needsReview,
    required this.matchedLines,
  });
}

final _accommodationLabel = RegExp(
  r'CAZARE|CAMER[ĂA]|NOAPTE\s+CAZARE|SERVICII\s+HOTELIERE|ACCOMMODATION|ROOM\s+CHARGE|LODGING',
  caseSensitive: false,
);
final _excludedSummary = RegExp(
  r'^(?:TOTAL|SUBTOTAL|TVA|REST|PLAT[ĂA]|DISCOUNT|REDUCERE)\\b',
  caseSensitive: false,
);
final _money = RegExp(
  r'([0-9]{1,7}[.,][0-9]{2})\\s*(?:RON|LEI)?\\s*$',
  caseSensitive: false,
);

AccommodationInvoiceResult classifyAccommodationInvoice(String rawText) {
  final matched = <String>[];
  var bani = 0;
  var ambiguous = false;
  for (final original in rawText.split(RegExp(r'[\\r\\n]+'))) {
    final line = original.trim();
    if (!_accommodationLabel.hasMatch(line) || _excludedSummary.hasMatch(line)) continue;
    matched.add(line);
    final m = _money.firstMatch(line);
    if (m == null) {
      ambiguous = true;
      continue;
    }
    final parts = m.group(1)!.replaceAll(',', '.').split('.');
    final lei = int.tryParse(parts[0]);
    final cents = int.tryParse(parts[1]);
    if (lei == null || cents == null) {
      ambiguous = true;
      continue;
    }
    bani += lei * 100 + cents;
  }
  return AccommodationInvoiceResult(
    containsAccommodation: matched.isNotEmpty,
    accommodationAmountBani: matched.isEmpty ? 0 : (ambiguous ? null : bani),
    needsReview: ambiguous || matched.isEmpty,
    matchedLines: List.unmodifiable(matched),
  );
}
