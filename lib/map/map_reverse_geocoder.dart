import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'reverse_geocode_address.dart';

typedef ReverseGeocodeGet = Future<http.Response> Function(
  Uri uri, {
  Map<String, String>? headers,
});

Future<http.Response> _defaultReverseGeocodeGet(
  Uri uri, {
  Map<String, String>? headers,
}) =>
    http.get(uri, headers: headers);

/// Performs the existing Nominatim reverse lookup and returns its concise
/// address. The request callback is injectable so tests never access network.
Future<String?> reverseGeocodePoint(
  LatLng point, {
  required bool isWeb,
  ReverseGeocodeGet? get,
}) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': point.latitude.toStringAsFixed(7),
      'lon': point.longitude.toStringAsFixed(7),
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'ro',
    });
    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': 'ro',
    };
    if (!isWeb) {
      headers['User-Agent'] = 'AndiCarpeta/1.5.1 (internal operations app)';
    }
    final response = await (get ?? _defaultReverseGeocodeGet)(uri,
        headers: headers).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.body.isEmpty) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return parseNominatimReverseAddress(decoded);
  } catch (_) {
    return null;
  }
}
