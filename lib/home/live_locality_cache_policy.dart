/// Reuses Home's cached locality only while movement and cache age stay
/// strictly below the existing 5 km and 30 minute limits.
bool shouldReuseLiveLocalityCache({
  required String label,
  required DateTime? resolvedAt,
  required double? distanceMovedMeters,
  required DateTime now,
}) {
  if (label.isEmpty || resolvedAt == null || distanceMovedMeters == null) {
    return false;
  }
  return distanceMovedMeters < 5000 &&
      now.difference(resolvedAt) < const Duration(minutes: 30);
}
