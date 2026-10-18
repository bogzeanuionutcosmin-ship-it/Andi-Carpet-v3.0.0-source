import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Deschide selectorul nativ „Salvează ca…” (Android SAF / iOS Files /
/// desktop). Nu confundăm salvarea fișierului cu partajarea PDF-ului.
///
/// false înseamnă că utilizatorul a anulat dialogul, nu că PDF-ul a fost salvat.
Future<bool> downloadFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  final destination = await FilePicker.saveFile(
    dialogTitle: 'Salvează fișierul',
    fileName: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
  return destination != null;
}
