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
      ('TOTAL 123.456,78 LEI', 123456.78),
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

  test('OCR pune totalul de plată înaintea taxei TVA, independent de ordinea liniilor', () {
    const texts = <String>[
      'SC TEST SRL\nTOTAL DE PLATA 1.234,56 LEI\nTOTAL TVA 234,56',
      'SC TEST SRL\nTOTAL TVA 234,56\nTOTAL DE PLATA 1.234,56 LEI',
      'SC TEST SRL\nSUMA DE PLATĂ 1.234,56 LEI\nTVA 234,56',
      'SC TEST SRL\nSUBTOTAL 1.000,00\nTOTAL TVA 234,56\nTOTAL 1.234,56 LEI',
      'SC TEST SRL\nTOTAL 1.234,56 LEI\nTOTAL TVA 234,56',
    ];
    for (final input in texts) {
      expect(parseFiscalOcr(input).amount, closeTo(1234.56, 0.001),
          reason: input);
    }
  });

  test('OCR ignoră zilele imposibile și acceptă 29 februarie în an bisect', () {
    for (final date in <String>[
      '31.02.2026', '29.02.2025', '31.04.2026', '2026-02-30',
    ]) {
      expect(parseFiscalOcr('SC TEST SRL\nDATA $date\nTOTAL 15,90 LEI').date,
          isNull, reason: date);
    }
    expect(parseFiscalOcr('DATA 29.02.2024\nTOTAL 15,90').date,
        DateTime(2024, 2, 29));
    expect(parseFiscalOcr('DATA 2024-02-29\nTOTAL 15,90').date,
        DateTime(2024, 2, 29));
  });

  test('OCR sare peste o dată invalidă înaintea uneia valide', () {
    final parsed = parseFiscalOcr(
        'DATA 31.02.2026\nDATA 05.03.2026\nTOTAL 15,90 LEI');
    expect(parsed.date, DateTime(2026, 3, 5));
  });
}
