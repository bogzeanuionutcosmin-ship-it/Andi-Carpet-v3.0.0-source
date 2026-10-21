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

/// Keeps the optional automatic prefill setting outside the Expenses page.
bool shouldRunOptionalAutomaticExpenseOcr({
  required Uint8List imageBytes,
  required bool enabled,
  required bool automaticMode,
}) =>
    imageBytes.isNotEmpty && enabled && automaticMode;

/// Runs the existing OCR pipeline only when automatic prefill is eligible.
/// The caller retains the progress indicator and handles the returned result.
Future<ExpenseOcrScanResult?> scanOptionalAutomaticExpenseOcr(
  Uint8List imageBytes, {
  String? path,
  required bool enabled,
  required bool automaticMode,
  required Future<String> Function(Uint8List, {String? path}) recognize,
  required FiscalOcrData Function(String text) parse,
}) async {
  if (!shouldRunOptionalAutomaticExpenseOcr(
    imageBytes: imageBytes,
    enabled: enabled,
    automaticMode: automaticMode,
  )) {
    return null;
  }
  return scanExpenseDocumentOcr(
    imageBytes,
    path: path,
    recognize: recognize,
    parse: parse,
  );
}
