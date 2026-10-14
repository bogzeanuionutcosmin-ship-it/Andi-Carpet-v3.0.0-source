import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';

void main() {
  group('Vision Error Log (offline, no external services)', () {
    late DateTime now;

    setUp(() {
      now = DateTime.utc(2026, 10, 13, 6);
    });

    VisionErrorLog create({
      int maxEntries = 500,
      int maxBytes = 1024 * 1024,
      Duration retention = const Duration(days: 7),
    }) =>
        VisionErrorLog(
          maxEntries: maxEntries,
          maxBytes: maxBytes,
          retention: retention,
          clock: () => now,
        );

    test('repeated errors are collapsed into a single summary', () {
      final log = create();
      for (var i = 0; i < 10000; i++) {
        log.record(area: 'ocr', code: 'save_failed', platform: 'android');
      }
      expect(log.length, 1);
      expect(log.entries.single.count, 10000);
      expect(log.entries.single.area, 'ocr');
      expect(log.encodedBytes, lessThan(1024));
    });

    test('severity escalates, resolving works, next occurrence reopens', () {
      final log = create();
      log.record(area: 'gps', code: 'location_denied', platform: 'android');
      log.record(
        area: 'gps',
        code: 'location_denied',
        platform: 'android',
        severity: VisionErrorSeverity.critical,
      );
      final id = log.entries.single.fingerprint;
      expect(log.entries.single.severity, VisionErrorSeverity.critical);
      expect(log.resolve(id), isTrue);
      expect(log.resolve(id), isFalse);
      expect(log.entries.single.resolved, isTrue);
      log.record(area: 'gps', code: 'location_denied', platform: 'android');
      expect(log.entries.single.resolved, isFalse);
      expect(log.entries.single.count, 3);
      expect(log.entries.single.severity, VisionErrorSeverity.critical);
    });

    test('local entries are capped and resolved entries evicted first', () {
      final log = create(maxEntries: 2);
      log.record(area: 'gps', code: 'first', platform: 'android');
      now = now.add(const Duration(seconds: 1));
      log.record(area: 'ocr', code: 'second', platform: 'android');
      expect(log.resolve('ocr/second/android'), isTrue);
      now = now.add(const Duration(seconds: 1));
      log.record(area: 'sync', code: 'third', platform: 'android');
      expect(log.length, 2);
      expect(log.entries.map((e) => e.code), containsAll(<String>['first', 'third']));
      expect(log.entries.map((e) => e.code), isNot(contains('second')));
    });

    test('critical incidents survive storage pressure ahead of newer warnings', () {
      final log = create(maxEntries: 2);
      log.record(area: 'system', code: 'critical_first', platform: 'android',
        severity: VisionErrorSeverity.critical);
      now = now.add(const Duration(minutes: 1));
      log.record(area: 'system', code: 'warning_second', platform: 'android',
        severity: VisionErrorSeverity.warning);
      now = now.add(const Duration(minutes: 1));
      log.record(area: 'system', code: 'error_third', platform: 'android',
        severity: VisionErrorSeverity.error);
      expect(log.entries.map((e) => e.code),
        containsAll(<String>['critical_first', 'error_third']));
      expect(log.entries.map((e) => e.code),
        isNot(contains('warning_second')));
    });

    test('resolved critical incident is evicted before an open warning', () {
      final log = create(maxEntries: 1);
      log.record(area: 'system', code: 'critical_done', platform: 'android',
        severity: VisionErrorSeverity.critical);
      expect(log.resolve('system/critical_done/android'), isTrue);
      now = now.add(const Duration(minutes: 1));
      log.record(area: 'system', code: 'warning_open', platform: 'android',
        severity: VisionErrorSeverity.warning);
      expect(log.entries.single.code, 'warning_open');
    });

    test('critical incident still expires by TTL and does not bypass hard cap', () {
      final log = create(maxEntries: 1, retention: const Duration(days: 7));
      log.record(area: 'system', code: 'one', platform: 'android',
        severity: VisionErrorSeverity.critical);
      now = now.add(const Duration(minutes: 1));
      log.record(area: 'system', code: 'two', platform: 'android',
        severity: VisionErrorSeverity.critical);
      expect(log.entries.single.code, 'two');
      now = now.add(const Duration(days: 8));
      expect(log.length, 0);
    });

    test('byte limit is enforced independent of entry count', () {
      final log = create(maxEntries: 500, maxBytes: 450);
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(milliseconds: 1));
        log.record(area: 'system', code: 'issue_$i', platform: 'android');
      }
      expect(log.encodedBytes, lessThanOrEqualTo(450));
      expect(log.length, lessThan(10));
    });

    test('events expire after seven days, including resolved incidents', () {
      final log = create();
      log.record(
        area: 'flutter',
        code: 'uncaught',
        platform: 'web',
        severity: VisionErrorSeverity.critical,
      );
      expect(log.length, 1);
      now = now.add(const Duration(days: 8));
      expect(log.length, 0);
    });

    test('only fixed safe identifiers are stored (never raw messages)', () {
      final log = create();
      log.record(
        area: 'gps coordinates 45.12 26.34',
        code: 'token=secret-1234',
        platform: 'android',
      );
      expect(log.entries.single.area, 'unknown');
      expect(log.entries.single.code, 'unknown');
      expect(log.encode(), isNot(contains('secret-1234')));
      expect(log.encode(), isNot(contains('45.12')));
    });

    test('serialized summaries survive local restart', () {
      final before = create();
      before.record(area: 'ocr', code: 'save_failed', platform: 'android');
      before.record(area: 'ocr', code: 'save_failed', platform: 'android');
      final saved = before.encode();
      final after = create();
      after.restore(saved);
      expect(after.entries.single.count, 2);
      expect(after.entries.single.firstSeen, now);
      expect(after.entries.single.lastSeen, now);
    });

    test('old, future, corrupt or malicious cache never reaches output', () {
      final log = create();
      final invalidCache = jsonEncode({
        'version': 1,
        'items': [
          {
            'area': 'ocr',
            'code': 'safe',
            'platform': 'web',
            'severity': 'warning',
            'firstSeen': '2026-09-01T00:00:00.000Z',
            'lastSeen': '2026-09-01T00:00:00.000Z',
            'count': 1,
          },
          {
            'area': 'secret-password@example.com',
            'code': 'x',
            'platform': 'web',
            'severity': 'critical',
            'firstSeen': now.toIso8601String(),
            'lastSeen': now.toIso8601String(),
            'count': 1,
          },
          {
            'area': 'gps',
            'code': 'future',
            'platform': 'android',
            'severity': 'critical',
            'firstSeen': '2026-12-01T00:00:00.000Z',
            'lastSeen': '2026-12-01T00:00:00.000Z',
            'count': 1,
          },
          {
            'area': 'startup',
            'code': 'valid',
            'platform': 'android',
            'severity': 'error',
            'firstSeen': now.toIso8601String(),
            'lastSeen': now.toIso8601String(),
            'count': 3,
          },
        ],
      });
      log.restore('invalid');
      log.restore(invalidCache);
      expect(log.length, 1);
      expect(log.entries.single.code, 'valid');
      expect(log.encode(), isNot(contains('password')));
    });
  });
}
