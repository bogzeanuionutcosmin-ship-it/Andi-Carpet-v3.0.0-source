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
      final source = img.Image(width: 2, height: 3)
        ..exif.imageIfd['Orientation'] = 6;
      final input = Uint8List.fromList(img.encodeJpg(source, quality: 95));
      final decodedInput = img.decodeImage(input)!;
      expect(decodedInput.exif.imageIfd['Orientation'], isNotNull);

      final output = img.decodeImage(compressExpenseDocumentImage(input))!;
      expect(output.width, decodedInput.height);
      expect(output.height, decodedInput.width);
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
