import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PV Million is loadable from the Flutter bundle with original bytes', () async {
    final data = await rootBundle.load('assets/pv_million.pdf');
    final bundled = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final original = await File('assets/pv_million.pdf').readAsBytes();
    expect(bundled.length, 1399921);
    expect(bundled.take(5), [0x25, 0x50, 0x44, 0x46, 0x2d]);
    expect(bundled, orderedEquals(original));
  });
}
