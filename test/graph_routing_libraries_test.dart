import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/models/app_enums.dart';
import 'package:andi_carpeta/map/graph_route_calculations.dart';
import 'package:andi_carpeta/map/graph_road_distance.dart';
import 'package:andi_carpeta/main.dart' as legacy;

ScheduleItem item(String id, int order) => ScheduleItem(
  locationId: id, locationNameSnapshot: id, addressSnapshot: '',
  typeSnapshot: LocationType.other, order: order,
);
WorkSchedule day(int date, List<ScheduleItem> items) => WorkSchedule(
  id: '$date', teamId: 'team', date: DateTime(2026, 10, date), items: items,
  departureLatitude: 44, departureLongitude: 26,
  returnLatitude: 45, returnLongitude: 27,
);
Location location(String id, double? lat, double? lon) => Location(
  id: id, name: 'Name $id', address: '', type: LocationType.other,
  latitude: lat, longitude: lon,
);
Future<double?> noMapbox(List<List<double>> points) async =>
    throw StateError('Mapbox must not be called');
Future<http.Response> noHttp(Uri uri) async =>
    throw StateError('HTTP must not be called');

void main() {
  test('empty input preserves missing endpoints and zero distance', () {
    final legacy.GraphRoutePoints route = graphRoutePoints([], []);
    expect(route.complete, isFalse);
    expect(route.missingDeparture, isTrue);
    expect(route.missingDestination, isTrue);
    expect(route.points, isEmpty);
    expect(legacy.estimateGraphDistanceKm([], []), 0);
    expect(legacy.graphRoutePoints, same(graphRoutePoints));
  });

  test('sorts copies, uses earliest endpoints, retains visits and source lists', () {
    final first = day(1, [item('b', 2), item('a', 1)]);
    final later = day(2, [item('a', 1)]);
    later.departureLatitude = 50;
    final days = [later, first];
    final route = graphRoutePoints(days, [location('a', 46, 28), location('b', 47, 29)]);
    expect(route.complete, isTrue);
    expect(route.points.map((p) => [p.latitude, p.longitude]).toList(),
      [[44.0, 26.0], [46.0, 28.0], [47.0, 29.0], [46.0, 28.0], [45.0, 27.0]]);
    expect(days.first, same(later));
    expect(first.items.first.locationId, 'b');
  });

  test('missing GPS reports names or ids and never fabricates distance', () {
    final schedule = day(1, [item('known', 0), item('unknown', 1)]);
    schedule.returnLongitude = null;
    final locations = [location('known', 46, null)];
    final route = graphRoutePoints([schedule], locations);
    expect(route.missingLocations, ['Name known', 'unknown']);
    expect(route.missingDestination, isTrue);
    expect(route.points.length, 1);
    expect(estimateGraphDistanceKm([schedule], locations), 0);
  });

  test('straight line estimate retains Geolocator metric and kilometers', () {
    expect(estimateGraphDistanceKm([day(1, [])], []),
      Geolocator.distanceBetween(44, 26, 45, 27) / 1000);
  });

  test('incomplete and over-limit routes call neither dependency', () async {
    expect(await calculateGraphRoadDistanceKm([], [],
      mapboxEnabled: true, drivingKm: noMapbox, get: noHttp), isNull);
    final locations = [location('a', 46, 28)];
    expect(await calculateGraphRoadDistanceKm(
      [day(1, List.generate(74, (i) => item('a', i)))], locations,
      mapboxEnabled: false, drivingKm: noMapbox, get: noHttp), isNull);
  });

  test('Mapbox gets ordered lat/lon, accepts 75 points, and no HTTP fallback', () async {
    var calls = 0;
    final result = await calculateGraphRoadDistanceKm(
      [day(1, List.generate(73, (i) => item('a', i)))], [location('a', 46, 28)],
      mapboxEnabled: true, get: noHttp, drivingKm: (points) async {
        calls++;
        expect(points.length, 75);
        expect(points.first, [44.0, 26.0]);
        expect(points[1], [46.0, 28.0]);
        expect(points.last, [45.0, 27.0]);
        return null;
      });
    expect(result, isNull);
    expect(calls, 1);
  });

  test('Mapbox distance and exceptions propagate as before', () async {
    expect(await calculateGraphRoadDistanceKm([day(1, [])], [],
      mapboxEnabled: true, drivingKm: (_) async => 12.5, get: noHttp), 12.5);
    await expectLater(calculateGraphRoadDistanceKm([day(1, [])], [],
      mapboxEnabled: true, drivingKm: (_) async => throw StateError('route'),
      get: noHttp), throwsStateError);
  });

  test('OSRM receives lon/lat, original endpoint/options, and converts meters', () async {
    var calls = 0;
    expect(await calculateGraphRoadDistanceKm([day(1, [])], [],
      mapboxEnabled: false, drivingKm: noMapbox, get: (uri) async {
        calls++;
        expect(uri.scheme, 'https');
        expect(uri.host, 'router.project-osrm.org');
        expect(uri.path, '/route/v1/driving/26.0,44.0;27.0,45.0');
        expect(uri.queryParameters, {'overview': 'false', 'steps': 'false'});
        return http.Response(jsonEncode({'code': 'Ok', 'routes': [{'distance': 12345}]}), 200);
      }), 12.345);
    expect(calls, 1);
  });

  test('OSRM invalid responses remain null', () async {
    for (final body in ['broken', '[]', '{}',
      '{"code":"NoRoute"}', '{"code":"Ok","routes":[]}',
      '{"code":"Ok","routes":[{}]}',
      '{"code":"Ok","routes":[{"distance":-1}]}',
      '{"code":"Ok","routes":[{"distance":"12"}]}']) {
      expect(await calculateGraphRoadDistanceKm([day(1, [])], [],
        mapboxEnabled: false, drivingKm: noMapbox,
        get: (_) async => http.Response(body, 200)), isNull, reason: body);
    }
    expect(await calculateGraphRoadDistanceKm([day(1, [])], [],
      mapboxEnabled: false, drivingKm: noMapbox,
      get: (_) async => http.Response('{}', 503)), isNull);
  });

  test('OSRM network errors remain null', () async {
    expect(await calculateGraphRoadDistanceKm([day(1, [])], [],
      mapboxEnabled: false, drivingKm: noMapbox,
      get: (_) async => throw StateError('offline')), isNull);
  });

  testWidgets('OSRM retains 12 second timeout without changing fallback', (tester) async {
    double? value = -1;
    var completed = false;
    final future = calculateGraphRoadDistanceKm([day(1, [])], [],
      mapboxEnabled: false, drivingKm: noMapbox,
      get: (_) => Completer<http.Response>().future).then((result) {
        value = result;
        completed = true;
      });
    await tester.pump(const Duration(seconds: 11));
    expect(completed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await future;
    expect(value, isNull);
  });
}
