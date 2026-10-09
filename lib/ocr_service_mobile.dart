import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String> recognizeTextFromImage(Uint8List bytes, {String? path}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw UnsupportedError('OCR ML Kit este disponibil pe Android și iOS.');
  }
  if (path == null || path.trim().isEmpty) {
    throw ArgumentError('Fișierul imaginii nu are o cale locală disponibilă.');
  }
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final input = InputImage.fromFilePath(path);
    final result = await recognizer.processImage(input);
    return result.text;
  } finally {
    await recognizer.close();
  }
}
