/// Extrage exclusiv numarul, data si totalul unei facturi.
/// Nu confunda valoarea fara TVA sau randurile de servicii cu totalul.
class InvoiceFields {
  final String invoiceNumber;
  final DateTime? invoiceDate;
  final int? totalBani;
  bool get needsReview => invoiceNumber.isEmpty || invoiceDate == null || totalBani == null;
  const InvoiceFields({required this.invoiceNumber, required this.invoiceDate, required this.totalBani});
}

InvoiceFields parseInvoiceFields(String raw) {
  final lines = raw.split(RegExp(r'[\r\n]+')).map((s) => s.trim()).toList();
  String number = '';
  final explicit = RegExp(
    r'\b(?:FACTUR[ĂA]|INVOICE)\s*(?:FISCAL[ĂA]?\s*)?(?:SERIA\s+([A-Z0-9/-]+)\s*)?(?:NR\.?|NUM[ĂA]R|NO\.?)\s*[:#-]?\s*([A-Z0-9/-]+)',
    caseSensitive: false,
  );
  for (final line in lines) {
    final match = explicit.firstMatch(line);
    if (match != null) {
      final series = match.group(1);
      number = [if (series != null) series, match.group(2)!].join(' ');
      break;
    }
  }
  DateTime? date;
  final datePattern = RegExp(
    r'\b(?:DATA\s+(?:EMITERII|FACTURII)?|EMIS[ĂA]\s+LA|ISSUE\s+DATE)\s*[:#-]?\s*([0-3]?\d[./-][01]?\d[./-](?:20)?\d{2})',
    caseSensitive: false,
  );
  for (final line in lines) {
    final match = datePattern.firstMatch(line);
    if (match == null) continue;
    final parts = match.group(1)!.split(RegExp(r'[./-]'));
    if (parts.length != 3) continue;
    final day = int.tryParse(parts[0]), month = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) continue;
    if (year < 100) year += 2000;
    final candidate = DateTime(year, month, day);
    if (candidate.day == day && candidate.month == month && candidate.year == year) {
      date = candidate;
      break;
    }
  }
  int? total;
  final totalLabel = RegExp(
    r'\b(?:TOTAL\s+(?:DE\s+)?PLAT[ĂA]|TOTAL\s+FACTUR[ĂA]|TOTAL\s+GENERAL|GRAND\s+TOTAL|TOTAL\s+CU\s+TVA)(?=\s|$)',
    caseSensitive: false,
  );
  final moneyAtEnd = RegExp(r'([0-9]{1,7}[.,][0-9]{2})\s*(?:RON|LEI)?\s*$', caseSensitive: false);
  for (final line in lines) {
    if (!totalLabel.hasMatch(line)) continue;
    final match = moneyAtEnd.firstMatch(line);
    if (match == null) continue;
    final p = match.group(1)!.replaceAll(',', '.').split('.');
    final lei = int.tryParse(p[0]), bani = int.tryParse(p[1]);
    if (lei != null && bani != null) total = lei * 100 + bani;
  }
  return InvoiceFields(invoiceNumber: number, invoiceDate: date, totalBani: total);
}
