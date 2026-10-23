import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/dashboard/dashboard_record_journal.dart';

void main() {
  late Map<String, String> disk;
  DashboardRecordJournal journal() => DashboardRecordJournal(
        read: (key) async => disk[key],
        write: (key, value) async { disk[key] = value; },
        remove: (key) async { disk.remove(key); },
      );

  final payload = <String, dynamic>{
    'teamId': 'team-a',
    'locationId': 'room-2',
    'interventionId': 'visit-7',
    'status': 'completed',
    'startedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 23, 8)),
    'finishedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 23, 9)),
    'facadeDone': true,
  };
  final baseline = <String, dynamic>{
    'teamId': 'team-a',
    'locationId': 'room-2',
    'interventionId': 'visit-7',
    'status': 'running',
    'startedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 23, 8)),
    'finishedAt': null,
  };

  DashboardRecordIntent intent({Map<String, dynamic>? desired}) => DashboardRecordIntent(
        userId: 'user-a',
        teamId: 'team-a',
        recordId: 'iv_visit-7_1',
        transition: 'finish',
        desired: desired ?? payload,
        expected: baseline,
      );

  setUp(() => disk = {});

  test('persists the exact operation before sending and replays it after restart', () async {
    final original = intent();
    await expectLater(
      journal().run(candidate: original, send: (sent) async {
        expect(disk, hasLength(1), reason: 'write the journal before network access');
        expect(sent.recordId, original.recordId);
        throw TimeoutException('acknowledgement was lost');
      }),
      throwsA(isA<TimeoutException>()),
    );

    final restarted = journal();
    final recovered = await restarted.pending(userId: 'user-a', teamId: 'team-a');
    expect(recovered, isNotNull);
    expect(recovered!.sameOperation(original), isTrue);
    expect(recovered.desired['finishedAt'], isA<Timestamp>());
    expect((recovered.desired['finishedAt'] as Timestamp).toDate(), DateTime.utc(2026, 10, 23, 9));

    await restarted.run(candidate: original, send: (sent) async {
      expect(sent.sameOperation(original), isTrue);
    });
    expect(disk, isEmpty);
  });

  test('refuses to overwrite an unresolved operation with a different payload', () async {
    final original = intent();
    await journal().persist(original);
    final different = intent(desired: {...payload, 'facadeDone': false});

    await expectLater(
      journal().run(candidate: different, send: (_) async => fail('must not send a conflicting operation')),
      throwsStateError,
    );
    expect((await journal().pending(userId: 'user-a', teamId: 'team-a'))!.sameOperation(original), isTrue);
  });

  test('keeps corrupt journal contents instead of silently replacing them', () async {
    await journal().persist(intent());
    final key = disk.keys.single;
    disk[key] = '{not-json';

    await expectLater(journal().pending(userId: 'user-a', teamId: 'team-a'), throwsStateError);
    expect(disk[key], '{not-json');
  });

  test('keeps independent users and teams in separate journals', () async {
    await journal().persist(intent());
    expect(await journal().pending(userId: 'user-b', teamId: 'team-a'), isNull);
    expect(await journal().pending(userId: 'user-a', teamId: 'team-b'), isNull);
  });

  test('does not send a record transition if secure storage cannot persist it', () async {
    final broken = DashboardRecordJournal(
      read: (_) async => null,
      write: (_, __) async => throw StateError('secure storage unavailable'),
      remove: (_) async {},
    );
    await expectLater(
      broken.run(candidate: intent(), send: (_) async => fail('must not write without a durable intent')),
      throwsStateError,
    );
  });
}
