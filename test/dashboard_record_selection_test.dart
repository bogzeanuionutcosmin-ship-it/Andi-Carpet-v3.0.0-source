import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.CentralizerRecord record({
  required String id,
  String teamId = 'team-a',
  String locationId = 'room-1',
  app.WorkAttemptStatus status = app.WorkAttemptStatus.completed,
  DateTime? startedAt,
  DateTime? finishedAt,
}) => app.CentralizerRecord(
  id: id,
  teamId: teamId,
  locationId: locationId,
  type: app.LocationType.magic,
  locationNameSnapshot: 'Room',
  addressSnapshot: 'Address',
  status: status,
  startedAt: startedAt,
  finishedAt: finishedAt,
);

void main() {
  group('dashboardRecordsForItem', () {
    final workDate = DateTime(2026, 10, 20);
    final item = app.ScheduleItem(
      locationId: 'room-1',
      locationNameSnapshot: 'Room',
      addressSnapshot: 'Address',
      typeSnapshot: app.LocationType.magic,
      order: 1,
    );

    test('keeps same-team open attempts and sorts completed history before active attempts', () {
      final records = [
        record(id: 'active', status: app.WorkAttemptStatus.running, startedAt: DateTime(2026, 10, 18, 9)),
        record(id: 'latest', startedAt: DateTime(2026, 10, 20, 12), finishedAt: DateTime(2026, 10, 20, 13)),
        record(id: 'earlier', startedAt: DateTime(2026, 10, 20, 8), finishedAt: DateTime(2026, 10, 20, 9)),
        record(id: 'other-team', teamId: 'team-b', startedAt: DateTime(2026, 10, 20, 10), finishedAt: DateTime(2026, 10, 20, 11)),
        record(id: 'other-room', locationId: 'room-2', startedAt: DateTime(2026, 10, 20, 10), finishedAt: DateTime(2026, 10, 20, 11)),
        record(id: 'old-closed', startedAt: DateTime(2026, 10, 17, 8), finishedAt: DateTime(2026, 10, 17, 9)),
      ];

      final result = app.dashboardRecordsForItem(
        records,
        teamId: 'team-a',
        item: item,
        workDate: workDate,
      );

      expect(result.map((r) => r.id), ['earlier', 'latest', 'active']);
    });

    test('includes waiting access records without a finish time', () {
      final waiting = record(
        id: 'waiting',
        status: app.WorkAttemptStatus.waitingAccess,
        startedAt: DateTime(2026, 10, 19, 23),
      );

      expect(
        app.dashboardRecordsForItem(
          [waiting],
          teamId: 'team-a',
          item: item,
          workDate: workDate,
        ).map((r) => r.id),
        ['waiting'],
      );
    });
  });

  test('dashboardCompletedHistory keeps completed timed entries for the location', () {
    final records = [
      record(id: 'completed', startedAt: DateTime(2026, 10, 20, 8), finishedAt: DateTime(2026, 10, 20, 9)),
      record(id: 'unfinished', status: app.WorkAttemptStatus.running, startedAt: DateTime(2026, 10, 20, 10)),
      record(id: 'other-room', locationId: 'room-2', startedAt: DateTime(2026, 10, 20, 8), finishedAt: DateTime(2026, 10, 20, 9)),
    ];

    expect(
      app.dashboardCompletedHistory(records, locationId: 'room-1').map((r) => r.id),
      ['completed'],
    );
  });
}
