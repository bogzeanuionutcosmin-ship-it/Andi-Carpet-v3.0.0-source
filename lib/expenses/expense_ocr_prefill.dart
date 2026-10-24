part of '../main.dart';

/// Values prefilled in the expense form from OCR output.
class ExpenseOcrPrefill {
  const ExpenseOcrPrefill({
    required this.documentNumber,
    required this.amountText,
    required this.supplier,
    required this.litersText,
    required this.pricePerLiterText,
    required this.category,
    required this.documentType,
    required this.date,
  });

  final String documentNumber;
  final String amountText;
  final String supplier;
  final String litersText;
  final String pricePerLiterText;
  final String category;
  final ExpenseDocumentType documentType;
  final DateTime date;
}

/// Maps OCR output to the exact defaults formerly assigned by ExpensePage.
ExpenseOcrPrefill expenseOcrPrefill(FiscalOcrData? ocr, {required DateTime now}) {
  final rawText = ocr?.rawText ?? '';
  return ExpenseOcrPrefill(
    documentNumber: ocr?.documentNumber ?? '',
    amountText: ocr?.amount == null ? '' : ocr!.amount!.toStringAsFixed(2),
    supplier: ocr?.supplier ?? '',
    litersText: ocr?.liters == null ? '' : ocr!.liters!.toStringAsFixed(2),
    pricePerLiterText:
        ocr?.pricePerLiter == null ? '' : ocr!.pricePerLiter!.toStringAsFixed(2),
    category: ocr?.looksLikeFuel == true ? 'Combustibil' : 'Alte cheltuieli',
    documentType: rawText.toUpperCase().contains('FACTUR')
        ? ExpenseDocumentType.invoice
        : ExpenseDocumentType.fiscalReceipt,
    date: ocr?.date ?? now,
  );
}
