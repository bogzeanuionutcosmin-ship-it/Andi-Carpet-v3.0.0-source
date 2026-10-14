import 'dart:async';
import 'dart:convert';

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

  test('snapshot encode failure does not poison later queued writes',
      () async {
    var failClock = false;
    final live = VisionErrorLog(clock: () {
      if (failClock) throw StateError('synthetic transient clock failure');
      return clock;
    });
    final saved = <String>[];
    final local = VisionLocalPersistence(
      log: live,
      read: () async => null,
      write: (snapshot) async { saved.add(snapshot); },
    );
    await local.initialize();
    live.record(area: 'system', code: 'prior_issue', platform: 'android');
    local.changed();
    failClock = true;
    await local.flush();
    expect(local.status.state, VisionPersistenceState.memoryOnly);
    expect(saved, isEmpty);
    failClock = false;
    await local.flush();
    expect(local.status.state, VisionPersistenceState.saved);
    expect(saved, hasLength(1));
    expect(saved.single, contains('prior_issue'));
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

  test('early same-code event keeps older occurrences after delayed restore',
      () async {
    final historicClock = DateTime.utc(2026, 10, 13, 10);
    final historic = VisionErrorLog(clock: () => historicClock);
    for (var i = 0; i < 3; i++) {
      historic.record(area: 'gps', code: 'signal_lost', platform: 'android',
          severity: VisionErrorSeverity.critical);
    }
    expect(historic.resolve('gps/signal_lost/android'), isTrue);
    final loading = Completer<String?>();
    final saved = <String>[];
    final live = freshLog();
    final persistence = VisionLocalPersistence(
      log: live,
      read: () => loading.future,
      write: (snapshot) async { saved.add(snapshot); },
    );
    final initialization = persistence.initialize();
    live.record(area: 'gps', code: 'signal_lost', platform: 'android',
        severity: VisionErrorSeverity.warning);
    persistence.changed();
    final flush = persistence.flush();
    await Future<void>.delayed(Duration.zero);
    expect(saved, isEmpty);
    loading.complete(historic.encode());
    await Future.wait([initialization, flush]);

    final incident = live.entries.single;
    expect(incident.count, 4);
    expect(incident.firstSeen, historicClock);
    expect(incident.lastSeen, clock);
    expect(incident.severity, VisionErrorSeverity.critical);
    expect(incident.resolved, isFalse);
    expect(persistence.status.state, VisionPersistenceState.saved);
    final recovered = freshLog()..restore(saved.single);
    expect(recovered.entries.single.count, 4);
    expect(recovered.entries.single.resolved, isFalse);
  });

  test('initial merge ignores duplicate cache rows and default stays idempotent',
      () async {
    final seed = freshLog()
      ..record(area: 'fcm', code: 'refresh_failed', platform: 'android');
    final payload = jsonDecode(seed.encode()) as Map<String, dynamic>;
    final row = (payload['items'] as List).single;
    final duplicateCache = jsonEncode({
      'version': 1,
      'items': [row, row],
    });
    final live = freshLog();
    live.record(area: 'fcm', code: 'refresh_failed', platform: 'android');
    final saved = <String>[];
    final persistence = VisionLocalPersistence(
      log: live,
      read: () async => duplicateCache,
      write: (snapshot) async { saved.add(snapshot); },
    );
    persistence.changed();
    await persistence.flush();
    expect(live.entries.single.count, 2);
    expect((freshLog()..restore(saved.single)).entries.single.count, 2);

    final regularRestore = freshLog()
      ..record(area: 'fcm', code: 'refresh_failed', platform: 'android');
    regularRestore.restore(duplicateCache);
    regularRestore.restore(duplicateCache);
    expect(regularRestore.entries.single.count, 1);
  });

  test('critical error burst coalesces 1200 overlapping flushes into two writes',
      () async {
    final firstWrite = Completer<void>();
    final snapshots = <String>[];
    final log = freshLog();
    final persistence = VisionLocalPersistence(
      log: log,
      read: () async => null,
      write: (snapshot) async {
        snapshots.add(snapshot);
        if (snapshots.length == 1) await firstWrite.future;
      },
    );
    await persistence.initialize();
    log.record(area: 'system', code: 'critical_burst', platform: 'android',
        severity: VisionErrorSeverity.critical);
    persistence.changed();
    final pending = <Future<void>>[persistence.flush()];
    await Future<void>.delayed(Duration.zero);
    expect(snapshots, hasLength(1));
    for (var i = 0; i < 1200; i++) {
      log.record(area: 'system', code: 'critical_burst', platform: 'android',
          severity: VisionErrorSeverity.critical);
      persistence.changed();
      pending.add(persistence.flush());
    }
    expect(snapshots, hasLength(1));
    expect(persistence.status.state, VisionPersistenceState.pending);
    firstWrite.complete();
    await Future.wait(pending);
    expect(snapshots, hasLength(2));
    expect((freshLog()..restore(snapshots.first)).entries.single.count, 1);
    expect((freshLog()..restore(snapshots.last)).entries.single.count, 1201);
    expect(persistence.status.state, VisionPersistenceState.saved);
  });

  test('duplicate flush requests without new events do not add disk writes',
      () async {
    final held = Completer<void>();
    var writes = 0;
    final log = freshLog();
    final persistence = VisionLocalPersistence(
      log: log,
      read: () async => null,
      write: (_) async {
        writes++;
        await held.future;
      },
    );
    log.record(area: 'gps', code: 'startup_error', platform: 'android');
    persistence.changed();
    final pending = <Future<void>>[persistence.flush()];
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 40; i++) {
      pending.add(persistence.flush());
    }
    held.complete();
    await Future.wait(pending);
    expect(writes, 1);
    expect(persistence.status.state, VisionPersistenceState.saved);
  });

  test('a failed first burst write permits a newer coalesced revision',
      () async {
    final held = Completer<void>();
    var attempts = 0;
    String? saved;
    final log = freshLog();
    final persistence = VisionLocalPersistence(
      log: log,
      read: () async => null,
      write: (snapshot) async {
        attempts++;
        if (attempts == 1) {
          await held.future;
          throw StateError('synthetic storage failure');
        }
        saved = snapshot;
      },
    );
    log.record(area: 'ocr', code: 'first_failure', platform: 'android');
    persistence.changed();
    final first = persistence.flush();
    await Future<void>.delayed(Duration.zero);
    log.record(area: 'ocr', code: 'second_failure', platform: 'android');
    persistence.changed();
    final later = persistence.flush();
    held.complete();
    await Future.wait([first, later]);
    expect(attempts, 2);
    expect((freshLog()..restore(saved)).length, 2);
    expect(persistence.status.state, VisionPersistenceState.saved);
  });
}
