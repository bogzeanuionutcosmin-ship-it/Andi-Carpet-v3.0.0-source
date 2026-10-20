import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../lib/map/map_geometry_cache_policy.dart';

void main() {
  test('route cache key retains ordered six-decimal coordinates', () {
    expect(
      mapRoadGeometryCacheKey(<LatLng>[
        LatLng(46.12345678, 24.12345678),
        LatLng(46.9, 24.8),
      ]),
      '46.123457,24.123457|46.900000,24.800000',
    );
    expect(mapRoadGeometryCacheKey(<LatLng>[]), '');
  });

  test('cache expires only after five minutes and handles missing timestamps', () {
    final now = DateTime(2026, 10, 20, 12);
    expect(isMapRoadGeometryStale(null, now), isTrue);
    expect(isMapRoadGeometryStale(now, now), isFalse);
    expect(isMapRoadGeometryStale(now.subtract(const Duration(minutes: 5)), now), isFalse);
    expect(isMapRoadGeometryStale(now.subtract(const Duration(minutes: 5, microseconds: 1)), now), isTrue);
    // Preserve the original negative-difference behavior if the clock moves back.
    expect(isMapRoadGeometryStale(now.add(const Duration(seconds: 1)), now), isFalse);
  });
}
