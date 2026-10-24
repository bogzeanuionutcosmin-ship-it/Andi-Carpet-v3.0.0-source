import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.WorkSchedule cloneForTest(app.WorkSchedule source) => app.WorkSchedule(
      id: source.id,
      teamId: source.teamId,
      graphId: source.graphId,
      graphName: source.graphName,
      date: source.date,
      items: source.items
          .map((item) => app.ScheduleItem(
                locationId: item.locationId,
                locationNameSnapshot: item.locationNameSnapshot,
                addressSnapshot: item.addressSnapshot,
                typeSnapshot: item.typeSnapshot,
                categoryIdSnapshot: item.categoryIdSnapshot,
                order: item.order,
                transferred: item.transferred,
                facadePlanned: item.facadePlanned,
              ))
          .toList(),
      started: source.started,
      closed: source.closed,
      paused: source.paused,
      postponed: source.postponed,
      persisted: source.persisted,
      writeToken: source.writeToken,
    );

app.WorkSchedule schedule(String id, {bool paused = false}) => app.WorkSchedule(
      id: id,
      teamId: 'team-1',
      graphId: 'graph-1',
      graphName: 'Graph 1',
      date: DateTime.utc(2026, 10, 21),
      items: [
        app.ScheduleItem(
          locationId: 'location-$id',
          locationNameSnapshot: 'Client $id',
          addressSnapshot: 'Address $id',
          typeSnapshot: app.LocationType.magic,
          order: 1,
        ),
      ],
      paused: paused,
      persisted: true,
      writeToken: 'token-$id',
    );

void main() {
  test('graph-state persistence saves projected clones once and keeps source data', () async {
    final source = [schedule('1'), schedule('2', paused: true)];
    List<app.WorkSchedule>? saved;
    var calls = 0;

    await app.saveProgramGraphState(
      schedules: source,
      clone: cloneForTest,
      save: (items) async {
        calls++;
        saved = items;
      },
      paused: true,
    );

    expect(calls, 1);
    expect(saved, hasLength(2));
    expect(saved!.every((item) => item.paused), isTrue);
    expect(saved!.first, isNot(same(source.first)));
    expect(saved!.map((item) => item.id), ['1', '2']);
    expect(saved!.map((item) => item.writeToken), ['token-1', 'token-2']);
    expect(saved!.map((item) => item.items.single.locationId), [
      'location-1',
      'location-2',
    ]);
    expect(source.map((item) => item.paused), [false, true]);
  });

  test('persistence failure is propagated to the existing page feedback owner', () async {
    final failure = StateError('save failed');
    Object? thrown;

    try {
      await app.saveProgramGraphState(
        schedules: [schedule('1')],
        clone: cloneForTest,
        save: (_) async => throw failure,
        closed: true,
        paused: false,
      );
    } catch (error) {
      thrown = error;
    }

    expect(thrown, same(failure));
  });

  test('empty graphs still invoke the save callback with an empty list', () async {
    List<app.WorkSchedule>? saved;

    await app.saveProgramGraphState(
      schedules: const [],
      clone: cloneForTest,
      save: (items) async => saved = items,
      closed: true,
    );

    expect(saved, isEmpty);
  });
}
