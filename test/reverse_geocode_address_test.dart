import 'package:flutter_test/flutter_test.dart';

import '../lib/map/reverse_geocode_address.dart';

void main() {
  test('formats street, house number, locality and distinct county in order', () {
    expect(
      parseNominatimReverseAddress({
        'address': {
          'road': '  Strada Lalelelor ',
          'house_number': 12,
          'city': 'Craiova',
          'county': 'Dolj',
        },
        'display_name': 'ignored fallback',
      }),
      'Strada Lalelelor 12, Craiova, Dolj',
    );
  });

  test('uses the first available road and locality aliases', () {
    expect(
      parseNominatimReverseAddress({
        'address': {
          'road': ' ',
          'pedestrian': 'Aleea Parcului',
          'residential': 'Ignored street',
          'town': 'Calafat',
          'municipality': 'Ignored locality',
          'county': 'Calafat',
        },
      }),
      'Aleea Parcului, Calafat',
    );
  });

  test('falls back to trimmed display name when no concise address exists', () {
    expect(
      parseNominatimReverseAddress({
        'address': {'country': 'Romania'},
        'display_name': '  România  ',
      }),
      'România',
    );
    expect(parseNominatimReverseAddress({'display_name': '  '}), isNull);
  });

  test('returns null when neither address fields nor display name are usable', () {
    expect(
      parseNominatimReverseAddress({'address': 'not an address map'}),
      isNull,
    );
  });
}
