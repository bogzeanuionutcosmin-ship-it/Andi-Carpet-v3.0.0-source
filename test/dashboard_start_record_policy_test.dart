import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.CentralizerRecord record({
  required String id,
  required String teamId,
  required String locationId,
  required DateTime at,
  app.WorkAttemptStatus status = app.WorkAttemptStatus.notCompleted,
  DateTime? finishedAt,
}) => app.CentralizerRecord(
      id: id,
      teamId: teamId,
      locationId: locationId,
      type: app.LocationType.magic,
      locationNameSnapshot: 'Location $locationId',
      addressSnapshot: 'Address $locationId',
      startedAt: at,
      finishedAt: finishedAt,
      status: status,
      keptForLearning: true,
    );

app.DashboardStartRecordDecision<app.CentralizerRecord> decide(
  Iterable<app.CentralizerRecord> records,
) => app.dashboardStartRecordDecision<app.CentralizerRecord>(
      records: records,
      teamId: 'team-1',
      locationId: 'location-1',
      teamIdOf: (value) => value.teamId,
      locationIdOf: (value) => value.locationId,
      statusOf: (value) => value.status,
      isRunning: app.WorkAttemptStatus.running,
      finishedAtOf: (value) => value.finishedAt,
      eventTimeOf: (value) => value.startedAt ?? DateTime.utc(2000),
    );

void main() {
  final now = DateTime.utc(2026, 10, 21, 8);

  test('blocks entry when the first running team record is another location', () {
    final other = record(
      id: 'other',
      teamId: 'team-1',
      locationId: 'location-2',
      at: now,
      status: app.WorkAttemptStatus.running,
    );
    final decision = decide([other]);

    expect(decision.action, app.DashboardStartRecordAction.blockedByOtherLocation);
    expect(decision.activeRecord, same(other));
    expect(decision.baseRecord, isNull);
  });

  test('does not start a duplicate while the selected location is already running', () {
    final active = record(
      id: 'active',
      teamId: 'team-1',
      locationId: 'location-1',
      at: now,
      status: app.WorkAttemptStatus.running,
    );
    final decision = decide([active]);

    expect(decision.action, app.DashboardStartRecordAction.alreadyRunning);
    expect(decision.activeRecord, same(active));
  });

  test('uses the latest unfinished same-team record as the update base', () {
    final older = record(
      id: 'older', teamId: 'team-1', locationId: 'location-1', at: now,
    );
    final latest = record(
      id: 'latest',
      teamId: 'team-1',
      locationId: 'location-1',
      at: now.add(const Duration(hours: 1)),
    );
    final otherTeam = record(
      id: 'other-team', teamId: 'team-2', locationId: 'location-1', at: now,
    );
    final completed = record(
      id: 'completed',
      teamId: 'team-1',
      locationId: 'location-1',
      at: now.add(const Duration(hours: 2)),
      finishedAt: now.add(const Duration(hours: 3)),
    );

    final decision = decide([older, otherTeam, completed, latest]);

    expect(decision.action, app.DashboardStartRecordAction.start);
    expect(decision.baseRecord, same(latest));
    expect(decision.activeRecord, isNull);
  });

  test('ignores a running record from another team', () {
    final otherTeam = record(
      id: 'other-team',
      teamId: 'team-2',
      locationId: 'location-2',
      at: now,
      status: app.WorkAttemptStatus.running,
    );

    expect(decide([otherTeam]).action, app.DashboardStartRecordAction.start);
  });
}
