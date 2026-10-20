import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('forwards image bytes and local path, parses text, and reports success', () async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    Uint8List? receivedBytes;
    String? receivedPath;
    var parsedText = '';
    final reported = <app.FiscalOcrData>[];

    final result = await app.scanExpenseDocumentOcr(
      bytes,
      path: '/tmp/receipt.jpg',
      recognize: (input, {String? path}) async {
        receivedBytes = input;
        receivedPath = path;
        return 'recognized receipt';
      },
      parse: (text) {
        parsedText = text;
        return const app.FiscalOcrData(rawText: 'recognized receipt', confidence: 0.8);
      },
      onSuccess: reported.add,
    );

    expect(identical(receivedBytes, bytes), isTrue);
    expect(receivedPath, '/tmp/receipt.jpg');
    expect(parsedText, 'recognized receipt');
    expect(result.data.rawText, 'recognized receipt');
    expect(result.data.confidence, 0.8);
    expect(result.error, isNull);
    expect(reported, <app.FiscalOcrData>[result.data]);
    expect(bytes, <int>[1, 2, 3]);
  });

  test('recognition failure returns the existing empty OCR fallback', () async {
    final failure = StateError('recognizer failed');
    var parseCalls = 0;
    var successCalls = 0;

    final result = await app.scanExpenseDocumentOcr(
      Uint8List.fromList(<int>[4]),
      path: '/tmp/receipt.jpg',
      recognize: (_, {String? path}) async => throw failure,
      parse: (_) {
        parseCalls++;
        return const app.FiscalOcrData(rawText: 'unexpected');
      },
      onSuccess: (_) => successCalls++,
    );

    expect(result.data.rawText, isEmpty);
    expect(result.data.confidence, 0);
    expect(identical(result.error, failure), isTrue);
    expect(parseCalls, 0);
    expect(successCalls, 0);
  });

  test('parse or success callback failure uses the same OCR fallback', () async {
    final parseFailure = ArgumentError('parser failed');
    final parseResult = await app.scanExpenseDocumentOcr(
      Uint8List.fromList(<int>[5]),
      path: '/tmp/receipt.jpg',
      recognize: (_, {String? path}) async => 'text',
      parse: (_) => throw parseFailure,
    );
    expect(parseResult.data.rawText, isEmpty);
    expect(identical(parseResult.error, parseFailure), isTrue);

    final callbackFailure = StateError('logger failed');
    final callbackResult = await app.scanExpenseDocumentOcr(
      Uint8List.fromList(<int>[6]),
      path: '/tmp/receipt.jpg',
      recognize: (_, {String? path}) async => 'text',
      parse: (text) => app.FiscalOcrData(rawText: text, confidence: 1),
      onSuccess: (_) => throw callbackFailure,
    );
    expect(callbackResult.data.rawText, isEmpty);
    expect(identical(callbackResult.error, callbackFailure), isTrue);
  });
}
