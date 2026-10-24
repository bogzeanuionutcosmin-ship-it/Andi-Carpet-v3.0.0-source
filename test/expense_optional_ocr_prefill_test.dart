import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/ocr_parser.dart';

void main() {
  group('optional automatic Expense OCR prefill', () {
    test('is disabled unless the setting is enabled and automatic', () {
      final image = Uint8List.fromList(<int>[1]);
      expect(
        app.shouldRunOptionalAutomaticExpenseOcr(
          imageBytes: image,
          enabled: false,
          automaticMode: true,
        ),
        isFalse,
      );
      expect(
        app.shouldRunOptionalAutomaticExpenseOcr(
          imageBytes: image,
          enabled: true,
          automaticMode: false,
        ),
        isFalse,
      );
      expect(
        app.shouldRunOptionalAutomaticExpenseOcr(
          imageBytes: image,
          enabled: true,
          automaticMode: true,
        ),
        isTrue,
      );
    });

    test('does not invoke recognition for an empty image', () async {
      var recognitionCalls = 0;
      final result = await app.scanOptionalAutomaticExpenseOcr(
        Uint8List(0),
        enabled: true,
        automaticMode: true,
        recognize: (_, {String? path}) async {
          recognitionCalls++;
          return 'unexpected';
        },
        parse: (_) => const FiscalOcrData(rawText: 'unexpected'),
      );

      expect(result, isNull);
      expect(recognitionCalls, 0);
    });

    test('returns parsed data for eligible automatic prefill', () async {
      final image = Uint8List.fromList(<int>[4, 5]);
      Uint8List? received;
      String? receivedPath;
      final result = await app.scanOptionalAutomaticExpenseOcr(
        image,
        enabled: true,
        automaticMode: true,
        path: '/tmp/receipt.jpg',
        recognize: (bytes, {String? path}) async {
          received = bytes;
          receivedPath = path;
          return 'receipt text';
        },
        parse: (text) => FiscalOcrData(rawText: text, confidence: 0.75),
      );

      expect(identical(received, image), isTrue);
      expect(receivedPath, '/tmp/receipt.jpg');
      expect(result?.data.rawText, 'receipt text');
      expect(result?.data.confidence, 0.75);
      expect(result?.error, isNull);
    });

    test('returns the existing empty fallback when eligible OCR fails', () async {
      final failure = StateError('recognizer failed');
      final result = await app.scanOptionalAutomaticExpenseOcr(
        Uint8List.fromList(<int>[6]),
        enabled: true,
        automaticMode: true,
        recognize: (_, {String? path}) async => throw failure,
        parse: (_) => const FiscalOcrData(rawText: 'unexpected'),
      );

      expect(result?.data.rawText, isEmpty);
      expect(result?.data.confidence, 0);
      expect(identical(result?.error, failure), isTrue);
    });
  });
}
