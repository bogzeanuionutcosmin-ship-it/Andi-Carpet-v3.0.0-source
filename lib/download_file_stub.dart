import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

Future<void> downloadFile(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) async {
  if (mimeType == 'application/pdf') {
    await Printing.sharePdf(bytes: bytes, filename: filename);
    return;
  }
  await FilePicker.saveFile(fileName: filename, bytes: bytes);
}
