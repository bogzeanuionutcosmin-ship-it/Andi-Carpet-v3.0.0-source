import 'package:flutter_test/flutter_test.dart';

import '../lib/map/map_route_selection.dart';

class _Schedule {
  final String teamId;
  final String graphId;
  final DateTime date;
  final bool started;
  final bool closed;

  const _Schedule({
    required this.teamId,
    required this.graphId,
    required this.date,
    this.started = true,
    this.closed = false,
  });
}

List<String> _activeGraphIds(
  List<_Schedule> schedules, {
  String? teamId = 'team-a',
}) =>
    activeMapRouteGraphIds(
      schedules,
      teamId: teamId,
      graphIdOf: (schedule) => schedule.graphId,
      teamIdOf: (schedule) => schedule.teamId,
      startedOf: (schedule) => schedule.started,
      closedOf: (schedule) => schedule.closed,
    );

List<_Schedule> _routeDays(
  List<_Schedule> schedules,
  String graphId,
) =>
    mapRouteDays(
      schedules,
      graphId: graphId,
      graphIdOf: (schedule) => schedule.graphId,
      startedOf: (schedule) => schedule.started,
      closedOf: (schedule) => schedule.closed,
      dateOf: (schedule) => schedule.date,
    );

void main() {
  final early = DateTime(2026, 10, 18);
  final late = DateTime(2026, 10, 20);

  test('keeps active graph IDs unique and in schedule order', () {
    final schedules = [
      _Schedule(teamId: 'team-a', graphId: 'route-b', date: early),
      _Schedule(teamId: 'team-a', graphId: 'route-a', date: late),
      _Schedule(teamId: 'team-a', graphId: 'route-b', date: late),
      _Schedule(teamId: 'team-b', graphId: 'route-b', date: early),
      _Schedule(teamId: 'team-a', graphId: 'closed', date: early, closed: true),
      _Schedule(teamId: 'team-a', graphId: 'not-started', date: early, started: false),
      _Schedule(teamId: 'team-b', graphId: 'other-team', date: early),
    ];

    expect(_activeGraphIds(schedules), ['route-b', 'route-a']);
    expect(_routeDays(schedules, 'route-b').map((schedule) => schedule.graphId),
        ['route-b', 'route-b', 'route-b']);
    expect(_routeDays(schedules, 'route-b').map((schedule) => schedule.date),
        [early, early, late]);
  });

  test('uses requested active route and falls back when it is no longer active', () {
    final schedules = [
      _Schedule(teamId: 'team-a', graphId: 'route-a', date: late),
      _Schedule(teamId: 'team-a', graphId: 'route-b', date: early),
    ];

    final graphIds = _activeGraphIds(schedules);
    expect(selectedActiveMapRouteGraphId(graphIds, 'route-b'), 'route-b');
    expect(selectedActiveMapRouteGraphId(graphIds, 'stale'), 'route-a');
  });

  test('a missing team keeps all teams eligible, as the existing map did', () {
    final schedules = [
      _Schedule(teamId: 'team-b', graphId: 'route-b', date: late),
      _Schedule(teamId: 'team-a', graphId: 'route-a', date: early),
    ];

    final graphIds = _activeGraphIds(schedules, teamId: null);
    expect(graphIds, ['route-b', 'route-a']);
    expect(selectedActiveMapRouteGraphId(graphIds, null), 'route-b');
    expect(_routeDays(schedules, 'route-b').single.graphId, 'route-b');
  });

  test('returns no days when no active graph exists', () {
    final graphIds = _activeGraphIds([
      _Schedule(teamId: 'team-a', graphId: 'closed', date: early, closed: true),
      _Schedule(teamId: 'team-b', graphId: 'other-team', date: early),
    ]);

    expect(graphIds, isEmpty);
    expect(selectedActiveMapRouteGraphId(graphIds, 'stale'), isNull);
    expect(_routeDays([], 'route-a'), isEmpty);
  });
}
