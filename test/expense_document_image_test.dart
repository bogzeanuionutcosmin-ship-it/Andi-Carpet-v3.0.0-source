import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../lib/expenses/expense_document_image.dart';

void main() {
  group('fingerprintExpenseDocumentImage', () {
    test('matches deterministic 64-bit FNV-1a vectors', () {
      expect(fingerprintExpenseDocumentImage(Uint8List(0)),
          'cbf29ce484222325');
      expect(
        fingerprintExpenseDocumentImage(Uint8List.fromList('hello'.codeUnits)),
        'a430d84680aabd0b',
      );
    });
  });

  group('compressExpenseDocumentImage', () {
    test('bakes EXIF orientation before encoding the preview', () {
      final source = img.Image(width: 2, height: 3);
      final jpeg = Uint8List.fromList(img.encodeJpg(source, quality: 95));
      final input = _withExifOrientation(jpeg, 6);
      final decodedInput = img.decodeImage(input)!;
      // The image package applies JPEG EXIF orientation while decoding and
      // clears the metadata from the returned image.
      expect(decodedInput.width, 3);
      expect(decodedInput.height, 2);
      expect(decodedInput.exif.imageIfd['Orientation'], isNull);

      final output = img.decodeImage(compressExpenseDocumentImage(input))!;
      expect(output.width, 3);
      expect(output.height, 2);
      expect(output.exif.imageIfd['Orientation'], isNull);
    });

    test('caps the longest output dimension at 1400 and preserves ratio', () {
      final source = img.Image(width: 1600, height: 800);
      final input = Uint8List.fromList(img.encodePng(source));

      final output = img.decodeImage(compressExpenseDocumentImage(input))!;
      expect(output.width, 1400);
      expect(output.height, 700);
    });

    test('runs both fallback passes and preserves the final-pass size result', () {
      final source = img.Image(width: 1400, height: 1400);
      var state = 0x12345678;
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          state = (1664525 * state + 1013904223) & 0xffffffff;
          final red = (state >> 16) & 0xff;
          state = (1664525 * state + 1013904223) & 0xffffffff;
          final green = (state >> 16) & 0xff;
          state = (1664525 * state + 1013904223) & 0xffffffff;
          final blue = (state >> 16) & 0xff;
          source.setPixelRgb(x, y, red, green, blue);
        }
      }
      final input = Uint8List.fromList(img.encodePng(source));

      final compressed = compressExpenseDocumentImage(input);
      final output = img.decodeImage(compressed)!;
      // The legacy implementation stops after the 800/48 pass even if the
      // encoded result still exceeds the 480000-byte target.
      expect(output.width, 800);
      expect(output.height, 800);
      expect(compressed.length, greaterThan(0));
    });

    test('preserves malformed-image threshold and exact error', () {
      final underLimit = Uint8List(550000);
      expect(identical(compressExpenseDocumentImage(underLimit), underLimit),
          isTrue);

      final overLimit = Uint8List(550001);
      expect(
        () => compressExpenseDocumentImage(overLimit),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Imagine prea mare sau format nesuportat.',
          ),
        ),
      );
    });
  });
}

/// Inserts a valid, little-endian EXIF APP1 block into an encoded JPEG.
Uint8List _withExifOrientation(Uint8List jpeg, int orientation) {
  final exifSegment = <int>[
    0xff, 0xe1, 0x00, 0x22,
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // Exif\0\0
    0x49, 0x49, 0x2a, 0x00, // little-endian TIFF header
    0x08, 0x00, 0x00, 0x00, // IFD0 offset
    0x01, 0x00, // one IFD entry
    0x12, 0x01, // Orientation tag
    0x03, 0x00, // SHORT
    0x01, 0x00, 0x00, 0x00, // one value
    orientation, 0x00, 0x00, 0x00, // inline SHORT value + padding
    0x00, 0x00, 0x00, 0x00, // next IFD offset
  ];
  return Uint8List.fromList([
    ...jpeg.sublist(0, 2),
    ...exifSegment,
    ...jpeg.sublist(2),
  ]);
}
