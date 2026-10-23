import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ocr_parser.dart';

void main() {
  test('OCR parser extrage datele uzuale din bon', () {
    final result = parseFiscalOcr('''
SC EXEMPLU SRL
BON FISCAL NR 12345
DATA 05.10.2026
TOTAL 148,75 LEI
''');
    expect(result.documentNumber, contains('12345'));
    expect(result.amount, closeTo(148.75, 0.01));
    expect(result.date, DateTime(2026, 10, 5));
    expect(result.supplier.toUpperCase(), contains('SRL'));
  });

  test('OCR parser recunoaște document de carburant', () {
    final result = parseFiscalOcr('''
OMV PETROM
MOTORINA
42,50 L
7,25 LEI/L
TOTAL 308,13 LEI
''');
    expect(result.looksLikeFuel, isTrue);
    expect(result.liters, closeTo(42.5, 0.01));
    expect(result.pricePerLiter, closeTo(7.25, 0.01));
  });

  test('rejects impossible calendar dates instead of normalizing them', () {
    final impossible = parseFiscalOcr('BON NR 123\nDATA 31.02.2026\nTOTAL 10,00 LEI');
    expect(impossible.date, isNull);

    final leapDay = parseFiscalOcr('BON NR 124\nDATA 29.02.2024\nTOTAL 10,00 LEI');
    expect(leapDay.date, DateTime(2024, 2, 29));

    final invalidLeapDay = parseFiscalOcr('BON NR 125\nDATA 29.02.2025\nTOTAL 10,00 LEI');
    expect(invalidLeapDay.date, isNull);
  });

  test('keeps Romanian thousands separators when extracting the total', () {
    final spaced = parseFiscalOcr('BON NR 1\nTOTAL DE PLATA 1 234,56 LEI');
    expect(spaced.amount, closeTo(1234.56, 0.01));

    final dotted = parseFiscalOcr('FACTURA NR 2\nTOTAL 1.234,56 RON');
    expect(dotted.amount, closeTo(1234.56, 0.01));

    final ungrouped = parseFiscalOcr('BON NR 3\nTOTAL 1234,56 LEI');
    expect(ungrouped.amount, closeTo(1234.56, 0.01));

    final integerThousands = parseFiscalOcr('BON NR 4\nTOTAL 1.234 LEI');
    expect(integerThousands.amount, closeTo(1234, 0.01));

    final unlabeled = parseFiscalOcr('COMERT SRL\n1 234,56');
    expect(unlabeled.amount, closeTo(1234.56, 0.01));
  });
}
