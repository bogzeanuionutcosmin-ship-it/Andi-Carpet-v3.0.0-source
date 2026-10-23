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

  test('encodes user and team scope without separator collisions', () async {
    final first = DashboardRecordIntent(
      userId: 'a_b', teamId: 'c', recordId: 'first', transition: 'finish',
      desired: {...payload, 'teamId': 'c'},
      expected: {...baseline, 'teamId': 'c'},
    );
    final second = DashboardRecordIntent(
      userId: 'a', teamId: 'b_c', recordId: 'second', transition: 'finish',
      desired: {...payload, 'teamId': 'b_c'},
      expected: {...baseline, 'teamId': 'b_c'},
    );
    await journal().persist(first);
    await journal().persist(second);

    expect(disk.keys, hasLength(2));
    expect((await journal().pending(userId: 'a_b', teamId: 'c'))?.recordId, 'first');
    expect((await journal().pending(userId: 'a', teamId: 'b_c'))?.recordId, 'second');
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

  test('rejects a payload whose identity does not match its durable scope', () async {
    final malformed = intent(desired: {...payload, 'teamId': 'team-b'});
    await expectLater(
      journal().run(candidate: malformed, send: (_) async => fail('must not send a mismatched payload')),
      throwsFormatException,
    );
    expect(disk, isEmpty);
  });

  test('serializes concurrent writes for the same user and team scope', () async {
    final gate = Completer<void>();
    final first = journal().run(candidate: intent(), send: (_) => gate.future);
    // Let the first run reach send after it has claimed the in-process scope.
    for (var turn = 0; turn < 5 && disk.isEmpty; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    await expectLater(
      journal().run(candidate: intent(), send: (_) async => fail('must not race the first operation')),
      throwsStateError,
    );
    gate.complete();
    await first;
    expect(disk, isEmpty);
  });
}
