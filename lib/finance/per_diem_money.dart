/// PATCH 24: conversion without floating-point rounding errors.
int parseLeiToBani(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) throw FormatException('Sumă invalidă', input);
  final lei = int.parse(match.group(1)!);
  final fractional = (match.group(2) ?? '').padRight(2, '0');
  final bani = lei * 100 + (fractional.isEmpty ? 0 : int.parse(fractional));
  if (bani < 0 || bani > 100000000000) throw RangeError('Sumă în afara limitelor');
  return bani;
}
String formatBani(int bani) {
  final negative = bani < 0 ? '-' : '';
  final absValue = bani.abs();
  return '$negative${absValue ~/ 100},${(absValue % 100).toString().padLeft(2, '0')} lei';
}

// PATCH 63–70: validare exactă a sumelor monetare (maxim două zecimale).
// Evită rotunjirea implicită a unei sume introduse greșit.
int? parsePerDiemBani(String raw, {bool allowZero = true}) {
  final value = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final lei = int.tryParse(parts[0]);
  if (lei == null || lei > 100000000) return null;
  final bani = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final total = lei * 100 + bani;
  if (!allowZero && total == 0) return null;
  return total;
}
