import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/fuel_receipt_learning.dart';

void main() {
  test('bon mixt: exclude cafeaua si foloseste doar motorina', () {
    final result = classifyFuelReceipt('''
BON FISCAL 123
MOTORINA 250,75
CAFEA 12,50
TOTAL 263,25
''');
    expect(result.containsFuel, isTrue);
    expect(result.fuelAmountBani, 25075);
    expect(result.needsReview, isFalse);
  });

  test('doua alimentari: aduna numai carburantul', () {
    final result = classifyFuelReceipt('''
DIESEL 100,25
BENZINA 50,40
APA 5,00
TOTAL 155,65
''');
    expect(result.fuelAmountBani, 15065);
  });

  test('combustibil fara pret lizibil: cere verificare', () {
    final result = classifyFuelReceipt('MOTORINA SUMA ILIZIBILA');
    expect(result.containsFuel, isTrue);
    expect(result.fuelAmountBani, isNull);
    expect(result.needsReview, isTrue);
  });

  test('bon fara combustibil: suma carburant zero', () {
    final result = classifyFuelReceipt('CAFEA 12,50\\nTOTAL 12,50');
    expect(result.containsFuel, isFalse);
    expect(result.fuelAmountBani, 0);
  });

  test('nu confunda pretul pe litru cu valoarea alimentarii', () {
    final result = classifyFuelReceipt('MOTORINA 35 L 7,49 RON/L');
    expect(result.fuelAmountBani, isNull);
    expect(result.needsReview, isTrue);
  });
}
