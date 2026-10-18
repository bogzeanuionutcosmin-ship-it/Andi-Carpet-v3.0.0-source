import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_data_models.dart';
import 'graph_route_points.dart';

/// Calls the existing routing service; does not own a client or its cache.
typedef DrivingDistanceLookup = Future<double?> Function(List<List<double>> points);
typedef RouteHttpGet = Future<http.Response> Function(Uri uri);

Future<double?> calculateGraphRoadDistanceKm(
    List<WorkSchedule> days, List<Location> locations, {
  required bool mapboxEnabled,
  required DrivingDistanceLookup drivingKm,
  required RouteHttpGet get,
}) async {
  final route = graphRoutePoints(days, locations);
  if (!route.complete || route.points.length < 2 || route.points.length > 75) {
    return null;
  }
  // Mapbox Directions accepts up to 25 waypoints per request. Overlap
  // adjacent chunks at the boundary to preserve the entire road distance.
  if (mapboxEnabled) {
    return drivingKm(route.points
        .map((p) => <double>[p.latitude, p.longitude]).toList());
  }

  // Development fallback when no public Mapbox token was supplied.
  final coordinates = route.points
      .map((p) => '${p.longitude},${p.latitude}')
      .join(';');
  final uri = Uri.https('router.project-osrm.org',
      '/route/v1/driving/$coordinates', {'overview': 'false', 'steps': 'false'});
  try {
    final response = await get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is! Map || data['code'] != 'Ok') return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final distance = routes.first['distance'];
    if (distance is! num || !distance.isFinite || distance < 0) return null;
    return distance.toDouble() / 1000.0;
  } catch (_) {
    return null;
  }
}

