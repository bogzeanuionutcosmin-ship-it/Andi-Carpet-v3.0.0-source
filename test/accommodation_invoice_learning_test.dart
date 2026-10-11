import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/accommodation_invoice_learning.dart';

void main() {
  test('factura cazare simpla', () {
    final result = classifyAccommodationInvoice(
      'FACTURA SERIA HT NR 00125\nCAZARE CAMERA 2 NOPTI 420,00\nTOTAL 420,00',
    );
    expect(result.containsAccommodation, true);
    expect(result.accommodationAmountBani, 42000);
    expect(result.needsReview, false);
  });

  test('factura mixta cazare si restaurant', () {
    final result = classifyAccommodationInvoice(
      'CAZARE 300,00\nRESTAURANT 65,50\nMINIBAR 20,00\nTOTAL 385,50',
    );
    expect(result.accommodationAmountBani, 30000);
  });

  test('mai multe pozitii de cazare', () {
    final result = classifyAccommodationInvoice(
      'CAZARE CAMERA 1 250,00\nCAZARE CAMERA 2 300,00\nTOTAL 550,00',
    );
    expect(result.accommodationAmountBani, 55000);
  });

  test('valoare ilizibila necesita verificare', () {
    final result = classifyAccommodationInvoice(
      'CAZARE CAMERA ILIZIBIL\nTOTAL 450,00',
    );
    expect(result.containsAccommodation, true);
    expect(result.accommodationAmountBani, null);
    expect(result.needsReview, true);
  });

  test('factura restaurant fara cazare', () {
    final result = classifyAccommodationInvoice(
      'RESTAURANT 75,00\nTOTAL 75,00',
    );
    expect(result.containsAccommodation, false);
    expect(result.accommodationAmountBani, 0);
  });
}
