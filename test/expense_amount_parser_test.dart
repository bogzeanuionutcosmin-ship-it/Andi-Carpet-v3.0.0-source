import 'package:flutter_test/flutter_test.dart';

import '../lib/expenses/expense_amount_parser.dart';

void main() {
  test('parses positive lei amounts into integer bani', () {
    expect(parseExpenseAmountBani('1'), 100);
    expect(parseExpenseAmountBani('0,5'), 50);
    expect(parseExpenseAmountBani(' 12,34 '), 1234);
    expect(parseExpenseAmountBani('999999999.99'), 99999999999);
  });

  test('rejects zero, negative, malformed and over-precision values', () {
    for (final raw in <String>[
      '',
      '0',
      '0,00',
      '-1',
      '+1',
      '.5',
      '1.',
      '1.234',
      '1e3',
      '1000000000',
      'abc',
    ]) {
      expect(parseExpenseAmountBani(raw), isNull, reason: raw);
    }
  });
}
