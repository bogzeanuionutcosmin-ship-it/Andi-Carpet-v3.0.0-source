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

  test('OCR parser citește corect totaluri cu separatori de mii', () {
    const samples = <(String, double)>[
      ('TOTAL 1.234,56 LEI', 1234.56),
      ('SUMA DE PLATA 1 234,56 LEI', 1234.56),
      ('TOTAL 1,234.56 RON', 1234.56),
      ('TOTAL 12.345,67 LEI', 12345.67),
      ('TOTAL 1.234.567,89 LEI', 1234567.89),
      ('TOTAL 148,75 LEI', 148.75),
      ('TOTAL 199.99 RON', 199.99),
    ];
    for (final (ocr, expected) in samples) {
      final parsed = parseFiscalOcr('SC TEST SRL\nBON FISCAL NR 12345\n$ocr');
      expect(parsed.amount, closeTo(expected, 0.001), reason: ocr);
    }
  });

  test('OCR: câmpurile total și TVA diferă, folosim totalul cu separator', () {
    final result = parseFiscalOcr(
      'BON FISCAL 98765\nTOTAL TVA 234,56\nTOTAL DE PLATA 1.234,56 LEI',
    );
    expect(result.amount, closeTo(1234.56, 0.001));
  });
}
