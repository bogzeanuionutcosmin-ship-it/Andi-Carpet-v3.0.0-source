import 'package:latlong2/latlong.dart';
import '../models/app_data_models.dart';

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

