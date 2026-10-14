import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_local_persistence.dart';
import 'package:andi_carpeta/vision/vision_persistence_status.dart';

void main() {
  final clock = DateTime.utc(2026, 10, 14, 10);

  VisionErrorLog freshLog() =>
      VisionErrorLog(clock: () => clock, maxEntries: 150, maxBytes: 48 * 1024);

  test('delayed restore is included in first write after an early report',
      () async {
    final seed = freshLog()
      ..record(area: 'gps', code: 'earlier_failure', platform: 'android');
    final pendingRead = Completer<String?>();
    final writes = <String>[];
    final live = freshLog();
    final local = VisionLocalPersistence(
      log: live,
      read: () => pendingRead.future,
      write: (snapshot) async { writes.add(snapshot); },
    );
    final loading = local.initialize();
    live.record(area: 'ocr', code: 'save_failed', platform: 'android');
    local.changed();
    final flushing = local.flush();

    await Future<void>.delayed(Duration.zero);
    expect(writes, isEmpty); // Must not overwrite storage before restore.
    pendingRead.complete(seed.encode());
    await Future.wait([loading, flushing]);
    expect(local.status.state, VisionPersistenceState.saved);
    expect(writes, hasLength(1));
    final recovered = freshLog()..restore(writes.single);
    expect(recovered.entries.map((e) => e.code),
        containsAll(<String>['earlier_failure', 'save_failed']));
    expect(recovered.length, 2);
  });

  test('flush initializes lazy read before overwriting stored incidents',
      () async {
    final seed = freshLog()
      ..record(area: 'fcm', code: 'old_token_error', platform: 'android');
    final readGate = Completer<String?>();
    final saved = <String>[];
    final live = freshLog();
    final local = VisionLocalPersistence(
      log: live,
      read: () => readGate.future,
      write: (snapshot) async { saved.add(snapshot); },
    );
    live.record(area: 'gps', code: 'recent_error', platform: 'android');
    local.changed();
    final future = local.flush(); // No explicit initialize.
    await Future<void>.delayed(Duration.zero);
    expect(saved, isEmpty);
    readGate.complete(seed.encode());
    await future;
    final output = freshLog()..restore(saved.single);
    expect(output.entries.map((e) => e.code),
        containsAll(<String>['old_token_error', 'recent_error']));
    expect(local.status.state, VisionPersistenceState.saved);
  });

  test('queued writes serialize and later snapshot includes new incidents',
      () async {
    final gate = Completer<void>();
    final writes = <String>[];
    final live = freshLog();
    final local = VisionLocalPersistence(
      log: live,
      read: () async => null,
      write: (snapshot) async {
        writes.add(snapshot);
        if (writes.length == 1) await gate.future;
      },
    );
    await local.initialize();
    live.record(area: 'ocr', code: 'first', platform: 'android');
    local.changed();
    final first = local.flush();
    await Future<void>.delayed(Duration.zero);
    expect(writes, hasLength(1));
    live.record(area: 'ocr', code: 'second', platform: 'android');
    local.changed();
    final second = local.flush();
    expect(local.status.state, VisionPersistenceState.pending);
    expect(writes, hasLength(1)); // No second parallel write.
    gate.complete();
    await Future.wait([first, second]);
    expect(writes, hasLength(2));
    final oldSnapshot = freshLog()..restore(writes[0]);
    final newSnapshot = freshLog()..restore(writes[1]);
    expect(oldSnapshot.length, 1);
    expect(newSnapshot.length, 2);
    expect(local.status.state, VisionPersistenceState.saved);
  });

  test('read failure is recoverable only after a confirmed local write',
      () async {
    final writes = <String>[];
    final live = freshLog();
    final local = VisionLocalPersistence(
      log: live,
      read: () async => throw StateError('device read failed'),
      write: (snapshot) async { writes.add(snapshot); },
    );
    await local.initialize();
    expect(local.status.state, VisionPersistenceState.memoryOnly);
    live.record(area: 'system', code: 'startup_failed', platform: 'android');
    local.changed();
    expect(local.status.state, VisionPersistenceState.memoryOnly);
    await local.flush();
    expect(local.status.state, VisionPersistenceState.saved);
    expect(writes, hasLength(1));
  });

  test('write failure remains visible until a later successful snapshot',
      () async {
    var attempt = 0;
    final live = freshLog();
    final writes = <String>[];
    final local = VisionLocalPersistence(
      log: live,
      read: () async => null,
      write: (snapshot) async {
        attempt++;
        if (attempt == 1) throw StateError('synthetic write failure');
        writes.add(snapshot);
      },
    );
    await local.initialize();
    live.record(area: 'ocr', code: 'first', platform: 'android');
    local.changed();
    await local.flush();
    expect(local.status.state, VisionPersistenceState.memoryOnly);
    live.record(area: 'gps', code: 'second', platform: 'android');
    local.changed();
    await local.flush();
    expect(local.status.state, VisionPersistenceState.saved);
    expect(attempt, 2);
    final restored = freshLog()..restore(writes.single);
    expect(restored.length, 2);
  });

  test('reject raw incident details without leaking them through persistence',
      () async {
    final writes = <String>[];
    final live = freshLog();
    final local = VisionLocalPersistence(
      log: live,
      read: () async => null,
      write: (snapshot) async { writes.add(snapshot); },
    );
    live.record(area: 'ocr', code: 'token=secret customer@test.example',
        platform: 'android');
    local.changed();
    await local.flush();
    expect(writes.single, isNot(contains('secret')));
    expect(writes.single, isNot(contains('customer@test.example')));
    expect(writes.single, contains('"code":"unknown"'));
  });
}
