part of '../main.dart';

/// Resolves a live-location label without tying validation to Dashboard widgets.
/// Thresholds and active-work requirements preserve the existing page behavior.
String dashboardMemberLocationLabel({
  required Map<String, dynamic>? live,
  required String teamId,
  required Iterable<CentralizerRecord> records,
  required Iterable<Location> locations,
  required DateTime Function() now,
  required bool Function(CentralizerRecord record, DateTime workDate)
      belongsToWorkDate,
  required double Function(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) distanceBetween,
  required String Function(DateTime) formatTime,
  required String Function(String name, String address) locationCityLabel,
}) {
  if (live == null) return 'Locație live indisponibilă';
  final latitude = live['latitude'];
  final longitude = live['longitude'];
  if (latitude is! num || longitude is! num ||
      !latitude.toDouble().isFinite || !longitude.toDouble().isFinite ||
      latitude < -90 || latitude > 90 ||
      longitude < -180 || longitude > 180) {
    return 'Locație live indisponibilă';
  }

  final updated = live['updatedAt'];
  final at = updated is Timestamp ? updated.toDate() : null;
  if (at == null ||
      now().difference(at) > const Duration(minutes: 30) ||
      at.isAfter(now().add(const Duration(minutes: 5)))) {
    return 'Locație live neactualizată';
  }
  final age = ' · actualizat ${formatTime(at)}';
  final locality = (live['localityLabel'] ?? '').toString().trim();

  // GPS proximity alone never implies work at a site. Require an active,
  // unfinished record for this team and the operational work date.
  final active = records.where((record) =>
      record.teamId == teamId &&
      record.status == WorkAttemptStatus.running &&
      record.finishedAt == null &&
      belongsToWorkDate(record, now()));
  Location? currentSite;
  var closest = double.infinity;
  for (final record in active) {
    for (final site in locations) {
      if (site.id != record.locationId ||
          site.latitude == null || site.longitude == null) {
        continue;
      }
      final meters = distanceBetween(
        latitude.toDouble(),
        longitude.toDouble(),
        site.latitude!,
        site.longitude!,
      );
      if (meters <= 150 && meters < closest) {
        currentSite = site;
        closest = meters;
      }
    }
  }
  if (currentSite != null) {
    final city = locationCityLabel(currentSite.name, currentSite.address);
    return city.isEmpty
        ? '${currentSite.name}$age'
        : '${currentSite.name} · $city$age';
  }
  if (locality.isNotEmpty) return '$locality$age';
  return 'Oraș/județ indisponibil$age';
}
