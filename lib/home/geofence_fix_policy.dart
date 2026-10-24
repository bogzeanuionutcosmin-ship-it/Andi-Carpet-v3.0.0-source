part of '../main.dart';

/// Preserves the existing quality and freshness gate for Home geofence decisions.
bool isUsableGeofencePosition({
  required double latitude,
  required double longitude,
  required double accuracyMeters,
  required double speedMetersPerSecond,
  required DateTime timestamp,
  required DateTime now,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return false;
  }
  if (!accuracyMeters.isFinite ||
      accuracyMeters < 0 ||
      accuracyMeters > 80) {
    return false;
  }
  if (timestamp.isAfter(now.add(const Duration(minutes: 1))) ||
      now.difference(timestamp) > const Duration(minutes: 2)) {
    return false;
  }
  if (speedMetersPerSecond.isFinite && speedMetersPerSecond > 8) {
    return false;
  }
  return true;
}
