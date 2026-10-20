import 'dart:convert';

import 'package:http/http.dart' as http;

typedef RomaniaPlaceGet = Future<http.Response> Function(
  Uri uri, {
  Map<String, String>? headers,
});

typedef RomaniaPlacePost = Future<http.Response> Function(
  Uri uri, {
  Map<String, String>? headers,
  Object? body,
});

/// Shared search/fallback policy used by the Dashboard and Program screens.
///
/// The request functions and token source are injected so the parsing and
/// fallback order can be tested without Firebase or live geocoding services.
class RomaniaPlaceGeocoder {
  const RomaniaPlaceGeocoder({
    required this.serverEndpoint,
    required this.getIdToken,
    required this.get,
    required this.post,
    required this.isWeb,
    required this.includeName,
    required this.log,
    this.logPrefix = '',
    this.serverTimeout = const Duration(seconds: 12),
    this.nominatimTimeout = const Duration(seconds: 10),
  });

  final Uri serverEndpoint;
  final Future<String?> Function() getIdToken;
  final RomaniaPlaceGet get;
  final RomaniaPlacePost post;
  final bool isWeb;
  final bool includeName;
  final void Function(String message) log;
  final String logPrefix;
  final Duration serverTimeout;
  final Duration nominatimTimeout;

  Future<Map<String, dynamic>?> geocode(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    Map<String, dynamic>? parsePoint(Object? raw) {
      if (raw is! Map) return null;
      final lat = double.tryParse((raw['lat'] ?? '').toString());
      final lon = double.tryParse((raw['lon'] ?? '').toString());
      if (lat == null || lon == null) return null;
      if (!includeName) return {'lat': lat, 'lon': lon};
      return {'name': (raw['name'] ?? clean).toString(), 'lat': lat, 'lon': lon};
    }

    Future<Map<String, dynamic>?> viaServer() async {
      try {
        final token = await getIdToken();
        if (token == null || token.isEmpty) return null;
        final response = await post(
          serverEndpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'query': clean}),
        ).timeout(serverTimeout);
        if (response.statusCode != 200 || response.body.isEmpty) return null;
        return parsePoint(jsonDecode(response.body));
      } catch (error) {
        final label = logPrefix.isEmpty
            ? 'Server fallback'
            : '$logPrefix server fallback';
        log('[geocode] $label: $error');
        return null;
      }
    }

    Future<Map<String, dynamic>?> viaNominatim(String value) async {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'jsonv2',
          'q': value,
          'limit': '1',
          'countrycodes': 'ro',
          'accept-language': 'ro',
          'addressdetails': '1',
        });
        final headers = <String, String>{
          'Accept': 'application/json',
          'Accept-Language': 'ro',
        };
        if (!isWeb) {
          headers['User-Agent'] = 'AndiCarpeta/2.0.8 (internal operations app)';
        }
        final response = await get(uri, headers: headers).timeout(nominatimTimeout);
        if (response.statusCode != 200 || response.body.isEmpty) return null;
        final decoded = jsonDecode(response.body);
        if (decoded is! List || decoded.isEmpty) return null;
        return parsePoint(decoded.first);
      } catch (error) {
        final context = logPrefix.isEmpty ? '' : '$logPrefix ';
        log('[geocode] ${context}Nominatim $value: $error');
        return null;
      }
    }

    // Browser requests use the Firebase proxy first; native requests try
    // Nominatim first and use the proxy only after direct lookup fails.
    if (isWeb) {
      final server = await viaServer();
      if (server != null) return server;
    }

    final candidates = <String>[clean];
    if (!clean.toLowerCase().contains('românia') &&
        !clean.toLowerCase().contains('romania')) {
      candidates.add('$clean, România');
    }
    for (final candidate in candidates) {
      final direct = await viaNominatim(candidate);
      if (direct != null) return direct;
    }

    if (!isWeb) return viaServer();
    return null;
  }
}
