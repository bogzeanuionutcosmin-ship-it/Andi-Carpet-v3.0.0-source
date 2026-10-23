import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/mapbox_services.dart';

const route = <List<double>>[
  <double>[46.1, 24.1],
  <double>[46.2, 24.2],
];

http.Response routeResponse() => http.Response(
      jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [24.1, 46.1],
                [24.15, 46.15],
                [24.2, 46.2],
              ],
            },
          },
        ],
      }),
      200,
    );

void main() {
  test('coalesces an in-flight geometry request and caches its successful result', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final client = MockClient((_) {
      requests++;
      return response.future;
    });
    final service = MapboxServices('pk.test', client: client);

    final first = service.drivingGeometry(route);
    final concurrent = service.drivingGeometry(route);
    expect(requests, 1);
    response.complete(routeResponse());

    final firstResult = await first;
    expect(await concurrent, routeResult);
    expect(firstResult, routeResult);
    expect(await service.drivingGeometry(route), routeResult);
    expect(requests, 1);
    expect(service.requestsByService['Directions'], 1);

    // Callers cannot mutate the shared cached geometry.
    firstResult!.first[0] = -1;
    expect(await service.drivingGeometry(route), routeResult);
    expect(requests, 1);
    client.close();
  });

  test('expires cached geometry after five minutes and retries a failed request', () async {
    var now = DateTime(2026, 10, 23, 12);
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return requests == 1 ? routeResponse() : http.Response('{}', 503);
    });
    final service = MapboxServices('pk.test', client: client, now: () => now);

    expect(await service.drivingGeometry(route), routeResult);
    now = now.add(const Duration(minutes: 5) - const Duration(microseconds: 1));
    expect(await service.drivingGeometry(route), routeResult);
    expect(requests, 1);
    now = now.add(const Duration(microseconds: 1));
    expect(await service.drivingGeometry(route), isNull);
    expect(requests, 2);

    // Failed data is never cached as if it were a route.
    expect(await service.drivingGeometry(route), isNull);
    expect(requests, 3);
    client.close();
  });

  test('keeps route order in its cache identity', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return routeResponse();
    });
    final service = MapboxServices('pk.test', client: client);

    await service.drivingGeometry(route);
    await service.drivingGeometry(route.reversed.toList());
    expect(requests, 2);
    client.close();
  });
}

const routeResult = <List<double>>[
  <double>[46.1, 24.1],
  <double>[46.15, 24.15],
  <double>[46.2, 24.2],
];
