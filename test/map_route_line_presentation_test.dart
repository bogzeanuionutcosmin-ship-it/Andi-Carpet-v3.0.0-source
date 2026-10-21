import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../lib/map/map_route_line_presentation.dart';

void main() {
  const route = <LatLng>[
    LatLng(44.0, 26.0),
    LatLng(44.1, 26.1),
    LatLng(44.2, 26.2),
  ];

  test('hides route lines when presentation is disabled', () {
    expect(
      mapRouteLinePresentation(
        visible: false,
        complete: true,
        points: route,
      ),
      isEmpty,
    );
  });

  test('does not present partial geometry as a complete route', () {
    expect(
      mapRouteLinePresentation(
        visible: true,
        complete: false,
        points: route,
      ),
      isEmpty,
    );
  });

  test('returns no segments for fewer than two route points', () {
    for (final points in <List<LatLng>>[
      const <LatLng>[],
      const <LatLng>[LatLng(44.0, 26.0)],
    ]) {
      expect(
        mapRouteLinePresentation(
          visible: true,
          complete: true,
          points: points,
        ),
        isEmpty,
      );
    }
  });

  test('preserves adjacent point order, palette cycle, and stroke width', () {
    final points = List<LatLng>.generate(
      9,
      (index) => LatLng(44.0 + index / 10, 26.0 + index / 10),
    );
    final lines = mapRouteLinePresentation(
      visible: true,
      complete: true,
      points: points,
    );

    const colors = <Color>[
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
    ];

    expect(lines, hasLength(points.length - 1));
    for (var index = 0; index < lines.length; index++) {
      expect(lines[index].points, [points[index], points[index + 1]]);
      expect(lines[index].color, colors[index % colors.length]);
      expect(lines[index].strokeWidth, 6);
    }
  });
}
