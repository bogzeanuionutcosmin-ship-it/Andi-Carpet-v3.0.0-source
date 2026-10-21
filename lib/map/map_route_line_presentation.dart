import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Builds the existing segmented rainbow presentation for a complete route.
///
/// Geometry, route selection, and GPS ownership stay with their existing
/// controllers. Incomplete routes are intentionally not drawn.
List<Polyline> mapRouteLinePresentation({
  required bool visible,
  required bool complete,
  required List<LatLng> points,
}) {
  if (!visible || !complete) return const <Polyline>[];

  const colors = <Color>[
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];
  final lines = <Polyline>[];
  for (var index = 1; index < points.length; index++) {
    lines.add(
      Polyline(
        points: <LatLng>[points[index - 1], points[index]],
        color: colors[(index - 1) % colors.length],
        strokeWidth: 6,
      ),
    );
  }
  return lines;
}
