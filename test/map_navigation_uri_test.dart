import 'package:flutter_test/flutter_test.dart';

import '../lib/map/map_navigation_uri.dart';

void main() {
  group('mapNavigationUri', () {
    test('uses saved coordinates for Google Maps when both are present', () {
      expect(
        mapNavigationUri(
          app: 'maps',
          latitude: 45.1,
          longitude: 27.95,
          address: 'ignored address',
        ).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=45.1%2C27.95',
      );
    });

    test('uses the saved address for Google Maps when coordinates are absent', () {
      expect(
        mapNavigationUri(
          app: 'maps',
          latitude: null,
          longitude: null,
          address: 'Strada Principala 1',
        ).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=Strada%20Principala%201',
      );
    });

    test('uses saved coordinates for Waze when both are present', () {
      expect(
        mapNavigationUri(
          app: 'waze',
          latitude: 45.1,
          longitude: 27.95,
          address: 'ignored address',
        ).toString(),
        'https://www.waze.com/ul?ll=45.1,27.95&navigate=yes',
      );
    });

    test('encodes Romanian characters and reserved address characters', () {
      const address = 'Școala nr. 2 & hala #4';
      const encodedAddress = '%C8%98coala%20nr.%202%20%26%20hala%20%234';

      expect(
        mapNavigationUri(
          app: 'maps',
          latitude: null,
          longitude: null,
          address: address,
        ).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress',
      );
      expect(
        mapNavigationUri(
          app: 'waze',
          latitude: null,
          longitude: null,
          address: address,
        ).toString(),
        'https://www.waze.com/ul?q=$encodedAddress&navigate=yes',
      );
    });

    test('falls back to address when only one coordinate is present', () {
      const address = 'Depozit & punct #2';

      expect(
        mapNavigationUri(
          app: 'maps',
          latitude: 45.1,
          longitude: null,
          address: address,
        ).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=Depozit%20%26%20punct%20%232',
      );
      expect(
        mapNavigationUri(
          app: 'waze',
          latitude: null,
          longitude: 27.95,
          address: address,
        ).toString(),
        'https://www.waze.com/ul?q=Depozit%20%26%20punct%20%232&navigate=yes',
      );
    });

    test('preserves the Waze fallback for an unrecognized app value', () {
      expect(
        mapNavigationUri(
          app: 'unknown',
          latitude: 45.1,
          longitude: 27.95,
          address: 'ignored address',
        ).toString(),
        'https://www.waze.com/ul?ll=45.1,27.95&navigate=yes',
      );
      expect(
        mapNavigationUri(
          app: 'unknown',
          latitude: null,
          longitude: null,
          address: 'Strada Noua 5',
        ).toString(),
        'https://www.waze.com/ul?q=Strada%20Noua%205&navigate=yes',
      );
    });
  });
}
