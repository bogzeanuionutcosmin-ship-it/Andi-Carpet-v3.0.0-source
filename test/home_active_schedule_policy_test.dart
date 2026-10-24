import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

class ScheduleFixture {
  const ScheduleFixture({
    required this.id,
    required this.teamId,
    required this.date,
    this.started = true,
    this.closed = false,
    this.paused = false,
    this.postponed = false,
  });

  final String id;
  final String teamId;
  final DateTime date;
  final bool started;
  final bool closed;
  final bool paused;
  final bool postponed;
}

List<ScheduleFixture> select(
  Iterable<ScheduleFixture> schedules,
  DateTime workDate,
) =>
    app.homeActiveSchedulesForWorkDate<ScheduleFixture>(
      schedules: schedules,
      teamId: 'team-1',
      workDate: workDate,
      teamIdOf: (schedule) => schedule.teamId,
      dateOf: (schedule) => schedule.date,
      isStarted: (schedule) => schedule.started,
      isClosed: (schedule) => schedule.closed,
      isPaused: (schedule) => schedule.paused,
      isPostponed: (schedule) => schedule.postponed,
      sameDay: (left, right) =>
          left.year == right.year &&
          left.month == right.month &&
          left.day == right.day,
    );

void main() {
  final workDate = DateTime(2026, 10, 21, 22);
  final morning = DateTime(2026, 10, 21, 7);

  test('keeps only started, open, unpaused, non-postponed team schedules', () {
    final eligible = ScheduleFixture(
      id: 'eligible',
      teamId: 'team-1',
      date: morning,
    );

    final result = select([
      eligible,
      ScheduleFixture(
        id: 'other-team',
        teamId: 'team-2',
        date: morning,
      ),
      ScheduleFixture(
        id: 'other-day',
        teamId: 'team-1',
        date: DateTime(2026, 10, 20),
      ),
      ScheduleFixture(
        id: 'not-started',
        teamId: 'team-1',
        date: morning,
        started: false,
      ),
      ScheduleFixture(
        id: 'closed',
        teamId: 'team-1',
        date: morning,
        closed: true,
      ),
      ScheduleFixture(
        id: 'paused',
        teamId: 'team-1',
        date: morning,
        paused: true,
      ),
      ScheduleFixture(
        id: 'postponed',
        teamId: 'team-1',
        date: morning,
        postponed: true,
      ),
    ], workDate);

    expect(result, hasLength(1));
    expect(result.single, same(eligible));
  });

  test('uses the supplied same-day policy and preserves input order', () {
    final later = ScheduleFixture(
      id: 'later',
      teamId: 'team-1',
      date: DateTime(2026, 10, 21, 23),
    );
    final earlier = ScheduleFixture(
      id: 'earlier',
      teamId: 'team-1',
      date: morning,
    );

    final result = select([later, earlier], workDate);

    expect(result, hasLength(2));
    expect(result[0], same(later));
    expect(result[1], same(earlier));
  });

  test('returns a new empty list when no schedule is eligible', () {
    final input = <ScheduleFixture>[
      ScheduleFixture(
        id: 'not-started',
        teamId: 'team-1',
        date: DateTime(2026, 10, 21),
        started: false,
      ),
    ];

    final result = select(input, workDate);

    expect(result, isEmpty);
    expect(result, isNot(same(input)));
  });
}
