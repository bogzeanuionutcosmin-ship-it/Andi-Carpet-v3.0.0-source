import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/fuel_receipt_learning.dart';
import 'package:andi_carpeta/ocr_parser.dart';

void main() {
  final fixtures = (jsonDecode(
    File('test/fixtures/fuel_receipts_synthetic.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  for (final fixture in fixtures) {
    final label = '${fixture['brand']} / ${fixture['case']}';
    test('Learning sintetic: $label', () {
      expect(fixture['source'], 'synthetic');
      final raw = fixture['rawText'] as String;
      final expected = fixture['expected'] as Map<String, dynamic>;
      final fuel = classifyFuelReceipt(raw);
      final ocr = parseFiscalOcr(raw);
      expect(fuel.containsFuel, expected['containsFuel']);
      expect(fuel.fuelAmountBani, expected['fuelAmountBani']);
      expect(fuel.needsReview, expected['needsReview']);
      expect(ocr.documentNumber, expected['bf']);
      expect(ocr.date?.toIso8601String().substring(0, 10), expected['date']);
      if (fuel.containsFuel) {
        expect(ocr.amount,
            expected['fuelAmountBani'] == null ? null : (expected['fuelAmountBani'] as int) / 100);
      }
    });
  }
}
