import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.WorkSchedule cloneForTest(app.WorkSchedule source) => app.WorkSchedule(
  id: source.id,
  teamId: source.teamId,
  graphId: source.graphId,
  graphName: source.graphName,
  date: source.date,
  items: List<app.ScheduleItem>.from(source.items),
  started: source.started,
  closed: source.closed,
  paused: source.paused,
  planAlertReason: source.planAlertReason,
);

void main() {
  app.WorkSchedule schedule(String id, {
    bool started = false,
    bool closed = false,
    bool paused = false,
  }) => app.WorkSchedule(
    id: id,
    teamId: 'team-1',
    graphName: 'Graph $id',
    date: DateTime.utc(2026, 10, 20),
    items: [
      app.ScheduleItem(
        locationId: 'location-$id',
        locationNameSnapshot: 'Client $id',
        addressSnapshot: 'Address $id',
        typeSnapshot: app.LocationType.magic,
        order: 1,
      ),
    ],
    started: started,
    closed: closed,
    paused: paused,
    planAlertReason: 'preserve-$id',
  );

  test('pause projection updates every clone and preserves all other state', () {
    final first = schedule('1');
    final second = schedule('2', started: true);
    final projected = app.projectProgramGraphState(
      schedules: [first, second],
      clone: cloneForTest,
      paused: true,
    );

    expect(projected, hasLength(2));
    expect(projected[0], isNot(same(first)));
    expect(projected[1], isNot(same(second)));
    expect(projected.map((item) => item.paused), everyElement(isTrue));
    expect(projected.map((item) => item.started), [false, true]);
    expect(projected.map((item) => item.closed), [false, false]);
    expect(projected.map((item) => item.planAlertReason), [
      'preserve-1',
      'preserve-2',
    ]);
    expect(projected.map((item) => item.graphName), ['Graph 1', 'Graph 2']);
    expect(projected.map((item) => item.items.single.locationId), [
      'location-1',
      'location-2',
    ]);

    expect(first.paused, isFalse);
    expect(second.paused, isFalse);
  });

  test('null flags retain source values while explicit flags change only clones', () {
    final source = schedule('1', started: true, closed: true, paused: true);
    final projected = app.projectProgramGraphState(
      schedules: [source],
      clone: cloneForTest,
      started: false,
      closed: null,
      paused: null,
    );

    expect(projected.single.started, isFalse);
    expect(projected.single.closed, isTrue);
    expect(projected.single.paused, isTrue);
    expect(source.started, isTrue);
    expect(source.closed, isTrue);
    expect(source.paused, isTrue);
  });

  test('start, close, and resume flags update only the projected schedules', () {
    final source = schedule('1', paused: true);
    final projected = app.projectProgramGraphState(
      schedules: [source],
      clone: cloneForTest,
      started: true,
      closed: true,
      paused: false,
    );

    expect(projected.single.started, isTrue);
    expect(projected.single.closed, isTrue);
    expect(projected.single.paused, isFalse);
    expect(source.started, isFalse);
    expect(source.closed, isFalse);
    expect(source.paused, isTrue);
  });

  test('empty graph produces an empty snapshot', () {
    expect(
      app.projectProgramGraphState(
        schedules: const [],
        clone: cloneForTest,
        closed: true,
      ),
      isEmpty,
    );
  });
}
