import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/per_diem_money.dart';

void main() {
  group('parsePerDiemBani', () {
    test('normalizes whitespace and comma decimals into integer bani', () {
      expect(parsePerDiemBani(' 12,3 '), 1230);
      expect(parsePerDiemBani('12.34'), 1234);
      expect(parsePerDiemBani('12'), 1200);
    });

    test('accepts zero only when allowed', () {
      expect(parsePerDiemBani('0'), 0);
      expect(parsePerDiemBani('0,00'), 0);
      expect(parsePerDiemBani('0', allowZero: false), isNull);
      expect(parsePerDiemBani('0,00', allowZero: false), isNull);
    });

    test('enforces the existing integer and decimal bounds', () {
      expect(parsePerDiemBani('100000000'), 10000000000);
      expect(parsePerDiemBani('100000000,99'), 10000000099);
      expect(parsePerDiemBani('100000001'), isNull);
      expect(parsePerDiemBani('1234567890'), isNull);
      expect(parsePerDiemBani('1.234'), isNull);
      expect(parsePerDiemBani('1.'), isNull);
    });

    test('rejects blank, signed, and non-numeric inputs', () {
      for (final value in ['', '  ', '-1', '+1', '.5', '1a', '1,2,3']) {
        expect(parsePerDiemBani(value), isNull, reason: 'input: $value');
      }
    });
  });
}
