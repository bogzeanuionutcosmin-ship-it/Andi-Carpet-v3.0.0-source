import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_local_persistence.dart';
import 'package:andi_carpeta/vision/vision_persistence_status.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15);
  VisionErrorLog journal() => VisionErrorLog(
    clock: () => now, maxEntries: 150, maxBytes: 48 * 1024);
  void event(VisionErrorLog log, VisionLocalPersistence local, String code) {
    log.record(area: 'system', code: code, platform: 'android',
      severity: VisionErrorSeverity.critical);
    local.changed();
  }

  test('1200 critical flushes behind restore share one drain and one snapshot', () async {
    final read = Completer<String?>();
    final writes = <String>[];
    final log = journal();
    var reads = 0;
    final local = VisionLocalPersistence(log: log,
      read: () { reads++; return read.future; },
      write: (s) async { writes.add(s); });
    Future<void>? drain;
    for (var i = 0; i < 1200; i++) {
      event(log, local, 'burst');
      final next = local.flush();
      drain ??= next;
      expect(identical(drain, next), isTrue);
    }
    await Future<void>.delayed(Duration.zero);
    expect(reads, 1); expect(writes, isEmpty);
    expect(local.status.state, VisionPersistenceState.pending);
    read.complete(null); await drain;
    expect(writes, hasLength(1));
    expect((journal()..restore(writes.single)).entries.single.count, 1200);
    expect(local.status.state, VisionPersistenceState.saved);
    for (var i = 0; i < 20; i++) { await local.flush(); }
    expect(writes, hasLength(1));
  });

  test('blocked write coalesces 1200 newer requests into one final snapshot', () async {
    final gate = Completer<void>();
    final writes = <String>[];
    final log = journal();
    final local = VisionLocalPersistence(log: log, read: () async => null,
      write: (s) async { writes.add(s); if (writes.length == 1) await gate.future; });
    event(log, local, 'burst'); final drain = local.flush();
    await Future<void>.delayed(Duration.zero);
    expect(writes, hasLength(1));
    for (var i = 0; i < 1200; i++) {
      event(log, local, 'burst');
      expect(identical(local.flush(), drain), isTrue);
    }
    expect(local.status.state, VisionPersistenceState.pending);
    gate.complete(); await drain;
    expect(writes, hasLength(2));
    expect((journal()..restore(writes.last)).entries.single.count, 1201);
    expect(local.status.state, VisionPersistenceState.saved);
  });

  test('new event during write is drained even without a second flush', () async {
    final gate = Completer<void>(); final writes = <String>[];
    final log = journal();
    final local = VisionLocalPersistence(log: log, read: () async => null,
      write: (s) async { writes.add(s); if (writes.length == 1) await gate.future; });
    event(log, local, 'first'); final drain = local.flush();
    await Future<void>.delayed(Duration.zero);
    event(log, local, 'second'); gate.complete(); await drain;
    expect(writes, hasLength(2));
    expect((journal()..restore(writes.last)).length, 2);
    expect(local.status.state, VisionPersistenceState.saved);
  });

  test('same-revision failure stops and explicit retry recovers once', () async {
    var attempts = 0; final log = journal(); final saved = <String>[];
    final local = VisionLocalPersistence(log: log, read: () async => null,
      write: (s) async { attempts++; if (attempts == 1) throw StateError('unavailable'); saved.add(s); });
    event(log, local, 'failure'); await local.flush();
    expect(attempts, 1); expect(local.status.state, VisionPersistenceState.memoryOnly);
    await Future<void>.delayed(Duration.zero); expect(attempts, 1);
    await local.flush(); expect(attempts, 2);
    expect(local.status.state, VisionPersistenceState.saved);
    await local.flush(); expect(attempts, 2); expect(saved, hasLength(1));
  });

  test('TTL expiry persists a changed snapshot without a new revision', () async {
    var time = now; final writes = <String>[];
    final log = VisionErrorLog(clock: () => time, maxEntries: 150, maxBytes: 48 * 1024);
    final local = VisionLocalPersistence(log: log, read: () async => null,
      write: (s) async { writes.add(s); });
    event(log, local, 'expired'); await local.flush();
    time = time.add(const Duration(days: 8)); await local.flush();
    expect(writes, hasLength(2)); expect(writes.last, contains('"items":[]'));
    await local.flush(); expect(writes, hasLength(2));
  });

  test('late failed write cannot certify newer events and recovery contains both', () async {
    final gate = Completer<void>(); var attempts = 0; final writes = <String>[];
    final log = journal();
    final local = VisionLocalPersistence(log: log, read: () async => null,
      write: (s) async { attempts++; if (attempts == 1) { await gate.future; throw StateError('late'); } writes.add(s); });
    event(log, local, 'first'); final drain = local.flush();
    await Future<void>.delayed(Duration.zero);
    event(log, local, 'second'); gate.complete(); await drain;
    expect(attempts, 2); expect((journal()..restore(writes.single)).length, 2);
    expect(local.status.state, VisionPersistenceState.saved);
  });
}
