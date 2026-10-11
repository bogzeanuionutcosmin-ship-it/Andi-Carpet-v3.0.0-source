import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/invoice_fields_learning.dart';

void main() {
  test('factura hotel cu restaurant: preia totalul integral', () {
    final result = parseInvoiceFields('''
HOTEL EXEMPLU
FACTURA SERIA HT NR 000125
DATA EMITERII 11.10.2026
CAZARE 300,00
RESTAURANT 65,50
TOTAL DE PLATA 365,50
''');
    expect(result.invoiceNumber, 'HT 000125');
    expect(result.invoiceDate, DateTime(2026, 10, 11));
    expect(result.totalBani, 36550);
    expect(result.needsReview, false);
  });

  test('numar rezervare nu este numar factura', () {
    final result = parseInvoiceFields('''
REZERVARE NR 99551
DATA EMITERII 11.10.2026
TOTAL DE PLATA 300,00
''');
    expect(result.invoiceNumber, isEmpty);
    expect(result.needsReview, true);
  });

  test('subtotal si TVA nu sunt total factura', () {
    final result = parseInvoiceFields('''
FACTURA NR 0123
DATA FACTURII 11.10.2026
SUBTOTAL 100,00
TVA 21,00
TOTAL CU TVA 121,00
''');
    expect(result.invoiceNumber, '0123');
    expect(result.totalBani, 12100);
  });

  test('OCR factura nu confunda totalul cu combustibilul', () {
    final invoice = parseInvoiceFields('FACTURA NR 0044\\nDATA EMITERII 11.10.2026\\nMOTORINA 120,00\\nTOTAL DE PLATA 150,00');
    expect(invoice.totalBani, 15000);
  });

  test('fara total explicit cere verificare', () {
    final result = parseInvoiceFields('''
FACTURA NR 0123
DATA FACTURII 11.10.2026
CAZARE 100,00
TVA 21,00
''');
    expect(result.totalBani, null);
    expect(result.needsReview, true);
  });
}
