import 'package:latlong2/latlong.dart';

/// Keeps the existing six-decimal route identity used by MapPage's geometry
/// cache. Point order is significant because it describes the route.
String mapRoadGeometryCacheKey(List<LatLng> points) => points
    .map((point) =>
        '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}')
    .join('|');

/// Geometry is stale only after the existing five-minute cache lifetime.
bool isMapRoadGeometryStale(DateTime? requestedAt, DateTime now) =>
    requestedAt == null ||
    now.difference(requestedAt) > const Duration(minutes: 5);
