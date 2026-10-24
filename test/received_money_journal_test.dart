import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/received_money_journal.dart';
import 'package:andi_carpeta/models/app_data_models.dart';

void main() {
  late Map<String, String> disk;
  ReceivedMoneyJournal journal() => ReceivedMoneyJournal(read: (key) async => disk[key],
    write: (key, value) async { disk[key] = value; }, remove: (key) async { disk.remove(key); });
  final entry = ReceivedMoneyEntry(id: 'stable-id', kind: 'during', amount: 12.34,
    method: 'Transfer', fromName: 'Client', date: DateTime.utc(2026, 10, 23));
  setUp(() { disk = {}; });

  test('replays the exact durable entry after an uncertain acknowledgement', () async {
    await expectLater(journal().run(userId: 'u', teamId: 't', targetId: 's', candidate: entry,
      send: (sent) async {
        expect(sent.id, entry.id);
        expect(disk, hasLength(1), reason: 'journal precedes network write');
        throw TimeoutException('commit may have succeeded');
      }), throwsA(isA<TimeoutException>()));
    final restarted = journal();
    final pending = await restarted.pending(userId: 'u', teamId: 't', targetId: 's');
    expect(pending?.id, entry.id);
    expect(pending?.date, entry.date);
    final replay = ReceivedMoneyEntry(id: 'new-dialog-id', kind: 'departure', amount: 5,
      method: 'Cash', fromName: 'Other', date: DateTime.utc(2026, 10, 24));
    await restarted.run(userId: 'u', teamId: 't', targetId: 's', candidate: replay,
      send: (sent) async { expect(sent.id, entry.id); return true; });
    expect(disk, isEmpty);
  });

  test('keeps scopes isolated and corrupt records fail closed', () async {
    await journal().persist(userId: 'u1', teamId: 't', targetId: 's', entry: entry);
    expect(await journal().pending(userId: 'u2', teamId: 't', targetId: 's'), isNull);
    final key = disk.keys.single;
    disk[key] = '{broken';
    await expectLater(journal().pending(userId: 'u1', teamId: 't', targetId: 's'), throwsStateError);
    expect(disk[key], '{broken', reason: 'never overwrite an unreadable intent');
  });

  test('does not send if durable storage is unavailable', () async {
    final broken = ReceivedMoneyJournal(read: (_) async => null,
      write: (_, _) async => throw StateError('storage unavailable'), remove: (_) async {});
    await expectLater(broken.run(userId: 'u', teamId: 't', targetId: 's', candidate: entry,
      send: (_) async => fail('must not send')), throwsStateError);
  });
}
