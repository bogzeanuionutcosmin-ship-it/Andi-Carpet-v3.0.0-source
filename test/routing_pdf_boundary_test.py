"""Preserve protected assets/flows and prove extraction against the pinned baseline."""
from pathlib import Path
import hashlib
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / 'docs/ROUTING_PDF_PROTECTED_2026-10-13.json').read_text())


def source(path):
    return (ROOT / path).read_text()


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


class RoutingPdfBoundaryTests(unittest.TestCase):
    def test_protected_files_are_byte_identical(self):
        for path, expected in MANIFEST['protected_sha256'].items():
            with self.subTest(path=path):
                self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected)

    def test_moved_calculations_and_singleton_config_are_text_identical(self):
        points = source('lib/map/graph_route_points.dart')
        distance = source('lib/map/graph_route_calculations.dart')
        main = source('lib/main.dart')
        blocks = {
            'points': points[points.index('class GraphRoutePoints'):],
            'distance': distance[distance.index('double estimateGraphDistanceKm'):],
            'config': main[main.index('/// Distanța rutieră'):main.index('Future<double?> estimateGraphRoadDistanceKm')],
        }
        for key, block in blocks.items():
            self.assertEqual(digest(block), MANIFEST['original_blocks_sha256'][key], key)

    def test_road_body_only_substitutes_explicit_dependencies(self):
        body = source('lib/map/graph_road_distance.dart')
        body = body[body.index('Future<double?> calculateGraphRoadDistanceKm'):]
        body = body.replace('calculateGraphRoadDistanceKm(', 'estimateGraphRoadDistanceKm(', 1)
        body = body.replace('List<WorkSchedule> days, List<Location> locations, {\n  required bool mapboxEnabled,\n  required DrivingDistanceLookup drivingKm,\n  required RouteHttpGet get,\n}) async {', 'List<WorkSchedule> days, List<Location> locations) async {', 1)
        body = body.replace('if (mapboxEnabled)', 'if (kMapboxEnabled)').replace('return drivingKm(', 'return _mapboxServices.drivingKm(').replace('await get(uri)', 'await http.get(uri)')
        self.assertEqual(digest(body), MANIFEST['original_blocks_sha256']['road'])

    def test_singleton_remains_unique_lazy_and_shared_by_existing_callers(self):
        all_source = '\n'.join(p.read_text() for p in (ROOT / 'lib').rglob('*.dart'))
        self.assertEqual(all_source.count('final MapboxServices _mapboxServices = MapboxServices(kMapboxPublicToken);'), 1)
        main = source('lib/main.dart')
        self.assertIn('drivingKm: (points) => _mapboxServices.drivingKm(points)', main)
        self.assertNotIn('drivingKm: _mapboxServices.drivingKm', main)
        self.assertIn('get: (uri) => http.get(uri)', main)
        for path in ('graph_route_points.dart', 'graph_route_calculations.dart', 'graph_road_distance.dart'):
            body = source('lib/map/' + path)
            self.assertNotIn('main.dart', body)
            self.assertNotIn('part of ', body)
            self.assertNotIn('MapboxServices(', body)


if __name__ == '__main__':
    unittest.main()
