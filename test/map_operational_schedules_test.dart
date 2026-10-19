import 'package:flutter_test/flutter_test.dart';

import '../lib/map/map_operational_schedules.dart';

class _Schedule {
  final String teamId;
  final bool started;
  final bool workDay;
  final bool closed;

  const _Schedule({
    required this.teamId,
    required this.started,
    required this.workDay,
    this.closed = false,
  });
}

List<_Schedule> _todaySchedules(
  List<_Schedule> schedules, {
  bool isAdmin = false,
  String? teamId = 'team-a',
}) =>
    todayMapOperationalSchedules(
      schedules,
      isAdmin: isAdmin,
      teamId: teamId,
      startedOf: (schedule) => schedule.started,
      isWorkDayOf: (schedule) => schedule.workDay,
      teamIdOf: (schedule) => schedule.teamId,
    );

void main() {
  const todayTeamA = _Schedule(teamId: 'team-a', started: true, workDay: true);
  const todayTeamB = _Schedule(teamId: 'team-b', started: true, workDay: true);
  const closedTeamA = _Schedule(
      teamId: 'team-a', started: true, workDay: true, closed: true);

  test('non-admin sees only started schedules for their team and work day', () {
    const notStarted = _Schedule(
        teamId: 'team-a', started: false, workDay: true);
    const anotherDay = _Schedule(
        teamId: 'team-a', started: true, workDay: false);

    expect(
      _todaySchedules([todayTeamA, todayTeamB, notStarted, anotherDay]),
      [todayTeamA],
    );
  });

  test('admin sees started schedules for all teams on the work day', () {
    expect(
      _todaySchedules([todayTeamA, todayTeamB], isAdmin: true),
      [todayTeamA, todayTeamB],
    );
  });

  test('a missing team excludes non-admin schedules', () {
    expect(_todaySchedules([todayTeamA], teamId: null), isEmpty);
  });

  test('closed schedules stay eligible so their markers remain visible', () {
    expect(closedTeamA.closed, isTrue);
    expect(_todaySchedules([closedTeamA]), [closedTeamA]);
    expect(_todaySchedules([closedTeamA], isAdmin: true), [closedTeamA]);
  });
}
