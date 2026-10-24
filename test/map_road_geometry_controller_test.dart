import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../lib/map/map_road_geometry_controller.dart';

void main() {
  final route = <LatLng>[
    LatLng(46.12345678, 24.12345678),
    LatLng(46.9, 24.8),
  ];

  test('shares the pending request and forwards latitude-longitude coordinates', () async {
    final pending = Completer<List<List<double>>?>();
    final requests = <List<List<double>>>[];
    final controller = MapRoadGeometryController(
      loadGeometry: (coordinates) {
        requests.add(coordinates);
        return pending.future;
      },
      now: () => DateTime(2026, 10, 21, 12),
    );

    final first = controller.load(route);
    final concurrent = controller.load(List<LatLng>.of(route));

    expect(identical(first, concurrent), isTrue);
    expect(requests, hasLength(1));
    expect(requests.single, <List<double>>[
      <double>[46.12345678, 24.12345678],
      <double>[46.9, 24.8],
    ]);

    pending.complete(<List<double>>[
      <double>[24.12345678, 46.12345678],
      <double>[24.8, 46.9],
    ]);
    expect(await first, hasLength(2));
  });

  test('reuses at exactly five minutes and refreshes after five minutes', () {
    var now = DateTime(2026, 10, 21, 12);
    var calls = 0;
    final controller = MapRoadGeometryController(
      loadGeometry: (_) async {
        calls++;
        return null;
      },
      now: () => now,
    );

    final initial = controller.load(route);
    now = now.add(const Duration(minutes: 5));
    final atBoundary = controller.load(route);
    expect(identical(initial, atBoundary), isTrue);
    expect(calls, 1);

    now = now.add(const Duration(microseconds: 1));
    final expired = controller.load(route);
    expect(identical(initial, expired), isFalse);
    expect(calls, 2);
  });

  test('a changed or reversed route gets a new request', () {
    final requests = <List<List<double>>>[];
    final controller = MapRoadGeometryController(
      loadGeometry: (coordinates) async {
        requests.add(coordinates);
        return null;
      },
      now: () => DateTime(2026, 10, 21, 12),
    );

    final first = controller.load(route);
    final changed = controller.load(<LatLng>[route.first, LatLng(47, 25)]);
    final reversed = controller.load(route.reversed.toList());

    expect(identical(first, changed), isFalse);
    expect(identical(changed, reversed), isFalse);
    expect(requests, hasLength(3));
    expect(requests.last.first, <double>[46.9, 24.8]);
  });

  test('retains a failed request for the same route until cache expiry', () async {
    final failure = Completer<List<List<double>>?>();
    var calls = 0;
    final controller = MapRoadGeometryController(
      loadGeometry: (_) {
        calls++;
        return failure.future;
      },
      now: () => DateTime(2026, 10, 21, 12),
    );

    final first = controller.load(route);
    final sameRoute = controller.load(route);
    expect(identical(first, sameRoute), isTrue);

    failure.completeError(StateError('Mapbox unavailable'));
    await expectLater(first, throwsA(isA<StateError>()));
    expect(identical(first, controller.load(route)), isTrue);
    expect(calls, 1);
  });
}
