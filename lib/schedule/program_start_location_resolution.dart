part of '../main.dart';

/// Coordinates resolved for the two endpoints collected by the Program START
/// dialog. Keeping the sequential lookup here lets the widget retain only UI,
/// feedback, and persistence responsibilities.
class ProgramStartLocations {
  final double departureLatitude;
  final double departureLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  const ProgramStartLocations({
    required this.departureLatitude,
    required this.departureLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });
}

Future<ProgramStartLocations?> resolveProgramStartLocations({
  required String departure,
  required String destination,
  required Future<Map<String, dynamic>?> Function(String query) geocode,
}) async {
  final departurePoint = await geocode(departure);
  if (departurePoint == null) return null;

  final sameEndpoint = departure.toLowerCase() == destination.toLowerCase();
  final destinationPoint = sameEndpoint
      ? departurePoint
      : await geocode(destination);
  if (destinationPoint == null) return null;

  return ProgramStartLocations(
    departureLatitude: departurePoint['lat'] as double,
    departureLongitude: departurePoint['lon'] as double,
    destinationLatitude: destinationPoint['lat'] as double,
    destinationLongitude: destinationPoint['lon'] as double,
  );
}
