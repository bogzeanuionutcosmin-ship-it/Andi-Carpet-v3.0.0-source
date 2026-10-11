import 'dart:math' as math;

/// Records *observed* GPS distance, never the suggested Mapbox route length.
/// This class deliberately does not infer distance through gaps in coverage.
class RouteDistanceTracker {
  RouteDistanceTracker({this.maximumAccuracyMeters = 45, this.maximumGap = const Duration(seconds: 90)});

  final double maximumAccuracyMeters;
  final Duration maximumGap;
  RouteGpsFix? _last;
  double _meters = 0;
  int _acceptedSegments = 0;
  int _rejectedFixes = 0;
  double get observedKm => _meters / 1000;
  int get acceptedSegments => _acceptedSegments;
  int get rejectedFixes => _rejectedFixes;
  bool get hasUnmeasuredGaps => _hasGaps;
  bool _hasGaps = false;

  /// Restore cumulative measured distance after a page or application restart.
  /// Do not bridge GPS positions across sessions.
  void restoreMeters(double meters) {
    if (!meters.isFinite || meters < 0) return;
    _meters = meters;
    _last = null;
    _hasGaps = true;
  }

  void reset() {
    _last = null;
    _meters = 0;
    _acceptedSegments = 0;
    _rejectedFixes = 0;
    _hasGaps = false;
  }

  /// Returns true only when a reliable movement segment was added.
  bool add(RouteGpsFix fix) {
    if (!fix.valid || fix.accuracyMeters > maximumAccuracyMeters) {
      _rejectedFixes++;
      _last = null;
      _hasGaps = true;
      return false;
    }
    final previous = _last;
    if (previous == null) {
      _last = fix;
      return false;
    }
    final elapsed = fix.timestamp.difference(previous.timestamp);
    // Ignore out-of-order or duplicated timestamps without replacing the last
    // reliable fix; otherwise a delayed GPS callback could inflate distance.
    if (elapsed <= Duration.zero) {
      _rejectedFixes++;
      return false;
    }
    if (elapsed > maximumGap) {
      _last = fix;
      _hasGaps = true;
      return false;
    }
    _last = fix;
    final distance = _haversine(previous.latitude, previous.longitude, fix.latitude, fix.longitude);
    // Discard GPS jitter and physically implausible jumps (180 km/h).
    final uncertainty = math.max(5.0, (previous.accuracyMeters + fix.accuracyMeters) * 0.5);
    if (distance <= uncertainty) return false;
    if (distance / (elapsed.inMilliseconds / 1000) > 50) {
      _last = null;
      _rejectedFixes++;
      _hasGaps = true;
      return false;
    }
    _meters += distance;
    _acceptedSegments++;
    return true;
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.pow(math.sin(dLon / 2), 2);
    return 2 * radius * math.asin(math.min(1.0, math.sqrt(a)));
  }
}

class RouteGpsFix {
  const RouteGpsFix(this.latitude, this.longitude, this.accuracyMeters, this.timestamp);
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  bool get valid => latitude.isFinite && longitude.isFinite && accuracyMeters.isFinite &&
      latitude.abs() <= 90 && longitude.abs() <= 180 && accuracyMeters >= 0;
}
