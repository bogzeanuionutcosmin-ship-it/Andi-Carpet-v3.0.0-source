import 'package:geolocator/geolocator.dart';
import '../models/app_data_models.dart';
import 'graph_route_points.dart';
export 'graph_route_points.dart';

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

