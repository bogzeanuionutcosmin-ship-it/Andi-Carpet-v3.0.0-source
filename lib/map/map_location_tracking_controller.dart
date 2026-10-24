part of '../main.dart';

enum MapLocationTrackingStatus {
  started,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  cancelled,
  alreadyStarting,
  failed,
}

class MapLocationTrackingResult {
  const MapLocationTrackingResult(this.status, {this.error});

  final MapLocationTrackingStatus status;
  final Object? error;
}

abstract class MapLocationPlatform {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
  Stream<Position> getPositionStream();
}

class GeolocatorMapLocationPlatform implements MapLocationPlatform {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

  @override
  Stream<Position> getPositionStream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );
}

/// Owns GPS permission checks and the stream subscription for MapPage.
class MapLocationTrackingController {
  MapLocationTrackingController({MapLocationPlatform? platform})
      : _platform = platform ?? GeolocatorMapLocationPlatform();

  final MapLocationPlatform _platform;
  StreamSubscription<Position>? _subscription;
  bool _starting = false;
  int _generation = 0;

  Future<MapLocationTrackingResult> start({
    required void Function(Position position) onPosition,
    required void Function(Object error) onError,
  }) async {
    if (_starting) {
      return const MapLocationTrackingResult(
        MapLocationTrackingStatus.alreadyStarting,
      );
    }
    _starting = true;
    final generation = ++_generation;
    try {
      final enabled = await _platform.isLocationServiceEnabled();
      if (generation != _generation) {
        return const MapLocationTrackingResult(MapLocationTrackingStatus.cancelled);
      }
      if (!enabled) {
        return const MapLocationTrackingResult(
          MapLocationTrackingStatus.serviceDisabled,
        );
      }

      var permission = await _platform.checkPermission();
      if (generation != _generation) {
        return const MapLocationTrackingResult(MapLocationTrackingStatus.cancelled);
      }
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
        if (generation != _generation) {
          return const MapLocationTrackingResult(MapLocationTrackingStatus.cancelled);
        }
      }
      if (permission == LocationPermission.denied) {
        return const MapLocationTrackingResult(
          MapLocationTrackingStatus.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const MapLocationTrackingResult(
          MapLocationTrackingStatus.permissionDeniedForever,
        );
      }

      final position = await _platform.getCurrentPosition();
      if (generation != _generation) {
        return const MapLocationTrackingResult(
          MapLocationTrackingStatus.cancelled,
        );
      }
      onPosition(position);

      await _subscription?.cancel();
      if (generation != _generation) {
        return const MapLocationTrackingResult(
          MapLocationTrackingStatus.cancelled,
        );
      }
      _subscription = _platform.getPositionStream().listen(
        onPosition,
        onError: onError,
      );
      return const MapLocationTrackingResult(
        MapLocationTrackingStatus.started,
      );
    } catch (error) {
      if (generation != _generation) {
        return const MapLocationTrackingResult(
          MapLocationTrackingStatus.cancelled,
        );
      }
      return MapLocationTrackingResult(
        MapLocationTrackingStatus.failed,
        error: error,
      );
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
