part of '../main.dart';

/// Caches identical Mapbox route geometry requests for the existing five-minute
/// window. Coordinates use the same six-decimal key and latitude/longitude order.
class MapRouteGeometryCache {
  MapRouteGeometryCache({
    required Future<List<List<double>>?> Function(List<List<double>> latLon)
        loadGeometry,
    DateTime Function()? now,
  })  : _loadGeometry = loadGeometry,
        _now = now ?? DateTime.now;

  final Future<List<List<double>>?> Function(List<List<double>> latLon)
      _loadGeometry;
  final DateTime Function() _now;

  String? _key;
  Future<List<List<double>>?>? _future;
  DateTime? _requestedAt;

  Future<List<List<double>>?> load(List<LatLng> points) {
    final key = points
        .map((point) =>
            '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}')
        .join('|');
    final requestedAt = _requestedAt;
    final stale = requestedAt == null ||
        _now().difference(requestedAt) > const Duration(minutes: 5);
    if (_key != key || _future == null || stale) {
      _key = key;
      _requestedAt = _now();
      _future = _loadGeometry(
        points.map((point) => <double>[point.latitude, point.longitude]).toList(),
      );
    }
    return _future!;
  }
}
