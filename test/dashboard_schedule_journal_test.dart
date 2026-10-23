import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/dashboard/dashboard_schedule_journal.dart';

void main() {
  late Map<String, String> disk;
  late Map<String, Map<String, dynamic>> documents;
  final baselineAt = Timestamp.fromDate(DateTime.utc(2026, 10, 23, 7));
  final committedAt = Timestamp.fromDate(DateTime.utc(2026, 10, 23, 8));

  DashboardScheduleJournal journal() => DashboardScheduleJournal(
        read: (key) async => disk[key],
        write: (key, value) async { disk[key] = value; },
        remove: (key) async { disk.remove(key); },
      );

  DashboardScheduleIntent candidate({String graphId = 'graph-a'}) {
    final writes = <DashboardScheduleWrite>[];
    for (final id in ['day-a', 'day-b']) {
      writes.add(DashboardScheduleWrite(
        scheduleId: id,
        expectedExists: true,
        expectedUpdatedAt: baselineAt,
        expectedWriteToken: 'baseline-$id',
        desired: {
          'teamId': 'team-a',
          'graphId': graphId,
          'graphName': 'Grafic',
          'date': Timestamp.fromDate(DateTime.utc(2026, 10, 23)),
          'started': true,
          'paused': false,
          'updatedAt': committedAt,
          'writeToken': 'operation-$id',
          'items': [
            {'locationId': 'room-$id', 'order': 1},
          ],
        },
      ));
    }
    return DashboardScheduleIntent(
      userId: 'user-a', teamId: 'team-a', graphId: graphId,
      transition: 'start', writes: writes,
    );
  }

  Map<String, dynamic> original(String id) => {
        'teamId': 'team-a',
        'graphId': 'graph-a',
        'started': false,
        'paused': true,
        'updatedAt': baselineAt,
        'writeToken': 'baseline-$id',
      };

  setUp(() {
    disk = {};
    documents = {'day-a': original('day-a'), 'day-b': original('day-b')};
  });

  test('lost acknowledgement replays the exact multi-day write as a no-op', () async {
    final operation = candidate();
    await expectLater(journal().run(candidate: operation, send: (pending) async {
      final plan = dashboardScheduleWritePlan(
        intent: pending,
        currentDocuments: pending.writes.map((write) => documents[write.scheduleId]).toList(),
      );
      expect(plan, DashboardScheduleWritePlan.write);
      for (final write in pending.writes) {
        documents[write.scheduleId] = {...documents[write.scheduleId]!, ...write.desired};
      }
      throw TimeoutException('transaction committed; acknowledgement was lost');
    }), throwsA(isA<TimeoutException>()));

    final restarted = journal();
    final pending = await restarted.pending(userId: 'user-a', teamId: 'team-a');
    expect(pending, isNotNull);
    expect(pending!.sameOperation(operation), isTrue);
    expect((pending.writes.first.desired['updatedAt'] as Timestamp).toDate().isAtSameMomentAs(DateTime.utc(2026, 10, 23, 8)), isTrue);
    expect(pending.writes.first.desired['writeToken'], 'operation-day-a');

    await restarted.run(candidate: operation, send: (replay) async {
      expect(dashboardScheduleWritePlan(
        intent: replay,
        currentDocuments: replay.writes.map((write) => documents[write.scheduleId]).toList(),
      ), DashboardScheduleWritePlan.replay);
    });
    expect(disk, isEmpty);
  });

  test('transaction plan writes only when every day matches its CAS baseline', () {
    expect(dashboardScheduleWritePlan(
      intent: candidate(),
      currentDocuments: [documents['day-a'], documents['day-b']],
    ), DashboardScheduleWritePlan.write);
  });

  test('decoded writes validate against the enclosing START or STOP intent', () {
    final start = candidate().toJson();
    expect(DashboardScheduleIntent.fromJson(start).transition, 'start');
    final mismatch = {...start, 'transition': 'stop'};
    expect(() => DashboardScheduleIntent.fromJson(mismatch), throwsFormatException);
    final stop = {
      ...mismatch,
      'writes': (start['writes'] as List).map((row) => {
        ...row as Map<String, dynamic>,
        'desired': {...row['desired'] as Map<String, dynamic>, 'started': false},
      }).toList(),
    };
    expect(DashboardScheduleIntent.fromJson(stop).transition, 'stop');
  });

  test('transaction plan fails closed for a changed or mixed batch', () {
    final operation = candidate();
    final changed = {...documents['day-b']!, 'writeToken': 'other-device'};
    expect(() => dashboardScheduleWritePlan(
      intent: operation,
      currentDocuments: [documents['day-a'], changed],
    ), throwsStateError);

    documents['day-a'] = {...documents['day-a']!, ...operation.writes.first.desired};
    expect(() => dashboardScheduleWritePlan(
      intent: operation,
      currentDocuments: [documents['day-a'], documents['day-b']],
    ), throwsStateError);

    documents['day-a'] = original('day-a');
    final retargeted = {...documents['day-b']!, 'teamId': 'team-b'};
    expect(() => dashboardScheduleWritePlan(
      intent: operation,
      currentDocuments: [documents['day-a'], retargeted],
    ), throwsStateError);
  });

  test('rejects scope mismatches and duplicate schedule IDs before persistence', () async {
    final valid = candidate();
    final wrongScope = DashboardScheduleIntent(
      userId: valid.userId, teamId: valid.teamId, graphId: 'other-graph',
      transition: valid.transition, writes: valid.writes,
    );
    await expectLater(
      journal().run(candidate: wrongScope, send: (_) async => fail('must not send')),
      throwsA(isA<FormatException>()),
    );

    final duplicate = DashboardScheduleIntent(
      userId: 'user-a', teamId: 'team-a', graphId: 'graph-a', transition: 'start',
      writes: [candidate().writes.first, candidate().writes.first],
    );
    await expectLater(
      journal().run(candidate: duplicate, send: (_) async => fail('must not send')),
      throwsA(isA<FormatException>()),
    );
    expect(disk, isEmpty);
  });

  test('stores journals for independent users and leaves corrupt data intact', () async {
    await journal().run(candidate: candidate(), send: (_) async => throw StateError('offline'))
        .catchError((_) {});
    expect(await journal().pending(userId: 'user-b', teamId: 'team-a'), isNull);
    final key = disk.keys.single;
    disk[key] = '{invalid';
    await expectLater(journal().pending(userId: 'user-a', teamId: 'team-a'), throwsStateError);
    expect(disk[key], '{invalid');
  });

  test('secure storage failure blocks the network send', () async {
    final broken = DashboardScheduleJournal(
      read: (_) async => null,
      write: (_, __) async => throw StateError('secure storage unavailable'),
      remove: (_) async {},
    );
    var sent = false;
    await expectLater(
      broken.run(candidate: candidate(), send: (_) async { sent = true; }),
      throwsStateError,
    );
    expect(sent, isFalse);
  });
}
