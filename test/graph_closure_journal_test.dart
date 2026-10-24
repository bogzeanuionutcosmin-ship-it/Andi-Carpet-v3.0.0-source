import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/operations/graph_closure_client.dart';
import 'package:andi_carpeta/operations/graph_closure_journal.dart';

void main() {
  late Map<String, String> disk;
  GraphClosureJournal journal() => GraphClosureJournal(
    read: (key) async => disk[key],
    write: (key, value) async { disk[key] = value; },
    remove: (key) async { disk.remove(key); });
  Map<String, dynamic> operation(String request, [String revision = 'v1']) => {
    'teamId': 'team', 'graphId': 'graph', 'requestId': request,
    'days': [{'id': 'day', 'writeToken': revision}],
  };
  setUp(() { disk = {}; });

  test('new instance recovers exact persisted intent after lost acknowledgement', () async {
    await expectLater(journal().close(projectId: 'demo-a', userId: 'a',
      operation: operation('original'), send: (pending) async {
        expect(disk, hasLength(1), reason: 'Durable write must precede HTTP');
        throw TimeoutException('committed but acknowledgement lost');
      }), throwsA(isA<TimeoutException>()));
    expect(disk, hasLength(1));
    expect(await journal().close(projectId: 'demo-a', userId: 'a',
      operation: operation('new-random-id', 'already-reloaded-revision'),
      send: (pending) async {
        expect(pending, operation('original'));
        return 'server-receipt';
      }), 'server-receipt');
    expect(disk, isEmpty);
  });

  test('project and user changes cannot replay another scope', () async {
    Future<void> retain(String project, String user) async {
      await expectLater(journal().close(projectId: project, userId: user,
        operation: operation('$project-$user'), send: (_) async => throw TimeoutException('offline')),
        throwsA(isA<TimeoutException>()));
    }
    await retain('project-a', 'alice');
    await retain('project-a', 'bob');
    await retain('project-b', 'alice');
    expect(disk, hasLength(3));
  });

  test('explicit rejection retires intent; unknown failure preserves it', () async {
    await expectLater(journal().close(projectId: 'p', userId: 'a', operation: operation('first'),
      send: (_) async => throw StateError('invalid ACK')), throwsStateError);
    expect(disk, hasLength(1));
    await expectLater(journal().close(projectId: 'p', userId: 'a', operation: operation('second'),
      send: (pending) async {
        expect(pending['requestId'], 'first');
        throw GraphClosureRejected('revision conflict');
      }), throwsA(isA<GraphClosureRejected>()));
    expect(disk, isEmpty);
  });

  test('storage failure prevents sending; corrupt intent is never replaced', () async {
    final broken = GraphClosureJournal(read: (_) async => null,
      write: (_, _) async => throw StateError('disk unavailable'), remove: (_) async {});
    await expectLater(broken.close(projectId: 'p', userId: 'a', operation: operation('first'),
      send: (_) async { fail('network before durable storage'); }), throwsStateError);
    await expectLater(journal().close(projectId: 'p', userId: 'a', operation: operation('first'),
      send: (_) async => throw TimeoutException('offline')), throwsA(isA<TimeoutException>()));
    disk[disk.keys.single] = 'corrupt';
    await expectLater(journal().close(projectId: 'p', userId: 'a', operation: operation('second'),
      send: (_) async { fail('corrupt journal sent'); }), throwsStateError);
    expect(disk.values.single, 'corrupt');
  });

  test('concurrent STOP for one scope cannot replace an in-flight intent', () async {
    final entered = Completer<void>();
    final reply = Completer<String>();
    final first = journal().close(projectId: 'p', userId: 'a', operation: operation('first'),
      send: (_) { entered.complete(); return reply.future; });
    await entered.future;
    await expectLater(journal().close(projectId: 'p', userId: 'a', operation: operation('second'),
      send: (_) async { fail('concurrent STOP sent'); }), throwsStateError);
    reply.complete('receipt');
    expect(await first, 'receipt');
    expect(disk, isEmpty);
  });
}
