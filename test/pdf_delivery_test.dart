import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/reports/pdf_delivery.dart';

void main() {
  test('saves once and forwards the original bytes, filename, and PDF MIME type', () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
    var saveCalls = 0;
    var downloadCalls = 0;
    var saved = false;
    Uint8List? receivedBytes;
    String? receivedFilename;
    String? receivedMimeType;

    await deliverPdf(
      buildBytes: () async {
        saveCalls++;
        saved = true;
        return bytes;
      },
      filename: () {
        expect(saved, isTrue);
        return 'raport_test.pdf';
      },
      download: (savedBytes, filename, {String mimeType = ''}) async {
        downloadCalls++;
        receivedBytes = savedBytes;
        receivedFilename = filename;
        receivedMimeType = mimeType;
      },
    );

    expect(saveCalls, 1);
    expect(downloadCalls, 1);
    expect(receivedBytes, same(bytes));
    expect(receivedFilename, 'raport_test.pdf');
    expect(receivedMimeType, 'application/pdf');
  });

  test('does not download when document serialization fails', () async {
    var downloadCalls = 0;
    var filenameCalls = 0;

    await expectLater(
      deliverPdf(
        buildBytes: () async => throw StateError('save failed'),
        filename: () {
          filenameCalls++;
          return 'raport_test.pdf';
        },
        download: (_, __, {String mimeType = ''}) async {
          downloadCalls++;
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(downloadCalls, 0);
    expect(filenameCalls, 0);
  });

  test('propagates download failures', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);

    await expectLater(
      deliverPdf(
        buildBytes: () async => bytes,
        filename: () => 'raport_test.pdf',
        download: (_, __, {String mimeType = ''}) async {
          throw StateError('download failed');
        },
      ),
      throwsA(isA<StateError>()),
    );
  });
}
