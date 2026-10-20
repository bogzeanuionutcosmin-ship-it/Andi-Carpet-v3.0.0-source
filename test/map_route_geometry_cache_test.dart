import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('same rounded route reuses the in-flight or completed future', () {
    var calls = 0;
    List<List<double>>? received;
    final cache = app.MapRouteGeometryCache(
      loadGeometry: (points) async {
        calls++;
        received = points;
        return const [[44.0, 26.0], [45.0, 27.0]];
      },
      now: () => DateTime.utc(2026, 10, 20),
    );
    final first = cache.load(const [LatLng(44.0000001, 26), LatLng(45, 27)]);
    final second = cache.load(const [LatLng(44.0000002, 26), LatLng(45, 27)]);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(received, const [[44.0000001, 26.0], [45.0, 27.0]]);
  });

  test('changed route key starts a new request', () {
    var calls = 0;
    final cache = app.MapRouteGeometryCache(
      loadGeometry: (points) async { calls++; return null; },
      now: () => DateTime.utc(2026, 10, 20),
    );
    cache.load(const [LatLng(44, 26)]);
    cache.load(const [LatLng(44, 26), LatLng(45, 27)]);
    expect(calls, 2);
  });

  test('cache remains fresh at five minutes and expires after that boundary', () {
    var now = DateTime.utc(2026, 10, 20);
    var calls = 0;
    final cache = app.MapRouteGeometryCache(
      loadGeometry: (points) async { calls++; return null; },
      now: () => now,
    );
    const route = [LatLng(44, 26), LatLng(45, 27)];
    cache.load(route);
    now = now.add(const Duration(minutes: 5));
    cache.load(route);
    expect(calls, 1);
    now = now.add(const Duration(microseconds: 1));
    cache.load(route);
    expect(calls, 2);
  });
}
