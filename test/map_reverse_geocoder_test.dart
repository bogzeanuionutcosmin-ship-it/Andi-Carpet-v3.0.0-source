import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../lib/map/map_reverse_geocoder.dart';

void main() {
  test('sends the existing Romanian reverse lookup request and parses it', () async {
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;

    final result = await reverseGeocodePoint(
      LatLng(46.123456789, 24.987654321),
      isWeb: false,
      get: (uri, {headers}) async {
        requestedUri = uri;
        requestedHeaders = headers;
        return http.Response(
          jsonEncode({
            'address': {'road': 'Strada Test', 'house_number': '7', 'city': 'Craiova'},
          }),
          200,
        );
      },
    );

    expect(requestedUri!.scheme, 'https');
    expect(requestedUri!.host, 'nominatim.openstreetmap.org');
    expect(requestedUri!.path, '/reverse');
    expect(requestedUri!.queryParameters, {
      'format': 'jsonv2',
      'lat': '46.1234568',
      'lon': '24.9876543',
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'ro',
    });
    expect(requestedHeaders, {
      'Accept': 'application/json',
      'Accept-Language': 'ro',
      'User-Agent': 'AndiCarpeta/1.5.1 (internal operations app)',
    });
    expect(result, 'Strada Test 7, Craiova');
  });

  test('omits the native user agent on web', () async {
    Map<String, String>? requestedHeaders;

    await reverseGeocodePoint(
      LatLng(45, 25),
      isWeb: true,
      get: (_, {headers}) async {
        requestedHeaders = headers;
        return http.Response('{}', 200);
      },
    );

    expect(requestedHeaders, {
      'Accept': 'application/json',
      'Accept-Language': 'ro',
    });
  });

  test('returns null for rejected or malformed responses and request failures', () async {
    Future<http.Response> response(int status, String body) async =>
        http.Response(body, status);

    expect(
      await reverseGeocodePoint(LatLng(45, 25), isWeb: true,
          get: (_, {headers}) => response(503, '{}')),
      isNull,
    );
    expect(
      await reverseGeocodePoint(LatLng(45, 25), isWeb: true,
          get: (_, {headers}) => response(200, '')),
      isNull,
    );
    expect(
      await reverseGeocodePoint(LatLng(45, 25), isWeb: true,
          get: (_, {headers}) => response(200, '{bad json')),
      isNull,
    );
    expect(
      await reverseGeocodePoint(
        LatLng(45, 25),
        isWeb: true,
        get: (_, {headers}) => throw StateError('network failure'),
      ),
      isNull,
    );
  });
}
