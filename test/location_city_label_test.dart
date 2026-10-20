import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/dashboard/location_city_label.dart';

void main() {
  group('dashboardLocationCityLabel', () {
    test('prefers the final address segment and removes Romanian prefixes', () {
      expect(
        dashboardLocationCityLabel(
          name: 'Million Brăila - Centru',
          address: 'Strada Unirii 1, Municipiul Brăila',
        ),
        'Brăila',
      );
      expect(
        dashboardLocationCityLabel(
          name: 'MAGIC Tulcea',
          address: 'Strada Portului 2, Jud. Tulcea',
        ),
        'Tulcea',
      );
    });

    test('falls back to the cleaned location name for country and postal tails', () {
      expect(
        dashboardLocationCityLabel(
          name: 'Magic Brăila – Centru',
          address: 'Strada Unirii 1, România',
        ),
        'Brăila',
      );
      expect(
        dashboardLocationCityLabel(
          name: 'Million Galați - Sud',
          address: 'Strada Portului 2, 800001',
        ),
        'Galați',
      );
    });

    test('uses the name when the address has no locality segment', () {
      expect(
        dashboardLocationCityLabel(
          name: 'Million Constanța - Nord',
          address: 'Șoseaua Mangaliei',
        ),
        'Constanța',
      );
    });
  });
}
