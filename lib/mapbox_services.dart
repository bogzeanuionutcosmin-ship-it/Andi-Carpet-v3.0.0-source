import 'dart:convert';
import 'package:http/http.dart' as http;

/// Optional Mapbox services. Public pk.* token only; no secret token in app.
class MapboxServices {
  MapboxServices(this.token, {http.Client? client}) : _client = client ?? http.Client();
  final String token;
  final http.Client _client;
  final Map<String, _CachedDistance> _distances = {};
  int requestCount = 0;
  final Map<String, int> _requestsByService = {
    'Directions': 0,
    'Optimization': 0,
    'Map Matching': 0,
  };
  Map<String, int> get requestsByService => Map.unmodifiable(_requestsByService);
  int get totalRequests => _requestsByService.values.fold(0, (a, b) => a + b);
  String get trackingStartedAt => _trackingStartedAt.toIso8601String();
  final DateTime _trackingStartedAt = DateTime.now();
  bool get enabled => token.startsWith('pk.');

  Future<Map<String, dynamic>?> _get(Uri uri) async {
    if (!enabled) return null;
    requestCount++;
    final path = uri.path;
    final service = path.startsWith('/directions/') ? 'Directions'
        : path.startsWith('/optimized-trips/') ? 'Optimization'
        : path.startsWith('/matching/') ? 'Map Matching' : null;
    if (service != null) _requestsByService[service] = _requestsByService[service]! + 1;
    try {
      final r = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic> && decoded['code'] == 'Ok') return decoded;
    } catch (_) { /* No fabricated route on errors. */ }
    return null;
  }

  /// Driving route length. At most 25 points per Directions request.
  /// Identical requests cached for 10 minutes to avoid repeated billing.
  Future<double?> drivingKm(List<List<double>> latLon) async {
    if (!enabled || latLon.length < 2 || latLon.length > 75 || !_valid(latLon)) return null;
    final key = latLon.map((p) => '${p[0].toStringAsFixed(5)},${p[1].toStringAsFixed(5)}').join(';');
    final cached = _distances[key];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 10)) return cached.km;
    var meters = 0.0;
    for (var start = 0; start < latLon.length - 1; start += 24) {
      final chunk = latLon.sublist(start, (start + 25).clamp(0, latLon.length));
      final coords = chunk.map((p) => '${p[1]},${p[0]}').join(';');
      final result = await _get(Uri.https('api.mapbox.com', '/directions/v5/mapbox/driving/$coords', {
        'access_token': token, 'overview': 'false', 'steps': 'false',
      }));
      final routes = result?['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
      final distance = routes.first['distance'];
      if (distance is! num || !distance.isFinite || distance < 0) return null;
      meters += distance.toDouble();
    }
    final km = meters / 1000;
    if (_distances.length >= 80) _distances.clear();
    _distances[key] = _CachedDistance(km, DateTime.now());
    return km;
  }

  /// Snaps a short ordered GPS trace to roads. No automatic upload or tracking.
  /// Returns [lat, lon] positions or null when matching is not reliable.
  Future<List<List<double>>?> matchTrace(List<List<double>> latLon) async {
    if (!enabled || latLon.length < 2 || latLon.length > 100 || !_valid(latLon)) return null;
    final coords = latLon.map((p) => '${p[1]},${p[0]}').join(';');
    final data = await _get(Uri.https('api.mapbox.com', '/matching/v5/mapbox/driving/$coords', {
      'access_token': token, 'geometries': 'geojson', 'overview': 'full', 'tidy': 'true',
    }));
    final matches = data?['matchings'];
    if (matches is! List || matches.isEmpty || matches.first is! Map) return null;
    final first = matches.first as Map;
    final confidence = first['confidence'];
    if (confidence is! num || confidence < 0.5) return null;
    final geometry = first['geometry'];
    if (geometry is! Map || geometry['coordinates'] is! List) return null;
    final result = <List<double>>[];
    for (final coordinate in geometry['coordinates'] as List) {
      if (coordinate is! List || coordinate.length < 2 || coordinate[0] is! num || coordinate[1] is! num) return null;
      result.add([(coordinate[1] as num).toDouble(), (coordinate[0] as num).toDouble()]);
    }
    return result.length >= 2 && _valid(result) ? result : null;
  }

  /// Optimizes stops with fixed first and last point (max 12 coordinates).
  /// Returns input indices, not coordinates; caller must preserve work constraints.
  Future<List<int>?> optimizedOrder(List<List<double>> latLon) async {
    if (!enabled || latLon.length < 3 || latLon.length > 12 || !_valid(latLon)) return null;
    final coords = latLon.map((p) => '${p[1]},${p[0]}').join(';');
    final data = await _get(Uri.https('api.mapbox.com', '/optimized-trips/v1/mapbox/driving/$coords', {
      'access_token': token, 'source': 'first', 'destination': 'last',
      'roundtrip': 'false', 'overview': 'false', 'steps': 'false',
    }));
    final waypoints = data?['waypoints'];
    if (waypoints is! List || waypoints.length != latLon.length) return null;
    final order = List<int>.filled(latLon.length, -1);
    for (var input = 0; input < waypoints.length; input++) {
      final item = waypoints[input];
      if (item is! Map || item['waypoint_index'] is! int) return null;
      final output = item['waypoint_index'] as int;
      if (output < 0 || output >= order.length || order[output] != -1) return null;
      order[output] = input;
    }
    if (order.first != 0 || order.last != latLon.length - 1) return null;
    return order;
  }

  static bool _valid(List<List<double>> points) => points.every((p) => p.length == 2 &&
    p[0].isFinite && p[1].isFinite && p[0].abs() <= 90 && p[1].abs() <= 180);
}

class _CachedDistance {
  const _CachedDistance(this.km, this.at);
  final double km;
  final DateTime at;
}
