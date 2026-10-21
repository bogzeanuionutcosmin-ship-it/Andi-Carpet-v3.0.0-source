import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  group('liveLocalityLabelFromAddress', () {
    test('uses the first available city field in the existing priority order', () {
      expect(
        app.liveLocalityLabelFromAddress({
          'city': ' ',
          'town': ' Oradea ',
          'municipality': 'Municipality',
          'village': 'Village',
          'county': 'Bihor',
        }),
        'Oradea · Bihor',
      );
    });

    test('uses county before state and combines distinct locality names', () {
      expect(
        app.liveLocalityLabelFromAddress({
          'village': 'Sântandrei',
          'county': 'Bihor',
          'state': 'Crișana',
        }),
        'Sântandrei · Bihor',
      );
    });

    test('does not duplicate a county that differs only by letter case', () {
      expect(
        app.liveLocalityLabelFromAddress({
          'city': 'ORADEA',
          'county': 'Oradea',
        }),
        'ORADEA',
      );
    });

    test('falls back to state when county is absent and to an empty label when all are absent', () {
      expect(
        app.liveLocalityLabelFromAddress({'state': 'Bihor'}),
        'Bihor',
      );
      expect(
        app.liveLocalityLabelFromAddress({}),
        '',
      );
    });
  });
}
