import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('Android APK install link accepts only public HTTPS URLs', () {
    expect(app.validatedAndroidApkUrl('https://example.com/andi.apk')?.host, 'example.com');
    expect(app.validatedAndroidApkUrl(' https://example.com/releases/latest '), isNotNull);
    for (final value in <String>[
      '', 'javascript:alert(1)', 'file:///sdcard/andi.apk',
      'http://example.com/andi.apk', 'https://user:password@example.com/andi.apk',
      'https://localhost/andi.apk', 'https://dev.localhost/andi.apk',
      'not-a-url',
    ]) {
      expect(app.validatedAndroidApkUrl(value), isNull, reason: value);
    }
  });
}
