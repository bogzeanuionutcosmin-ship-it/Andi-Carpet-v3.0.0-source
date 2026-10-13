class FiscalOcrData {
  final String rawText;
  final String documentNumber;
  final double? amount;
  final DateTime? date;
  final String supplier;
  final double? liters;
  final double? pricePerLiter;
  final bool looksLikeFuel;
  final double confidence;

  const FiscalOcrData({
    required this.rawText,
    this.documentNumber = '',
    this.amount,
    this.date,
    this.supplier = '',
    this.liters,
    this.pricePerLiter,
    this.looksLikeFuel = false,
    this.confidence = 0,
  });
}

/// Acceptă exclusiv valori monetare valide, nu numere ambigue preluate
/// din prețuri/litri/numere de bon. Conversia folosește bani întregi.
double? _money(String value) {
  final v = value.replaceAll(RegExp(r'[\s\u00A0]'), '');
  if (!RegExp(r'^\d[\d.,]*$').hasMatch(v)) return null;
  final decimal = RegExp(r'[.,]\d{2}$').firstMatch(v);
  final integer = decimal == null ? v : v.substring(0, decimal.start);
  final fractional = decimal == null ? '00' : v.substring(decimal.start + 1);

  if (integer.contains('.') || integer.contains(',')) {
    final grouping = integer.contains('.') ? '.' : ',';
    if (integer.contains(grouping == '.' ? ',' : '.')) return null;
    final groups = integer.split(grouping);
    if (groups.first.isEmpty || groups.first.length > 3 ||
        groups.skip(1).any((g) => g.length != 3)) return null;
  }
  final digits = integer.replaceAll(RegExp(r'[.,]'), '');
  if (digits.length > 7) return null;
  final lei = int.tryParse(digits);
  final bani = int.tryParse(fractional);
  if (lei == null || bani == null) return null;
  final totalBani = lei * 100 + bani;
  if (totalBani <= 0 || totalBani > 100000000) return null;
  return totalBani / 100.0;
}

/// Nu extrage o cifră parțială dintr-o linie mai lungă (TVA, număr
/// document, preț / litru etc.). O sumă trebuie să ocupe întreaga valoare.
double? _moneyLine(String value) {
  final match = RegExp(
    r'^([0-9][0-9.,\s\u00A0]*)(?:\s*(?:LEI|RON))?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  return match == null ? null : _money(match.group(1)!.trim());
}

/// Alege doar un total clar etichetat sau, în lipsa etichetei, o singură
/// valoare izolată cu moneda explicită. Niciodată valoarea MAXIMĂ de pe bon.
double? _extractReceiptTotal(List<String> lines) {
  final labels = RegExp(
    r'^(TOTAL(?:\s+DE\s+PLAT[ĂA]|\s+PLAT[ĂA]|\s+(?:RON|LEI))?|SUMA\s+DE\s+PLAT[ĂA]|DE\s+PLAT[ĂA])\s*[:=\-]?\s*(.*)$',
    caseSensitive: false,
  );
  final totals = <int, Set<double>>{};
  var hasTotalLabel = false;
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final match = labels.firstMatch(line);
    if (match == null) continue;
    hasTotalLabel = true;
    final label = match.group(1)!.toUpperCase();
    var value = match.group(2)!.trim();
    if (value.isEmpty && index + 1 < lines.length) {
      value = lines[index + 1];
    }
    final amount = _moneyLine(value);
    if (amount == null) continue;
    final priority = label.contains('PLAT') ? 2 : 1;
    totals.putIfAbsent(priority, () => <double>{}).add(amount);
  }

  for (final priority in [2, 1]) {
    final candidates = totals[priority];
    if (candidates == null || candidates.isEmpty) continue;
    return candidates.length == 1 ? candidates.single : null;
  }
  if (hasTotalLabel) return null;

  // Fallback sigur: o valoare cu LEI/RON pe o linie separată.
  // „7,25 LEI/L” sau multiple sume nu sunt un total demonstrat.
  final exactCurrency = RegExp(
    r'^([0-9][0-9.,\s\u00A0]*)\s+(?:RON|LEI)$',
    caseSensitive: false,
  );
  final candidates = <double>{};
  for (final line in lines) {
    final match = exactCurrency.firstMatch(line);
    if (match == null) continue;
    final amount = _moneyLine(line);
    if (amount != null) candidates.add(amount);
  }
  return candidates.length == 1 ? candidates.single : null;
}

DateTime? _parseDate(String value) {
  final p = value.replaceAll(RegExp(r'[^0-9]'), '.').split('.').where((x) => x.isNotEmpty).toList();
  if (p.length < 3) return null;
  var a = int.tryParse(p[0]);
  var b = int.tryParse(p[1]);
  var c = int.tryParse(p[2]);
  if (a == null || b == null || c == null) return null;
  if (a > 1900) {
    final y = a; a = c; c = y;
  }
  if (c < 100) c += c >= 70 ? 1900 : 2000;
  if (a < 1 || a > 31 || b < 1 || b > 12 || c < 2000 || c > 2100) return null;
  try { return DateTime(c, b, a); } catch (_) { return null; }
}

FiscalOcrData parseFiscalOcr(String text) {
  final raw = text.replaceAll('\r', '\n');
  final lines = raw.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
  final upper = raw.toUpperCase();

  String supplier = '';
  for (final line in lines.take(12)) {
    final u = line.toUpperCase();
    if (RegExp(r'\b(SRL|S\.R\.L|SA|S\.A\.|PFA|SCS|SC)\b').hasMatch(u) && line.length >= 4) {
      supplier = line;
      break;
    }
  }
  if (supplier.isEmpty && lines.isNotEmpty) {
    supplier = lines.firstWhere((x) => RegExp(r'[A-Za-zĂÂÎȘȚăâîșț]{3}').hasMatch(x), orElse: () => lines.first);
  }

  String docNo = '';
  final numberPatterns = <RegExp>[
    RegExp(r'(?:BON(?:\s+FISCAL)?|FACTUR[ĂA]?|FACT\.?|DOCUMENT|NR\.?)\s*(?:NR\.?)?\s*[:#\-]?\s*([A-Z0-9\-/]{2,})', caseSensitive: false),
    RegExp(r'NR\.?\s*[:#\-]?\s*([A-Z0-9\-/]{3,})', caseSensitive: false),
  ];
  for (final re in numberPatterns) {
    final m = re.firstMatch(raw);
    if (m != null) { docNo = (m.group(1) ?? '').trim(); if (docNo.isNotEmpty) break; }
  }

  DateTime? date;
  final dateMatches = RegExp(r'\b([0-3]?\d[./-][01]?\d[./-](?:20)?\d{2}|20\d{2}[./-][01]?\d[./-][0-3]?\d)\b').allMatches(raw);
  for (final m in dateMatches) {
    date = _parseDate(m.group(1) ?? '');
    if (date != null) break;
  }

  final amount = _extractReceiptTotal(lines);

  final fuel = RegExp(r'\b(MOTORIN[ĂA]|DIESEL|BENZIN[ĂA]|GPL|CARBURANT)\b', caseSensitive: false).hasMatch(upper);
  double? liters;
  double? price;
  final lm = RegExp(r'([0-9]{1,4}(?:[.,][0-9]{1,3})?)\s*(?:L|LITRI)\b', caseSensitive: false).firstMatch(raw);
  if (lm != null) liters = double.tryParse((lm.group(1) ?? '').replaceAll(',', '.'));
  final pm = RegExp(r'([0-9]{1,3}(?:[.,][0-9]{2,3})?)\s*(?:RON|LEI)?\s*/\s*L\b', caseSensitive: false).firstMatch(raw);
  if (pm != null) price = double.tryParse((pm.group(1) ?? '').replaceAll(',', '.'));
  if (price == null && fuel && liters != null && amount != null && liters > 0) {
    final inferred = amount / liters;
    if (inferred > 1 && inferred < 30) price = inferred;
  }

  var score = 0.0;
  if (amount != null) score += .35;
  if (date != null) score += .20;
  if (docNo.isNotEmpty) score += .20;
  if (supplier.isNotEmpty) score += .15;
  if (fuel && (liters != null || price != null)) score += .10;

  return FiscalOcrData(
    rawText: raw.trim(),
    documentNumber: docNo,
    amount: amount,
    date: date,
    supplier: supplier,
    liters: liters,
    pricePerLiter: price,
    looksLikeFuel: fuel,
    confidence: score.clamp(0.0, 1.0),
  );
}
