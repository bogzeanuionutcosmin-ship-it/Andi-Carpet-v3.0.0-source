import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.ScheduleItem item(String locationId, int order) => app.ScheduleItem(
  locationId: locationId,
  locationNameSnapshot: locationId,
  addressSnapshot: 'Address',
  typeSnapshot: app.LocationType.magic,
  order: order,
);

app.WorkSchedule schedule(List<app.ScheduleItem> items) => app.WorkSchedule(
  id: 'day-1',
  teamId: 'team-a',
  date: DateTime(2026, 10, 20),
  started: true,
  items: items,
);

app.CentralizerRecord record(
  String locationId, {
  required app.WorkAttemptStatus status,
}) => app.CentralizerRecord(
  id: 'record-$locationId',
  teamId: 'team-a',
  locationId: locationId,
  type: app.LocationType.magic,
  locationNameSnapshot: locationId,
  addressSnapshot: 'Address',
  status: status,
  startedAt: status == app.WorkAttemptStatus.completed
      ? DateTime(2026, 10, 20, 9)
      : null,
  finishedAt: status == app.WorkAttemptStatus.completed
      ? DateTime(2026, 10, 20, 10)
      : null,
);

void main() {
  final completed = record('first', status: app.WorkAttemptStatus.completed);

  app.MapWorkBadgeState? state(
    List<app.WorkSchedule> schedules,
    List<app.CentralizerRecord> records,
    String locationId,
  ) => app.mapWorkBadgeState(
    schedules: schedules,
    locationId: locationId,
    recordsForLocation: (id, teamId) => records.where(
      (record) => record.locationId == id && record.teamId == teamId,
    ),
  );

  test('returns null when the location has no assignment', () {
    expect(state([schedule([item('other', 1)])], [], 'target'), isNull);
  });

  test('shows completed when every assignment is completed', () {
    final day = schedule([item('first', 1), item('target', 2)]);
    final records = [
      completed,
      record('target', status: app.WorkAttemptStatus.completed),
    ];

    expect(state([day], records, 'target'), app.MapWorkBadgeState.completed);
  });

  test('shows next when earlier work is completed and target is the next open item', () {
    final day = schedule([item('first', 1), item('target', 2)]);

    expect(
      state([day], [completed], 'target'),
      app.MapWorkBadgeState.nextOrRunning,
    );
  });

  test('shows in progress for running and waiting-access records', () {
    final day = schedule([item('target', 1)]);

    expect(
      state([day], [record('target', status: app.WorkAttemptStatus.running)], 'target'),
      app.MapWorkBadgeState.nextOrRunning,
    );
    expect(
      state([day], [record('target', status: app.WorkAttemptStatus.waitingAccess)], 'target'),
      app.MapWorkBadgeState.nextOrRunning,
    );
  });

  test('keeps later assignments red while an earlier unworked item blocks them', () {
    final day = schedule([item('first', 1), item('target', 2)]);

    expect(
      state([day], [], 'target'),
      app.MapWorkBadgeState.notCompleted,
    );
  });

  test('shows red for a refused or not-completed target with no pending work', () {
    final day = schedule([item('target', 1)]);
    for (final status in [
      app.WorkAttemptStatus.refused,
      app.WorkAttemptStatus.notCompleted,
    ]) {
      expect(
        state([day], [record('target', status: status)], 'target'),
        app.MapWorkBadgeState.notCompleted,
      );
    }
  });
}
