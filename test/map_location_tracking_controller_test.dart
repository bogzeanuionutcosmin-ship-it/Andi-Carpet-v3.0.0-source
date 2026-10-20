import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:andi_carpeta/main.dart' as app;

Position position(double latitude) => Position(
      longitude: 26,
      latitude: latitude,
      timestamp: DateTime.utc(2026, 10, 20),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class FakeMapLocationPlatform implements app.MapLocationPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  final calls = <String>[];
  final stream = StreamController<Position>.broadcast();
  Object? currentPositionError;
  Completer<Position>? pendingCurrentPosition;
  Completer<void>? currentPositionRequested;

  @override
  Future<bool> isLocationServiceEnabled() async {
    calls.add('service');
    return enabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    calls.add('check');
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    calls.add('request');
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition() {
    calls.add('current');
    final pending = pendingCurrentPosition;
    if (pending != null) {
      currentPositionRequested?.complete();
      return pending.future;
    }
    final error = currentPositionError;
    if (error != null) return Future<Position>.error(error);
    return Future.value(position(44));
  }

  @override
  Stream<Position> getPositionStream() {
    calls.add('stream');
    return stream.stream;
  }

  Future<void> close() => stream.close();
}

void main() {
  test('disabled service stops before asking for permission', () async {
    final platform = FakeMapLocationPlatform()..enabled = false;
    final tracker = app.MapLocationTrackingController(platform: platform);

    final result = await tracker.start(onPosition: (_) {}, onError: (_) {});

    expect(result.status, app.MapLocationTrackingStatus.serviceDisabled);
    expect(platform.calls, ['service']);
    await platform.close();
  });

  test('denied permission requests once and never starts location reads',
      () async {
    final platform = FakeMapLocationPlatform()
      ..permission = LocationPermission.denied
      ..requestedPermission = LocationPermission.denied;
    final tracker = app.MapLocationTrackingController(platform: platform);

    final result = await tracker.start(onPosition: (_) {}, onError: (_) {});

    expect(result.status, app.MapLocationTrackingStatus.permissionDenied);
    expect(platform.calls, ['service', 'check', 'request']);
    await platform.close();
  });

  test('denied forever is reported without requesting again', () async {
    final platform = FakeMapLocationPlatform()
      ..permission = LocationPermission.deniedForever;
    final tracker = app.MapLocationTrackingController(platform: platform);

    final result = await tracker.start(onPosition: (_) {}, onError: (_) {});

    expect(
      result.status,
      app.MapLocationTrackingStatus.permissionDeniedForever,
    );
    expect(platform.calls, ['service', 'check']);
    await platform.close();
  });

  test('accepted permission reports current and streamed positions then stops',
      () async {
    final platform = FakeMapLocationPlatform()
      ..permission = LocationPermission.denied
      ..requestedPermission = LocationPermission.whileInUse;
    final tracker = app.MapLocationTrackingController(platform: platform);
    final positions = <Position>[];
    final errors = <Object>[];

    final result = await tracker.start(
      onPosition: positions.add,
      onError: errors.add,
    );

    expect(result.status, app.MapLocationTrackingStatus.started);
    expect(platform.calls, ['service', 'check', 'request', 'current', 'stream']);
    expect(positions.map((p) => p.latitude), [44]);

    platform.stream.add(position(45));
    await Future<void>.delayed(Duration.zero);
    expect(positions.map((p) => p.latitude), [44, 45]);

    final error = StateError('stream failure');
    platform.stream.addError(error);
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, same(error));

    await tracker.stop();
    expect(platform.stream.hasListener, isFalse);
    await platform.close();
  });

  test('current-position failures are returned to the caller', () async {
    final platform = FakeMapLocationPlatform()
      ..currentPositionError = StateError('location failure')
      ..permission = LocationPermission.always;
    final tracker = app.MapLocationTrackingController(platform: platform);

    final result = await tracker.start(onPosition: (_) {}, onError: (_) {});

    expect(result.status, app.MapLocationTrackingStatus.failed);
    expect(result.error.toString(), contains('location failure'));
    expect(platform.calls, ['service', 'check', 'current']);
    await platform.close();
  });
  test('stopping during the current fix prevents stream attachment', () async {
    final pending = Completer<Position>();
    final requested = Completer<void>();
    final platform = FakeMapLocationPlatform()
      ..permission = LocationPermission.always
      ..pendingCurrentPosition = pending
      ..currentPositionRequested = requested;
    final tracker = app.MapLocationTrackingController(platform: platform);
    final positions = <Position>[];

    final starting = tracker.start(
      onPosition: positions.add,
      onError: (_) {},
    );
    await requested.future;
    await tracker.stop();
    pending.complete(position(46));

    final result = await starting;
    expect(result.status, app.MapLocationTrackingStatus.cancelled);
    expect(positions, isEmpty);
    expect(platform.calls, ['service', 'check', 'current']);
    await platform.close();
  });

}
