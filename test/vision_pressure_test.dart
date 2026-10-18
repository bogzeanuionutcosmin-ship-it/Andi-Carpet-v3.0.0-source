import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_local_persistence.dart';
import 'package:andi_carpeta/vision/vision_persistence_status.dart';

void main() {
  final start = DateTime.utc(2026, 10, 15);
  VisionErrorLog bounded(DateTime Function() clock) => VisionErrorLog(
    clock: clock, maxEntries: 150, maxBytes: 48 * 1024);

  test('10000 duplicate reports use bounded summaries and one shared drain', () async {
    final log = bounded(() => start); final gate = Completer<String?>();
    final writes = <String>[];
    final local = VisionLocalPersistence(log: log, read: () => gate.future,
      write: (s) async { writes.add(s); });
    Future<void>? shared;
    for (var i = 0; i < 10000; i++) {
      log.record(area: 'gps', code: 'pressure', platform: 'android',
        severity: VisionErrorSeverity.values[i % 3]);
      local.changed(); final flush = local.flush(); shared ??= flush;
      expect(identical(shared, flush), isTrue);
    }
    expect(log.length, 1); expect(log.entries.single.count, 10000);
    expect(log.entries.single.severity, VisionErrorSeverity.critical);
    gate.complete(null); await shared;
    expect(writes, hasLength(1)); expect(utf8.encode(writes.single).length, lessThan(1024));
    expect(local.status.state, VisionPersistenceState.saved);
    expect((bounded(() => start)..restore(writes.single)).entries.single.count, 10000);
  });

  test('150 distinct fingerprints and severity eviction stay under both caps', () {
    final log = bounded(() => start);
    for (var i = 0; i < 150; i++) {
      log.record(area: 'gps', code: 'event_$i', platform: 'android',
        severity: i < 10 ? VisionErrorSeverity.critical : VisionErrorSeverity.error);
    }
    expect(log.length, 150); expect(log.encodedBytes, lessThanOrEqualTo(48 * 1024));
    for (var i = 0; i < 10; i++) { log.resolve('gps/event_${i + 10}/android'); }
    for (var i = 150; i < 400; i++) {
      log.record(area: 'gps', code: 'event_$i', platform: 'android',
        severity: VisionErrorSeverity.warning);
    }
    expect(log.length, 150); expect(log.encodedBytes, lessThanOrEqualTo(48 * 1024));
    expect(log.entries.where((e) => e.severity == VisionErrorSeverity.critical), hasLength(10));
    expect(log.entries.where((e) => e.resolved), isEmpty);
    final restored = bounded(() => start)..restore(log.encode());
    expect(restored.length, log.length); expect(restored.encodedBytes, log.encodedBytes);
  });

  test('tight injected byte cap exercises eviction with maximal identifiers', () {
    // Production 150 maximal rows fit under 48 KiB; a tighter injected cap
    // deliberately exercises the independent byte-eviction branch.
    final log = VisionErrorLog(clock: () => start, maxEntries: 150, maxBytes: 4096);
    final area = 'a' * 48, platform = 'p' * 48;
    for (var i = 0; i < 300; i++) {
      log.record(area: area, code: 'code_${i}_' + 'x' * (42 - i.toString().length),
        platform: platform, severity: i == 0 ? VisionErrorSeverity.critical : VisionErrorSeverity.warning);
      expect(log.length, lessThanOrEqualTo(150));
      expect(log.encodedBytes, lessThanOrEqualTo(4096));
    }
    expect(log.entries.any((e) => e.severity == VisionErrorSeverity.critical), isTrue);
    expect(log.length, lessThan(150)); // Byte cap, not only entry cap, is exercised.
  });

  test('TTL boundary cold restore and NTP rollback follow existing policy', () {
    var time = start;
    final log = bounded(() => time)..record(area: 'system', code: 'clock', platform: 'web');
    final cache = log.encode();
    time = start.add(const Duration(days: 7));
    expect((bounded(() => time)..restore(cache)).length, 1);
    time = time.add(const Duration(microseconds: 1));
    expect((bounded(() => time)..restore(cache)).length, 0);
    time = start.subtract(const Duration(seconds: 30));
    final backward = bounded(() => time)..restore(cache);
    backward.record(area: 'system', code: 'clock', platform: 'web');
    expect(backward.entries.single.firstSeen, start);
    expect(backward.entries.single.lastSeen, start);
    expect(backward.entries.single.count, 2);
    time = start.subtract(const Duration(minutes: 2));
    expect((bounded(() => time)..restore(cache)).length, 0);
  });

  test('oversized raw identifiers and corrupt payload are rejected before import', () {
    final log = bounded(() => start);
    final oversized = 'PRIVATE token@example.test ' * 100000;
    log.record(area: oversized, code: oversized, platform: oversized);
    expect(log.entries.single.fingerprint, 'unknown/unknown/unknown');
    log.restore(oversized); log.restore('{"version":1,"items":[');
    expect(log.length, 1); expect(log.encode(), isNot(contains('PRIVATE')));
    expect(log.encodedBytes, lessThan(1024));
  });

  test('saturated occurrence counter stays bounded and resolve reopens once', () {
    final seed = bounded(() => start)..record(area: 'gps', code: 'counter', platform: 'android');
    final payload = jsonDecode(seed.encode()) as Map<String, dynamic>;
    ((payload['items'] as List).single as Map)['count'] = 0x7fffffff;
    final log = bounded(() => start)..restore(jsonEncode(payload));
    expect(log.resolve('gps/counter/android'), isTrue);
    log.record(area: 'gps', code: 'counter', platform: 'android');
    expect(log.entries.single.count, 0x7fffffff);
    expect(log.entries.single.resolved, isFalse);
    expect(log.encodedBytes, lessThan(1024));
  });
}
