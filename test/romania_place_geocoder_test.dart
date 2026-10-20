import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:andi_carpeta/services/romania_place_geocoder.dart';

void main() {
  group('RomaniaPlaceGeocoder', () {
    test('returns null for a blank query without contacting either transport', () async {
      var calls = 0;
      final geocoder = RomaniaPlaceGeocoder(
        serverEndpoint: Uri.https('example.test', '/geocode'),
        getIdToken: () async => 'token',
        get: (uri, {headers}) async {
          calls++;
          return http.Response('[]', 200);
        },
        post: (uri, {headers, body}) async {
          calls++;
          return http.Response('{}', 200);
        },
        isWeb: false,
        includeName: true,
        log: (_) {},
      );

      expect(await geocoder.geocode(' \t '), isNull);
      expect(calls, 0);
    });

    test('web uses the authenticated server first and preserves the no-name result shape', () async {
      final calls = <String>[];
      String? postedBody;
      Map<String, String>? postedHeaders;
      final geocoder = RomaniaPlaceGeocoder(
        serverEndpoint: Uri.https('example.test', '/geocode'),
        getIdToken: () async => 'web-token',
        get: (uri, {headers}) async {
          calls.add('nominatim');
          return http.Response('[]', 200);
        },
        post: (uri, {headers, body}) async {
          calls.add('server');
          postedBody = body?.toString();
          postedHeaders = headers;
          return http.Response(jsonEncode({'lat': '45.26', 'lon': '27.97'}), 200);
        },
        isWeb: true,
        includeName: false,
        log: (_) {},
      );

      expect(await geocoder.geocode('  Brăila  '), {'lat': 45.26, 'lon': 27.97});
      expect(calls, ['server']);
      expect(jsonDecode(postedBody!)['query'], 'Brăila');
      expect(postedHeaders?['Authorization'], 'Bearer web-token');
      expect(postedHeaders?['Content-Type'], 'application/json');
    });

    test('native lookup tries the original and Romanian candidate in order', () async {
      final candidates = <String>[];
      Map<String, String>? directHeaders;
      final geocoder = RomaniaPlaceGeocoder(
        serverEndpoint: Uri.https('example.test', '/geocode'),
        getIdToken: () async => 'token',
        get: (uri, {headers}) async {
          candidates.add(uri.queryParameters['q']!);
          directHeaders = headers;
          if (candidates.length == 1) return http.Response('[{"lat":"bad"}]', 200);
          return http.Response('[{"lat":"45.26","lon":"27.97"}]', 200);
        },
        post: (uri, {headers, body}) async => http.Response('{}', 200),
        isWeb: false,
        includeName: true,
        log: (_) {},
      );

      expect(await geocoder.geocode('Brăila'), {
        'name': 'Brăila',
        'lat': 45.26,
        'lon': 27.97,
      });
      expect(candidates, ['Brăila', 'Brăila, România']);
      expect(directHeaders?['User-Agent'], 'AndiCarpeta/2.0.8 (internal operations app)');
    });

    test('native uses server only after direct candidates fail and keeps server name', () async {
      final calls = <String>[];
      final geocoder = RomaniaPlaceGeocoder(
        serverEndpoint: Uri.https('example.test', '/geocode'),
        getIdToken: () async => 'native-token',
        get: (uri, {headers}) async {
          calls.add('nominatim:${uri.queryParameters['q']}');
          return http.Response('[]', 200);
        },
        post: (uri, {headers, body}) async {
          calls.add('server');
          return http.Response(
            jsonEncode({'name': 'Brăila, România', 'lat': 45.26, 'lon': 27.97}),
            200,
          );
        },
        isWeb: false,
        includeName: true,
        log: (_) {},
      );

      expect(await geocoder.geocode('Brăila'), {
        'name': 'Brăila, România',
        'lat': 45.26,
        'lon': 27.97,
      });
      expect(calls, ['nominatim:Brăila', 'nominatim:Brăila, România', 'server']);
    });

    test('web logs a server timeout and continues to direct lookup', () async {
      final neverCompletes = Completer<http.Response>();
      final logs = <String>[];
      final geocoder = RomaniaPlaceGeocoder(
        serverEndpoint: Uri.https('example.test', '/geocode'),
        getIdToken: () async => 'token',
        get: (uri, {headers}) async => http.Response(
          '[{"lat":"45.26","lon":"27.97"}]',
          200,
        ),
        post: (uri, {headers, body}) => neverCompletes.future,
        isWeb: true,
        includeName: false,
        logPrefix: 'Dashboard',
        serverTimeout: const Duration(milliseconds: 1),
        log: logs.add,
      );

      expect(await geocoder.geocode('Brăila'), {'lat': 45.26, 'lon': 27.97});
      expect(logs.single, startsWith('[geocode] Dashboard server fallback: TimeoutException'));
    });
  });
}
