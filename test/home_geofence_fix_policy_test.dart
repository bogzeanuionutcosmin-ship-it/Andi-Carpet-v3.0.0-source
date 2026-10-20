import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  final now = DateTime.utc(2026, 10, 20, 12);

  bool usable({
    double latitude = 44.4268,
    double longitude = 26.1025,
    double accuracy = 20,
    double speed = 0,
    Duration age = Duration.zero,
  }) =>
      app.isUsableGeofencePosition(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
        speedMetersPerSecond: speed,
        timestamp: now.subtract(age),
        now: now,
      );

  group('isUsableGeofencePosition', () {
    test('accepts valid fixes at the existing inclusive boundaries', () {
      expect(usable(latitude: -90, longitude: 180, accuracy: 80), isTrue);
      expect(usable(age: const Duration(minutes: 2)), isTrue);
      expect(usable(speed: 8), isTrue);
    });

    test('rejects invalid or non-finite coordinates and accuracy', () {
      expect(usable(latitude: double.nan), isFalse);
      expect(usable(longitude: double.infinity), isFalse);
      expect(usable(latitude: 90.001), isFalse);
      expect(usable(longitude: -180.001), isFalse);
      expect(usable(accuracy: double.nan), isFalse);
      expect(usable(accuracy: -0.1), isFalse);
      expect(usable(accuracy: 80.001), isFalse);
    });

    test('rejects stale fixes and fixes more than one minute in the future', () {
      expect(usable(age: const Duration(minutes: 2, microseconds: 1)), isFalse);
      expect(
        app.isUsableGeofencePosition(
          latitude: 44.4268,
          longitude: 26.1025,
          accuracyMeters: 20,
          speedMetersPerSecond: 0,
          timestamp: now.add(const Duration(minutes: 1, microseconds: 1)),
          now: now,
        ),
        isFalse,
      );
      expect(
        app.isUsableGeofencePosition(
          latitude: 44.4268,
          longitude: 26.1025,
          accuracyMeters: 20,
          speedMetersPerSecond: 0,
          timestamp: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('rejects fast travel but preserves existing non-finite-speed behavior', () {
      expect(usable(speed: 8.001), isFalse);
      expect(usable(speed: double.nan), isTrue);
      expect(usable(speed: double.infinity), isTrue);
    });
  });
}
