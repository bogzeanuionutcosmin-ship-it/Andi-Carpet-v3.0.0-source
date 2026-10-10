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
