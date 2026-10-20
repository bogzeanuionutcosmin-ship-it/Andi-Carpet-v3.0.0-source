import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/notifications/push_token_document_id.dart';

void main() {
  test('preserves the existing unpadded Base64 URL document ID', () {
    expect(pushTokenDocumentId('abc'), 'YWJj');
    expect(pushTokenDocumentId('ab'), 'YWI');
    expect(pushTokenDocumentId(''), isEmpty);
  });

  test('encodes Unicode tokens from UTF-8 bytes', () {
    expect(pushTokenDocumentId('λ'), 'zrs');
    expect(pushTokenDocumentId('🔒'), '8J-Ukg');
  });

  test('uses URL-safe alphabet and strips all Base64 padding', () {
    expect(pushTokenDocumentId('\u083e\u083f'), '4KC-4KC_');
    final id = pushTokenDocumentId('token+/=?');

    expect(id, isNot(contains('=')));
    expect(id, matches(RegExp(r'^[A-Za-z0-9_-]*$')));
  });
}
