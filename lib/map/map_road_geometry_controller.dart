import 'package:latlong2/latlong.dart';

import 'map_geometry_cache_policy.dart';

/// Owns MapPage's single-route Mapbox geometry request and five-minute cache.
class MapRoadGeometryController {
  MapRoadGeometryController({
    required Future<List<List<double>>?> Function(List<List<double>> coordinates)
        loadGeometry,
    DateTime Function()? now,
  })  : _loadGeometry = loadGeometry,
        _now = now ?? DateTime.now;

  final Future<List<List<double>>?> Function(List<List<double>> coordinates)
      _loadGeometry;
  final DateTime Function() _now;

  String? _routeKey;
  Future<List<List<double>>?>? _request;
  DateTime? _requestedAt;

  Future<List<List<double>>?> load(List<LatLng> points) {
    final key = mapRoadGeometryCacheKey(points);
    final stale = isMapRoadGeometryStale(_requestedAt, _now());
    if (_routeKey != key || _request == null || stale) {
      _routeKey = key;
      _requestedAt = _now();
      _request = _loadGeometry(
        points.map((point) => <double>[point.latitude, point.longitude]).toList(),
      );
    }
    return _request!;
  }
}
