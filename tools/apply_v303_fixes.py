#!/usr/bin/env python3
"""Field-test corrections layered after the verified v3.0.2 import patch."""
from pathlib import Path
p = Path("lib/main.dart")
s = p.read_text(encoding="utf-8")
changes = [
    ("(_selectedCategoryIds.isEmpty || _selectedCategoryIds.contains(l.categoryId))",
     "_selectedCategoryIds.contains(l.categoryId)"),
    ("(_selectedStatuses.isEmpty || _selectedStatuses.contains(l.status))",
     "_selectedStatuses.contains(l.status)"),
    ("const Text('Traseu grafic curcubeu')",
     "const Text('Traseu rutier · progres')"),
    ("await authUser.reauthenticateWithCredential(EmailAuthProvider.credential(email:mail,password:pass));final a=await _loadQuickAccounts();",
     "final a=await _loadQuickAccounts();"),
]
for before, after in changes:
    count = s.count(before)
    if count not in (1, 2) if before.startswith("(_selected") else count != 1:
        raise SystemExit(f"Unexpected count {count}: {before[:85]}")
    s = s.replace(before, after)

# The FlutterMap route must use road geometry, never straight lines.
before = """  List<Polyline> _rainbowRouteLines() {
    if (!_showGraphRoute) return const <Polyline>[];
    const colors = <Color>[Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.blue, Colors.indigo, Colors.purple];
    final route = graphRoutePoints(_routeDays, widget.locations);
    // Nu desenăm segmente false peste locațiile fără GPS.
    if (!route.complete) return const <Polyline>[];
    final lines = <Polyline>[];
    for (var i = 1; i < route.points.length; i++) {
      lines.add(Polyline(points: [route.points[i - 1], route.points[i]],
          color: colors[(i - 1) % colors.length], strokeWidth: 6));
    }
    return lines;
  }"""
after = """  String? _roadRouteKey;
  List<Polyline> _roadRoutePolylines = const <Polyline>[];
  bool _roadRouteLoading = false;
  String? _roadRouteError;

  List<Polyline> _rainbowRouteLines() {
    if (!_showGraphRoute) return const <Polyline>[];
    final days = _routeDays;
    final route = graphRoutePoints(days, widget.locations);
    if (!route.complete || route.points.length < 2) return const <Polyline>[];
    final completed = <String>{};
    for (final day in days) {
      for (final item in day.items) {
        if (widget.records.any((r) => r.teamId == day.teamId &&
            r.locationId == item.locationId && r.completed &&
            recordBelongsToWorkDate(r, day.date))) {
          completed.add('${day.graphId}:${item.locationId}');
        }
      }
    }
    final key = '${days.first.graphId}:${route.points.map((p) => '${p.latitude},${p.longitude}').join('|')}:${completed.length}:${completed.join(',')}';
    if (_roadRouteKey != key) {
      _roadRouteKey = key;
      _roadRoutePolylines = const <Polyline>[];
      _roadRouteLoading = true;
      _roadRouteError = null;
      unawaited(_loadRoadRoute(key, route.points, days));
    }
    return _roadRoutePolylines;
  }

  Future<void> _loadRoadRoute(String key, List<LatLng> points, List<WorkSchedule> days) async {
    try {
      if (points.length > 75) throw StateError('Traseu prea lung pentru rutare publică.');
      final coords = points.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.https('router.project-osrm.org',
        '/route/v1/driving/$coords',
        {'overview':'false','steps':'true','geometries':'geojson'});
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) throw StateError('Serviciul rutier HTTP ${response.statusCode}');
      final data = jsonDecode(response.body);
      if (data is! Map || data['code'] != 'Ok') throw StateError('Rutarea nu a fost confirmată.');
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) throw StateError('Nu există traseu rutier.');
      final legs = routes.first['legs'];
      if (legs is! List || legs.length != points.length - 1) {
        throw StateError('Traseul rutier este incomplet.');
      }
      final ordered = <ScheduleItem>[];
      for (final day in days) {
        ordered.addAll([...day.items]..sort((a,b)=>a.order.compareTo(b.order)));
      }
      var completedCount = 0;
      for (final item in ordered) {
        final done = days.any((day) => day.items.any((i)=>i.locationId==item.locationId) &&
          widget.records.any((rec)=>rec.teamId==day.teamId &&
            rec.locationId==item.locationId && rec.completed &&
            recordBelongsToWorkDate(rec,day.date)));
        if (!done) break;
        completedCount++;
      }
      final lines = <Polyline>[];
      for (var i=0;i<legs.length;i++) {
        final leg = legs[i];
        if (leg is! Map || leg['steps'] is! List) throw StateError('Lipsesc drumurile.');
        final segment = <LatLng>[];
        for (final step in leg['steps'] as List) {
          if (step is! Map || step['geometry'] is! Map) continue;
          final coordinates = step['geometry']['coordinates'];
          if (coordinates is! List) continue;
          for (final xy in coordinates) {
            if (xy is List && xy.length >= 2 && xy[0] is num && xy[1] is num) {
              segment.add(LatLng((xy[1] as num).toDouble(),(xy[0] as num).toDouble()));
            }
          }
        }
        if (segment.length < 2) throw StateError('Geometria unui segment lipsește.');
        final color = i == legs.length - 1 ? Colors.green :
          i < completedCount ? Colors.green :
          i == completedCount ? Colors.amber : Colors.purple;
        lines.add(Polyline(points:segment,color:color,strokeWidth:6));
      }
      if (mounted && _roadRouteKey == key) setState(() {
        _roadRoutePolylines = lines;
        _roadRouteLoading = false;
      });
    } catch (e) {
      if (mounted && _roadRouteKey == key) setState(() {
        _roadRoutePolylines = const <Polyline>[];
        _roadRouteError = 'Traseul rutier nu poate fi încărcat: $e';
        _roadRouteLoading = false;
      });
    }
  }"""
if s.count(before) != 1:
    raise SystemExit("Expected original rainbow route exactly once")
s = s.replace(before, after, 1)
before = "        if (_todayOperationalSchedules.isNotEmpty) ...["
after = """        if (_showGraphRoute && _routeDays.isNotEmpty) ...[
          const SizedBox(height:8),
          const Wrap(spacing:12,runSpacing:6,children:[
            _MapStatusLegend(color:Colors.green,label:'Parcurs / retur planificat'),
            _MapStatusLegend(color:Colors.amber,label:'Următorul segment'),
            _MapStatusLegend(color:Colors.purple,label:'De parcurs'),
          ]),
          if (_roadRouteLoading) const LinearProgressIndicator(),
          if (_roadRouteError != null) Text(_roadRouteError!,style:const TextStyle(color:Colors.orange)),
        ],
        if (_todayOperationalSchedules.isNotEmpty) ...["""
if s.count(before) != 1:
    raise SystemExit("Expected map legend anchor exactly once")
s = s.replace(before, after, 1)
p.write_text(s, encoding="utf-8")
print("Applied verified road-geometry route and progress colors")

p.write_text(s, encoding="utf-8")
print("Applied field-test category/status and quick-account fixes")
