import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/expenses/expense_amount_input.dart';

void main() {
  test('converts valid decimal input directly to bani', () {
    const valid = <String, int>{
      '1': 100,
      '12': 1200,
      '1.2': 120,
      '1.23': 123,
      '1,2': 120,
      '  12,34  ': 1234,
      '000.01': 1,
      '999999999.99': 99999999999,
    };

    for (final entry in valid.entries) {
      expect(parseExpenseAmountBani(entry.key), entry.value, reason: entry.key);
    }
  });

  test('rejects empty, zero and unsupported monetary syntax', () {
    const invalid = <String>[
      '', ' ', '0', '0.00', '000', '000,00',
      '-1', '+1', '1e2', 'NaN', 'Infinity', '-Infinity',
      '1.001', '1,234', '1234567890', '.50', '1.',
    ];

    for (final input in invalid) {
      expect(parseExpenseAmountBani(input), isNull, reason: input);
    }
  });
}
