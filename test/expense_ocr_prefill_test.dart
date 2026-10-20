import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/ocr_parser.dart';

void main() {
  final fallbackDate = DateTime(2026, 10, 20);

  test('uses the existing empty OCR defaults for manual entry', () {
    final result = app.expenseOcrPrefill(null, now: fallbackDate);

    expect(result.documentNumber, isEmpty);
    expect(result.amountText, isEmpty);
    expect(result.supplier, isEmpty);
    expect(result.litersText, isEmpty);
    expect(result.pricePerLiterText, isEmpty);
    expect(result.category, 'Alte cheltuieli');
    expect(result.documentType, app.ExpenseDocumentType.fiscalReceipt);
    expect(result.date, fallbackDate);
  });

  test('preserves OCR field formatting, fuel category, invoice type and parsed date', () {
    final parsedDate = DateTime(2026, 10, 19);
    final result = app.expenseOcrPrefill(
      FiscalOcrData(
        rawText: 'factură fiscală',
        documentNumber: 'AB-42',
        amount: 1234.5,
        date: parsedDate,
        supplier: 'Furnizor SRL',
        liters: 24.75,
        pricePerLiter: 7.25,
        looksLikeFuel: true,
        confidence: .95,
      ),
      now: fallbackDate,
    );

    expect(result.documentNumber, 'AB-42');
    expect(result.amountText, '1234.50');
    expect(result.supplier, 'Furnizor SRL');
    expect(result.litersText, '24.75');
    expect(result.pricePerLiterText, '7.25');
    expect(result.category, 'Combustibil');
    expect(result.documentType, app.ExpenseDocumentType.invoice);
    expect(result.date, parsedDate);
  });

  test('keeps non-fuel documents on the other-expenses category', () {
    final result = app.expenseOcrPrefill(
      const FiscalOcrData(rawText: 'BON FISCAL', amount: 19),
      now: fallbackDate,
    );

    expect(result.category, 'Alte cheltuieli');
    expect(result.documentType, app.ExpenseDocumentType.fiscalReceipt);
    expect(result.amountText, '19.00');
    expect(result.date, fallbackDate);
  });
}
