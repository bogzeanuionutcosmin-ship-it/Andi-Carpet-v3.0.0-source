import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compresses an in-memory receipt image for its temporary preview.
///
/// Keeps the existing dimension, orientation, JPEG quality and size fallback
/// behavior used by the Expenses dialog.
Uint8List compressExpenseDocumentImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    if (bytes.length <= 550000) return bytes;
    throw const FormatException('Imagine prea mare sau format nesuportat.');
  }
  var work = img.bakeOrientation(decoded);
  final longest = work.width > work.height ? work.width : work.height;
  if (longest > 1400) {
    work = work.width >= work.height
        ? img.copyResize(work, width: 1400)
        : img.copyResize(work, height: 1400);
  }
  var encoded = Uint8List.fromList(img.encodeJpg(work, quality: 68));
  if (encoded.length > 480000) {
    work = work.width >= work.height
        ? img.copyResize(work, width: 1050)
        : img.copyResize(work, height: 1050);
    encoded = Uint8List.fromList(img.encodeJpg(work, quality: 56));
  }
  if (encoded.length > 480000) {
    work = work.width >= work.height
        ? img.copyResize(work, width: 800)
        : img.copyResize(work, height: 800);
    encoded = Uint8List.fromList(img.encodeJpg(work, quality: 48));
  }
  return encoded;
}

/// Returns the existing 64-bit FNV-1a fingerprint of the original image bytes.
String fingerprintExpenseDocumentImage(Uint8List bytes) {
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final b in bytes) {
    h ^= BigInt.from(b);
    h = (h * prime) & mask;
  }
  return h.toRadixString(16).padLeft(16, '0');
}
