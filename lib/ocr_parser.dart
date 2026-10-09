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

String _cleanNumber(String value) {
  var v=value.replaceAll(' ','').replaceAll(RegExp(r'[^0-9,.-]'),'');
  final comma=v.lastIndexOf(',');
  final dot=v.lastIndexOf('.');
  if(comma>=0&&dot>=0){
    final decimalIsComma=comma>dot;
    final decimalIndex=decimalIsComma?comma:dot;
    final integer=v.substring(0,decimalIndex).replaceAll(RegExp(r'[,.]'),'');
    final decimals=v.substring(decimalIndex+1).replaceAll(RegExp(r'[,.]'),'');
    return '$integer.$decimals';
  }
  final separator=comma>=0?',':(dot>=0?'.':'');
  if(separator.isEmpty)return v;
  final pieces=v.split(separator);
  if(pieces.length==2&&pieces.last.length<=3)return '${pieces.first}.${pieces.last}';
  if(pieces.length>2){
    final last=pieces.last;
    if(last.length<=3)return '${pieces.take(pieces.length-1).join()}.$last';
  }
  return v.replaceAll(separator,'');
}

double? _money(String value) {
  final normalized = _cleanNumber(value);
  final v = double.tryParse(normalized);
  if (v == null || v <= 0 || v > 1000000) return null;
  return v;
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

  double? amount;
  final totalPatterns = <RegExp>[
    RegExp(r'(?:TOTAL\s+(?:DE\s+PLAT[ĂA]|PLAT[ĂA])?|TOTAL|SUMA\s+DE\s+PLAT[ĂA]|DE\s+PLAT[ĂA])[^0-9]{0,20}([0-9]{1,7}(?:[.,][0-9]{2})?)', caseSensitive: false),
    RegExp(r'([0-9]{1,7}(?:[.,][0-9]{2})?)\s*(?:RON|LEI)\b', caseSensitive: false),
  ];
  for (final re in totalPatterns) {
    final matches = re.allMatches(raw).toList();
    for (final m in matches.reversed) {
      final v = _money(m.group(1) ?? '');
      if (v != null) { amount = v; break; }
    }
    if (amount != null) break;
  }
  if (amount == null) {
    final candidates = RegExp(r'\b([0-9]{1,6}[.,][0-9]{2})\b').allMatches(raw)
        .map((m) => _money(m.group(1) ?? ''))
        .whereType<double>()
        .where((x) => x < 100000)
        .toList();
    if (candidates.isNotEmpty) amount = candidates.reduce((a, b) => a > b ? a : b);
  }

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
