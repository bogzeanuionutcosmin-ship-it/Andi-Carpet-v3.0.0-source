part of '../main.dart';

/// Result of the existing document OCR and parsing attempt.
class ExpenseOcrScanResult {
  const ExpenseOcrScanResult({required this.data, this.error});

  final FiscalOcrData data;
  final Object? error;
}

/// Runs recognition, parsing, and the success callback as one fallible OCR step.
///
/// The caller retains image picking, progress UI, failure messaging, and the
/// existing empty-data fallback behavior.
Future<ExpenseOcrScanResult> scanExpenseDocumentOcr(
  Uint8List imageBytes, {
  String? path,
  required Future<String> Function(Uint8List, {String? path}) recognize,
  required FiscalOcrData Function(String text) parse,
  void Function(FiscalOcrData data)? onSuccess,
}) async {
  try {
    final text = await recognize(imageBytes, path: path);
    final data = parse(text);
    onSuccess?.call(data);
    return ExpenseOcrScanResult(data: data);
  } catch (error) {
    return ExpenseOcrScanResult(
      data: const FiscalOcrData(rawText: ''),
      error: error,
    );
  }
}
