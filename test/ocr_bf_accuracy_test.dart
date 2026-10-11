import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ocr_parser.dart';

void main() {
  test('BF explicit are prioritate fata de terminal si CUI', () {
    final result = parseFiscalOcr('''
OMV
CUI 12345678
TERMINAL NR 456789
CASA NR 08
BF 00012345
11.10.2026
MOTORINA 200,15
TOTAL 200,15
''');
    expect(result.documentNumber, '00012345');
    expect(result.amount, 200.15);
  });

  test('numarul de tranzactie nu devine BF', () {
    final result = parseFiscalOcr('''
POS NR 123456
TRANZACTIE NR 555555
11.10.2026
MOTORINA 150,50
TOTAL 150,50
''');
    expect(result.documentNumber, isEmpty);
  });

  test('bon fiscal nr este acceptat ca BF', () {
    final result = parseFiscalOcr('BON FISCAL NR 00991\n11.10.2026\nMOTORINA 90,20');
    expect(result.documentNumber, '00991');
  });

  test('numarul casei nu devine BF', () {
    final result = parseFiscalOcr('CASA NR 42\nTOTAL 20,00');
    expect(result.documentNumber, isEmpty);
  });
}
