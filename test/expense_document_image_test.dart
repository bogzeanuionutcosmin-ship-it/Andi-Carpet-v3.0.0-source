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
      // A 2x3 JPEG with EXIF orientation 6 should become 3x2 after rotation.
      final orientedJpeg = base64Decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYFBgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAADAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD6o+AaaVo3wK8FaPZ+FNBeK08JabDE934etJ5WVbWNQXlliZ5GwOXdizHJJJJNFFFft+Z+DnhFXzKtUqcPYGUpTk23hMO2222226erfVn+MHiXxrxlh/EfOaVLMsRGMcXiUkq1RJJVppJJSskloktj/9k=',
      );

      final output = img.decodeImage(
        compressExpenseDocumentImage(Uint8List.fromList(orientedJpeg)),
      )!;
      expect(output.width, 3);
      expect(output.height, 2);
    });

    test('caps the longest output dimension at 1400 and preserves ratio', () {
      final source = img.Image(width: 1600, height: 800);
      final input = Uint8List.fromList(img.encodePng(source));

      final output = img.decodeImage(compressExpenseDocumentImage(input))!;
      expect(output.width, 1400);
      expect(output.height, 700);
    });

    test('falls back to smaller dimensions for a high-entropy image', () {
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
      expect(compressed.length, lessThanOrEqualTo(480000));
      expect(output.width, lessThanOrEqualTo(1050));
      expect(output.height, lessThanOrEqualTo(1050));
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
