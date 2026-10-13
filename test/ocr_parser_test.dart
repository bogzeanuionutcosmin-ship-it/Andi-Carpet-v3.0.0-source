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

  test('Totalul real are prioritate față de subtotal, TVA și preț/L', () {
    final data = parseFiscalOcr('''
SC TEST SRL
BON FISCAL NR 12345
SUBTOTAL 100,00 LEI
TOTAL TVA 19,00 LEI
MOTORINA 12,00 L
PRET 7,50 LEI/L
TOTAL DE PLATA 119,00 LEI
''');
    expect(data.amount, 119.00);
  });

  test('Valoare cu separatori de mii este recunoscută corect', () {
    expect(parseFiscalOcr('TOTAL DE PLATA: 1.234,56 LEI').amount, 1234.56);
    expect(parseFiscalOcr('TOTAL RON: 1 234,56').amount, 1234.56);
    expect(parseFiscalOcr('TOTAL: 1,234.56').amount, 1234.56);
  });

  test('Total etichetat pe linia următoare', () {
    expect(parseFiscalOcr('SUMA DE PLATA\n148,75 LEI').amount, 148.75);
  });

  test('Totaluri diferite și contradictorii cer introducere manuală', () {
    expect(parseFiscalOcr('TOTAL 45,00 LEI\nTOTAL 55,00 LEI').amount, isNull);
  });

  test('Nu alege automat cea mai mare sumă de pe bon', () {
    final data = parseFiscalOcr('''
SC TEST SRL
PRODUS 600,00
SUBTOTAL 600,00
TVA 114,00
7,50 LEI/L
''');
    expect(data.amount, isNull);
    expect(data.confidence, lessThan(0.35));
  });

  test('Nu confundă un total TVA cu suma de plată', () {
    expect(parseFiscalOcr('TOTAL TVA 19,00 LEI\nTVA COLECTATA 19,00').amount, isNull);
  });

  test('Sumă fără etichetă doar dacă apare o singură valoare cu monedă', () {
    expect(parseFiscalOcr('118,45 LEI').amount, 118.45);
    expect(parseFiscalOcr('18,45 LEI\n118,45 LEI').amount, isNull);
    expect(parseFiscalOcr('7,25 LEI/L').amount, isNull);
  });

  test('Nu admite sume cu mai mult de două zecimale', () {
    expect(parseFiscalOcr('TOTAL 19,1234 LEI').amount, isNull);
    expect(parseFiscalOcr('TOTAL 12.123,456 LEI').amount, isNull);
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
}
