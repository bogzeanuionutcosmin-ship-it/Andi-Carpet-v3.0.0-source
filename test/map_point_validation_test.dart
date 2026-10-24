import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../lib/map/map_point_validation.dart';

void main() {
  group('isValidMapPoint', () {
    test('accepts interior and boundary coordinates', () {
      expect(isValidMapPoint(LatLng(45.9432, 24.9668)), isTrue);
      expect(isValidMapPoint(LatLng(-90, -180)), isTrue);
      expect(isValidMapPoint(LatLng(90, 180)), isTrue);
    });

    test('rejects coordinates outside geographic ranges', () {
      expect(isValidMapPoint(LatLng(90.0001, 0)), isFalse);
      expect(isValidMapPoint(LatLng(-90.0001, 0)), isFalse);
      expect(isValidMapPoint(LatLng(0, 180.0001)), isFalse);
      expect(isValidMapPoint(LatLng(0, -180.0001)), isFalse);
    });

    test('rejects non-finite coordinates and the GPS origin', () {
      expect(isValidMapPoint(LatLng(double.nan, 1)), isFalse);
      expect(isValidMapPoint(LatLng(1, double.infinity)), isFalse);
      expect(isValidMapPoint(LatLng(0, 0)), isFalse);
    });
  });
}
