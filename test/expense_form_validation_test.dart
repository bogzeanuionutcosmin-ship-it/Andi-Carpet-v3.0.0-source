import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('document number remains required after trimming', () {
    expect(
      app.expenseDocumentNumberValidationError(null),
      'Numărul documentului este obligatoriu.',
    );
    expect(
      app.expenseDocumentNumberValidationError(''),
      'Numărul documentului este obligatoriu.',
    );
    expect(
      app.expenseDocumentNumberValidationError('   '),
      'Numărul documentului este obligatoriu.',
    );
    expect(app.expenseDocumentNumberValidationError(' INV-1 '), isNull);
  });

  test('amount validation accepts only a parsed positive bani value', () {
    expect(
      app.expenseAmountValidationError(null),
      'Introdu o sumă pozitivă, cu maximum 2 zecimale.',
    );
    expect(app.expenseAmountValidationError(1), isNull);
  });

  test('document date permits exactly one day ahead and rejects later dates', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    expect(app.expenseDateExceedsFutureAllowance(now, now), isFalse);
    expect(
      app.expenseDateExceedsFutureAllowance(now.add(const Duration(days: 1)), now),
      isFalse,
    );
    expect(
      app.expenseDateExceedsFutureAllowance(
        now.add(const Duration(days: 1, microseconds: 1)),
        now,
      ),
      isTrue,
    );
    expect(
      app.expenseDateExceedsFutureAllowance(
        now.subtract(const Duration(days: 1)),
        now,
      ),
      isFalse,
    );
  });
}
