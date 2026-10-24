import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';

WorkSchedule _day(
  String id, {
  bool started = false,
  bool closed = false,
  bool paused = false,
}) =>
    WorkSchedule(
      id: id,
      teamId: 'team-1',
      graphId: 'graph-1',
      graphName: 'Grafic',
      date: DateTime(2026, 10, id == 'day-1' ? 21 : 22),
      items: <ScheduleItem>[],
      started: started,
      closed: closed,
      paused: paused,
      departureName: 'Plecare veche',
      departureLatitude: 44.4,
      departureLongitude: 26.1,
      returnName: 'Destinație veche',
      returnLatitude: 45.1,
      returnLongitude: 25.3,
    );

void main() {
  group('buildStartedProgramScheduleSnapshot', () {
    test('copies every day, starts the graph, reopens days, and stores trip endpoints', () {
      final days = <WorkSchedule>[
        _day('day-1', closed: true, paused: true),
        _day('day-2', started: false, closed: true, paused: true),
      ];

      final started = buildStartedProgramScheduleSnapshot(
        schedules: days,
        departureName: 'Brăila',
        departureLatitude: 45.2692,
        departureLongitude: 27.9575,
        returnName: 'Galați',
        returnLatitude: 45.4353,
        returnLongitude: 28.0080,
      );

      expect(started.map((day) => day.id), <String>['day-1', 'day-2']);
      for (final day in started) {
        expect(day.started, isTrue);
        expect(day.closed, isFalse);
        expect(day.paused, isFalse);
        expect(day.departureName, 'Brăila');
        expect(day.departureLatitude, 45.2692);
        expect(day.departureLongitude, 27.9575);
        expect(day.returnName, 'Galați');
        expect(day.returnLatitude, 45.4353);
        expect(day.returnLongitude, 28.0080);
      }
      expect(identical(started[0], days[0]), isFalse);
      expect(identical(started[1], days[1]), isFalse);
      expect(days.map((day) => <Object>[
        day.started,
        day.closed,
        day.paused,
        day.departureName,
        day.departureLatitude ?? 0,
        day.returnName,
        day.returnLatitude ?? 0,
      ]), <List<Object>>[
        <Object>[false, true, true, 'Plecare veche', 44.4, 'Destinație veche', 45.1],
        <Object>[false, true, true, 'Plecare veche', 44.4, 'Destinație veche', 45.1],
      ]);
    });

    test('returns an empty snapshot for an empty graph', () {
      expect(
        buildStartedProgramScheduleSnapshot(
          schedules: const <WorkSchedule>[],
          departureName: 'Brăila',
          departureLatitude: 45.2692,
          departureLongitude: 27.9575,
          returnName: 'Galați',
          returnLatitude: 45.4353,
          returnLongitude: 28.0080,
        ),
        isEmpty,
      );
    });
  });
}
