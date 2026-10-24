import 'dart:typed_data';

typedef PdfByteDownload = Future<void> Function(
  Uint8List bytes,
  String filename, {
  String mimeType,
});

/// Saves a PDF document and forwards its bytes using the shared PDF MIME type.
Future<void> deliverPdf({
  required Future<Uint8List> Function() buildBytes,
  required String Function() filename,
  required PdfByteDownload download,
}) async {
  final bytes = await buildBytes();
  final targetFilename = filename();
  await download(bytes, targetFilename, mimeType: 'application/pdf');
}
