import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ocr_parser.dart';

void main() {
  test('OCR bon mixt: suma este numai combustibilul', () {
    final data = parseFiscalOcr('''
OMV PETROM SA
BON FISCAL NR 12345
11.10.2026
MOTORINA 250,75
CAFEA 12,50
TOTAL 263,25
''');
    expect(data.documentNumber, isNotEmpty);
    expect(data.looksLikeFuel, isTrue);
    expect(data.amount, 250.75);
    expect(data.date?.year, 2026);
  });

  test('OCR combustibil ambiguu: nu precompleteaza totalul', () {
    final data = parseFiscalOcr('''
BON FISCAL NR 12345
MOTORINA SUMA ILIZIBILA
TOTAL 263,25
''');
    expect(data.looksLikeFuel, isTrue);
    expect(data.amount, isNull);
  });

  test('OCR fara combustibil pastreaza suma totala', () {
    final data = parseFiscalOcr('''
BON FISCAL NR 12345
CAFEA 12,50
TOTAL 12,50
''');
    expect(data.looksLikeFuel, isFalse);
    expect(data.amount, 12.50);
  });
}
