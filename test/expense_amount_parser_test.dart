import 'package:flutter_test/flutter_test.dart';

import '../lib/expenses/expense_amount_parser.dart';

void main() {
  test('converts valid decimal input directly to bani', () {
    const valid = <String, int>{
      '1': 100,
      '12': 1200,
      '1.2': 120,
      '1.23': 123,
      '0,5': 50,
      '1,2': 120,
      ' 12,34 ': 1234,
      '000.01': 1,
      '999999999.99': 99999999999,
    };

    for (final entry in valid.entries) {
      expect(parseExpenseAmountBani(entry.key), entry.value, reason: entry.key);
    }
  });

  test('rejects empty, zero, invalid signs, syntax and precision', () {
    const invalid = <String>[
      '', ' ', '0', '0.00', '0,00', '000', '000,00',
      '-1', '+1', '.5', '1.', '1.234', '1,234',
      '1e3', 'NaN', 'Infinity', '-Infinity',
      '1000000000', 'abc',
    ];

    for (final raw in invalid) {
      expect(parseExpenseAmountBani(raw), isNull, reason: raw);
    }
  });
}
