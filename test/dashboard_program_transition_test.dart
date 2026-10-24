import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  final date = DateTime(2026, 10, 20);

  app.WorkSchedule schedule({
    required String id,
    required String teamId,
    required String graphId,
    bool started = false,
    bool paused = false,
    bool closed = false,
  }) =>
      app.WorkSchedule(
        id: id,
        teamId: teamId,
        graphId: graphId,
        graphName: 'Grafic',
        date: date,
        items: [
          app.ScheduleItem(
            locationId: 'room-$id',
            locationNameSnapshot: 'Sala $id',
            addressSnapshot: 'Adresa $id',
            typeSnapshot: app.LocationType.magic,
            categoryIdSnapshot: 'category',
            order: 3,
            transferred: true,
            facadePlanned: true,
          ),
        ],
        started: started,
        paused: paused,
        closed: closed,
        active: false,
        postponed: true,
        autoProposed: true,
        departureName: 'Plecare veche',
        departureLatitude: 44.1,
        departureLongitude: 26.1,
        returnName: 'Destinație veche',
        returnLatitude: 45.1,
        returnLongitude: 27.1,
        updatedAt: DateTime(2026, 10, 19),
        persisted: true,
        writeToken: 'token-$id',
      );

  test('START scopes by both team and graph and preserves source order', () {
    final first = schedule(id: 'first', teamId: 'team-a', graphId: 'graph-1', paused: true, closed: true);
    final otherTeam = schedule(id: 'other-team', teamId: 'team-b', graphId: 'graph-1');
    final otherGraph = schedule(id: 'other-graph', teamId: 'team-a', graphId: 'graph-2');
    final selected = schedule(id: 'selected', teamId: 'team-a', graphId: 'graph-1');

    final result = app.dashboardSchedulesForGraphStart(
      schedules: [first, otherTeam, otherGraph, selected],
      selectedSchedule: selected,
      departureName: 'Brăila',
      departureLatitude: 45.27,
      departureLongitude: 27.96,
      returnName: 'Galați',
      returnLatitude: 45.44,
      returnLongitude: 28.04,
    );

    expect(result.map((item) => item.id), ['first', 'selected']);
    for (final item in result) {
      expect(item.teamId, 'team-a');
      expect(item.graphId, 'graph-1');
      expect(item.started, isTrue);
      expect(item.paused, isFalse);
      expect(item.closed, isFalse);
      expect(item.departureName, 'Brăila');
      expect(item.departureLatitude, 45.27);
      expect(item.departureLongitude, 27.96);
      expect(item.returnName, 'Galați');
      expect(item.returnLatitude, 45.44);
      expect(item.returnLongitude, 28.04);
      expect(item.active, isFalse);
      expect(item.postponed, isTrue);
      expect(item.autoProposed, isTrue);
      expect(item.persisted, isTrue);
    }
    expect(identical(result.first, first), isFalse);
    expect(identical(result.first.items.single, first.items.single), isFalse);
    expect(first.started, isFalse);
    expect(first.paused, isTrue);
    expect(first.closed, isTrue);
    expect(first.departureName, 'Plecare veche');
  });

  test('STOP clears started and paused on a copy and preserves other state', () {
    final original = schedule(
      id: 'stop',
      teamId: 'team-a',
      graphId: 'graph-1',
      started: true,
      paused: true,
      closed: true,
    );

    final updated = app.dashboardScheduleForGraphStop(original);

    expect(updated.started, isFalse);
    expect(updated.paused, isFalse);
    expect(updated.closed, isTrue);
    expect(updated.active, isFalse);
    expect(updated.departureName, 'Plecare veche');
    expect(updated.returnLatitude, 45.1);
    expect(updated.writeToken, 'token-stop');
    expect(updated.persisted, isTrue);
    expect(identical(updated, original), isFalse);
    expect(identical(updated.items.single, original.items.single), isFalse);
    expect(original.started, isTrue);
    expect(original.paused, isTrue);
  });
}
