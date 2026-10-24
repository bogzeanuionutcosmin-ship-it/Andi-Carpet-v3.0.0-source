import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.CentralizerRecord record({
  required String id,
  String teamId = 'team-a',
  String locationId = 'room-1',
  app.WorkAttemptStatus status = app.WorkAttemptStatus.completed,
  DateTime? startedAt,
  DateTime? finishedAt,
  DateTime? waitingStartedAt,
  DateTime? waitingEndedAt,
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
  waitingStartedAt: waitingStartedAt,
  waitingEndedAt: waitingEndedAt,
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

  group('dashboardRunningRecords', () {
    test('keeps open same-team running records and sorts newest first', () {
      final records = [
        record(
          id: 'historical',
          status: app.WorkAttemptStatus.running,
          startedAt: DateTime(2026, 10, 18, 9),
        ),
        record(
          id: 'latest',
          status: app.WorkAttemptStatus.running,
          startedAt: DateTime(2026, 10, 20, 12),
        ),
        record(
          id: 'other-team',
          teamId: 'team-b',
          status: app.WorkAttemptStatus.running,
          startedAt: DateTime(2026, 10, 20, 14),
        ),
        record(id: 'missing-start', status: app.WorkAttemptStatus.running),
        record(
          id: 'finished',
          status: app.WorkAttemptStatus.running,
          startedAt: DateTime(2026, 10, 20, 15),
          finishedAt: DateTime(2026, 10, 20, 16),
        ),
        record(
          id: 'completed',
          status: app.WorkAttemptStatus.completed,
          startedAt: DateTime(2026, 10, 20, 13),
          finishedAt: DateTime(2026, 10, 20, 14),
        ),
      ];

      expect(
        app.dashboardRunningRecords(records, teamId: 'team-a').map((r) => r.id),
        ['latest', 'historical'],
      );
    });
  });

  group('dashboardWaitingRecords', () {
    final workDate = DateTime(2026, 10, 20);

    test('keeps same-team open wait records on the work date newest first', () {
      final records = [
        record(
          id: 'latest',
          status: app.WorkAttemptStatus.waitingAccess,
          startedAt: DateTime(2026, 10, 20, 12),
          waitingStartedAt: DateTime(2026, 10, 20, 12),
        ),
        record(
          id: 'earlier',
          status: app.WorkAttemptStatus.waitingAccess,
          startedAt: DateTime(2026, 10, 20, 8),
          waitingStartedAt: DateTime(2026, 10, 20, 8),
        ),
        record(
          id: 'last-night',
          status: app.WorkAttemptStatus.waitingAccess,
          startedAt: DateTime(2026, 10, 19, 23, 45),
          waitingStartedAt: DateTime(2026, 10, 19, 23, 45),
        ),
        record(
          id: 'old-work-date',
          status: app.WorkAttemptStatus.waitingAccess,
          startedAt: DateTime(2026, 10, 19, 22),
          waitingStartedAt: DateTime(2026, 10, 19, 22),
        ),
        record(
          id: 'other-team',
          teamId: 'team-b',
          status: app.WorkAttemptStatus.waitingAccess,
          startedAt: DateTime(2026, 10, 20, 14),
          waitingStartedAt: DateTime(2026, 10, 20, 14),
        ),
        record(
          id: 'ended',
          status: app.WorkAttemptStatus.waitingAccess,
          startedAt: DateTime(2026, 10, 20, 15),
          waitingStartedAt: DateTime(2026, 10, 20, 15),
          waitingEndedAt: DateTime(2026, 10, 20, 16),
        ),
        record(
          id: 'running',
          status: app.WorkAttemptStatus.running,
          startedAt: DateTime(2026, 10, 20, 13),
          waitingStartedAt: DateTime(2026, 10, 20, 13),
        ),
      ];

      expect(
        app.dashboardWaitingRecords(
          records,
          teamId: 'team-a',
          workDate: workDate,
        ).map((r) => r.id),
        ['latest', 'earlier', 'last-night'],
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
