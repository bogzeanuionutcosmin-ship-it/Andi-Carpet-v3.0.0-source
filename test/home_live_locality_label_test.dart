import 'package:flutter_test/flutter_test.dart';
import '../lib/home/home_locality_label.dart';

void main() {
  group('liveLocalityLabelFromAddress', () {
    test('uses the first available city field in the existing priority order', () {
      expect(
        liveLocalityLabelFromAddress({
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
        liveLocalityLabelFromAddress({
          'village': 'Sântandrei',
          'county': 'Bihor',
          'state': 'Crișana',
        }),
        'Sântandrei · Bihor',
      );
    });

    test('does not duplicate a county that differs only by letter case', () {
      expect(
        liveLocalityLabelFromAddress({
          'city': 'ORADEA',
          'county': 'Oradea',
        }),
        'ORADEA',
      );
    });

    test('falls back to state when county is absent and to an empty label when all are absent', () {
      expect(
        liveLocalityLabelFromAddress({'state': 'Bihor'}),
        'Bihor',
      );
      expect(
        liveLocalityLabelFromAddress({}),
        '',
      );
    });
  });
}
