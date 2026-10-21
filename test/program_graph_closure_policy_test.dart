import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.WorkSchedule day({
  List<app.ScheduleItem>? items,
  DateTime? date,
}) => app.WorkSchedule(
  id: 'day-1', teamId: 'team-1', graphId: 'graph-1', graphName: 'Graph',
  date: date ?? DateTime(2026, 10, 21),
  items: items ?? [
    app.ScheduleItem(
      locationId: 'carpet', locationNameSnapshot: 'Carpet room',
      addressSnapshot: 'Street 1', typeSnapshot: app.LocationType.magic,
      order: 1,
    ),
  ],
);

app.CentralizerRecord attempt({
  required app.WorkAttemptStatus status,
  required DateTime at,
  String? reason,
  String id = 'attempt',
  bool facadePlanned = false,
  bool facadeDone = false,
}) => app.CentralizerRecord(
  id: id, teamId: 'team-1', locationId: 'carpet',
  type: app.LocationType.magic, locationNameSnapshot: 'Carpet room',
  addressSnapshot: 'Street 1', startedAt: at,
  finishedAt: status == app.WorkAttemptStatus.running ? null : at.add(const Duration(minutes: 5)),
  status: status, refusalReason: reason,
  facadePlanned: facadePlanned, facadeDone: facadeDone,
);

void main() {
  test('STOP is blocked for unstarted, refused, and unfinished interventions', () {
    final refused = attempt(status: app.WorkAttemptStatus.refused, at: DateTime(2026, 10, 21, 9));
    final refusedState = app.programGraphClosureReadiness(schedules: [day()], records: [refused]);
    expect(refusedState.canClose, isFalse);
    expect(refusedState.blockers.single, contains('refuzată, încă restantă'));

    final running = attempt(status: app.WorkAttemptStatus.running, at: DateTime(2026, 10, 21, 9));
    expect(app.programGraphClosureReadiness(schedules: [day()], records: [running]).canClose, isFalse);
    expect(app.programGraphClosureReadiness(schedules: [day()], records: []).canClose, isFalse);
  });

  test('STOP permits completed work and explained not-completed decisions', () {
    final completed = attempt(status: app.WorkAttemptStatus.completed, at: DateTime(2026, 10, 21, 9));
    expect(app.programGraphClosureReadiness(schedules: [day()], records: [completed]).canClose, isTrue);

    final explained = attempt(
      status: app.WorkAttemptStatus.notCompleted,
      at: DateTime(2026, 10, 21, 9), reason: 'Mocheta schimbată recent',
    );
    expect(app.programGraphClosureReadiness(schedules: [day()], records: [explained]).canClose, isTrue);

    final missingReason = attempt(status: app.WorkAttemptStatus.notCompleted, at: DateTime(2026, 10, 21, 9));
    expect(app.programGraphClosureReadiness(schedules: [day()], records: [missingReason]).canClose, isFalse);

    final unfinalizedWithReason = app.CentralizerRecord(
      id:'unfinalized', teamId:'team-1', locationId:'carpet',
      type:app.LocationType.magic, locationNameSnapshot:'Carpet room',
      addressSnapshot:'Street 1', startedAt:DateTime(2026,10,21,9),
      status:app.WorkAttemptStatus.notCompleted, refusalReason:'Lipsă acces',
    );
    expect(app.programGraphClosureReadiness(schedules:[day()],records:[unfinalizedWithReason]).canClose,isFalse,
      reason:'a reason without a persisted terminal timestamp is not a final decision');
  });

  test('latest same-day retry decides readiness; facade does not replace carpet work', () {
    final refused = attempt(status: app.WorkAttemptStatus.refused, at: DateTime(2026, 10, 21, 9), id: 'refused');
    final completed = attempt(status: app.WorkAttemptStatus.completed, at: DateTime(2026, 10, 21, 10), id: 'completed');
    expect(app.programGraphClosureReadiness(schedules: [day()], records: [refused, completed]).canClose, isTrue);

    final facade = app.ScheduleItem(
      locationId: 'carpet', locationNameSnapshot: 'Carpet room',
      addressSnapshot: 'Street 1', typeSnapshot: app.LocationType.magic,
      order: 1, facadePlanned: true,
    );
    expect(app.programGraphClosureReadiness(schedules: [day(items: [facade])], records: []).canClose, isFalse,
      reason:'a planned facade cannot make an unstarted carpet intervention disappear');
    final carpetDoneFacadePending = attempt(
      status: app.WorkAttemptStatus.completed,
      at: DateTime(2026, 10, 21, 11), facadePlanned: true, facadeDone: false,
    );
    expect(app.programGraphClosureReadiness(schedules: [day(items: [facade])], records: [carpetDoneFacadePending]).canClose, isTrue,
      reason:'unfinished additional facade work does not block finalized carpet work');
  });

  test('STOP checks every day in the graph, including a later unresolved day', () {
    final firstDay=day(date:DateTime(2026,10,21));
    final secondDay=day(date:DateTime(2026,10,22));
    final completed=attempt(status:app.WorkAttemptStatus.completed,at:DateTime(2026,10,21,9));
    expect(app.programGraphClosureReadiness(schedules:[firstDay,secondDay],records:[completed]).canClose,isFalse,
      reason:'a completed earlier day cannot hide an unstarted later-day intervention');
    final secondCompleted=app.CentralizerRecord(
      id:'second-day',teamId:'team-1',locationId:'carpet',
      type:app.LocationType.magic,locationNameSnapshot:'Carpet room',
      addressSnapshot:'Street 1',startedAt:DateTime(2026,10,22,9),
      finishedAt:DateTime(2026,10,22,9,5),status:app.WorkAttemptStatus.completed,
    );
    expect(app.programGraphClosureReadiness(schedules:[firstDay,secondDay],records:[completed,secondCompleted]).canClose,isTrue);
  });
}
