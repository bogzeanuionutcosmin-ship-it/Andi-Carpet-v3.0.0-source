part of '../main.dart';

class GraphRoutePoints {
  final List<LatLng> points;
  final List<String> missingLocations;
  final bool missingDeparture;
  final bool missingDestination;
  const GraphRoutePoints(this.points, this.missingLocations,
      this.missingDeparture, this.missingDestination);
  bool get complete => !missingDeparture && !missingDestination && missingLocations.isEmpty;
}

GraphRoutePoints graphRoutePoints(List<WorkSchedule> days, List<Location> locations) {
  if (days.isEmpty) return const GraphRoutePoints([], [], true, true);
  final orderedDays = [...days]..sort((a, b) => a.date.compareTo(b.date));
  final head = orderedDays.first;
  final byId = {for (final l in locations) l.id: l};
  final points = <LatLng>[];
  final missing = <String>[];
  final missingStart = head.departureLatitude == null || head.departureLongitude == null;
  final missingEnd = head.returnLatitude == null || head.returnLongitude == null;
  if (!missingStart) points.add(LatLng(head.departureLatitude!, head.departureLongitude!));
  for (final day in orderedDays) {
    final items = [...day.items]..sort((a, b) => a.order.compareTo(b.order));
    for (final item in items) {
      final location = byId[item.locationId];
      if (location?.latitude == null || location?.longitude == null) {
        missing.add(location?.name ?? item.locationId);
        continue;
      }
      points.add(LatLng(location!.latitude!, location.longitude!));
    }
  }
  if (!missingEnd) points.add(LatLng(head.returnLatitude!, head.returnLongitude!));
  return GraphRoutePoints(points, missing, missingStart, missingEnd);
}

double estimateGraphDistanceKm(List<WorkSchedule> days, List<Location> locations) {
  final route = graphRoutePoints(days, locations);
  if (!route.complete || route.points.length < 2) return 0;
  var meters = 0.0;
  for (var i = 1; i < route.points.length; i++) {
    final a = route.points[i - 1];
    final b = route.points[i];
    meters += Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }
  return meters / 1000.0;
}

/// Distanța rutieră în kilometri, pe drumuri practicabile cu automobilul.
/// Null înseamnă că serviciul de rutare nu a putut confirma traseul.
/// Serviciul public OSRM este destinat utilizării moderate, nu garantează SLA.
/// Public Mapbox token supplied at build time. Never embed an sk.* secret here.
const String kMapboxPublicToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

String get kMapTileUrl => !kMapboxEnabled
    ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
    : 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$kMapboxPublicToken';

bool get kMapboxEnabled => kMapboxPublicToken.startsWith('pk.');
final MapboxServices _mapboxServices = MapboxServices(kMapboxPublicToken);


Future<double?> estimateGraphRoadDistanceKm(
    List<WorkSchedule> days, List<Location> locations) async {
  final route = graphRoutePoints(days, locations);
  if (!route.complete || route.points.length < 2 || route.points.length > 75) {
    return null;
  }
  // Mapbox Directions accepts up to 25 waypoints per request. Overlap
  // adjacent chunks at the boundary to preserve the entire road distance.
  if (kMapboxEnabled) {
    return _mapboxServices.drivingKm(route.points
        .map((p) => <double>[p.latitude, p.longitude]).toList());
  }

  // Development fallback when no public Mapbox token was supplied.
  final coordinates = route.points
      .map((p) => '${p.longitude},${p.latitude}')
      .join(';');
  final uri = Uri.https('router.project-osrm.org',
      '/route/v1/driving/$coordinates', {'overview': 'false', 'steps': 'false'});
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
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

