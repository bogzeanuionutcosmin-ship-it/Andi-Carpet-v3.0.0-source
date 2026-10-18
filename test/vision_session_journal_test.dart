import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';

void main() {
  test('A to B to A2 always drops prior account AND prior epoch events', () {
    var uid = 'A';
    var epoch = 1;
    final journal = VisionSessionJournal();
    final a1 = journal.startSession(
      isSessionCurrent: () => uid == 'A' && epoch == 1,
    );
    expect(a1.record(area: 'ocr', code: 'a1_event', platform: 'android'), isTrue);
    expect(a1.entries.single.code, 'a1_event');

    uid = 'B';
    epoch = 2;
    final b = journal.startSession(
      isSessionCurrent: () => uid == 'B' && epoch == 2,
    );
    expect(a1.record(area: 'ocr', code: 'late_a1', platform: 'android'), isFalse);
    expect(a1.entries, isEmpty);
    expect(b.entries, isEmpty);
    expect(b.record(area: 'gps', code: 'b_event', platform: 'android'), isTrue);
    expect(b.entries.single.code, 'b_event');

    uid = 'A';
    epoch = 3;
    final a2 = journal.startSession(
      isSessionCurrent: () => uid == 'A' && epoch == 3,
    );
    expect(a1.isCurrent, isFalse);
    expect(b.isCurrent, isFalse);
    expect(a2.entries, isEmpty);
    expect(a2.record(area: 'fcm', code: 'a2_event', platform: 'android'), isTrue);
    expect(a2.entries.single.code, 'a2_event');
    expect(a1.buildReport(), isNull);
    expect(b.buildReport(), isNull);
  });

  test('reusing same UID with a new generation cannot reopen A1', () {
    var epoch = 1;
    final journal = VisionSessionJournal();
    final old = journal.startSession(isSessionCurrent: () => epoch == 1);
    expect(old.record(area: 'gps', code: 'old', platform: 'web'), isTrue);
    epoch = 2;
    final newer = journal.startSession(isSessionCurrent: () => epoch == 2);
    expect(old.isCurrent, isFalse);
    expect(old.entries, isEmpty);
    expect(newer.entries, isEmpty);
    expect(newer.record(area: 'gps', code: 'new', platform: 'web'), isTrue);
    expect(newer.entries.single.code, 'new');
  });

  test('external revocation erases memory even before new login', () {
    var authorized = true;
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => authorized);
    expect(lease.record(area: 'ocr', code: 'failed', platform: 'android'), isTrue);
    authorized = false;
    expect(lease.entries, isEmpty); // Ownership check disposes the log.
    authorized = true; // Old closure must not resurrect events.
    expect(lease.isCurrent, isFalse);
    expect(lease.record(area: 'ocr', code: 'late', platform: 'android'), isFalse);
    expect(lease.buildReport(), isNull);
  });

  test('throwing owner callback denies, clears and never interrupts crash handling', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(
      isSessionCurrent: () => throw StateError('revoked'),
    );
    expect(lease.record(area: 'gps', code: 'private', platform: 'android'), isFalse);
    expect(lease.entries, isEmpty);
    expect(lease.buildReport(), isNull);
  });

  test('late stale lease cannot revoke a newer owner', () {
    final journal = VisionSessionJournal();
    final stale = journal.startSession(isSessionCurrent: () => false);
    final current = journal.startSession(isSessionCurrent: () => true);
    expect(current.record(area: 'gps', code: 'good', platform: 'android'), isTrue);
    expect(stale.isCurrent, isFalse);
    expect(current.entries.single.code, 'good');
  });

  test('journal remains bounded, sanitized, and in memory only', () {
    final journal = VisionSessionJournal(maxEntries: 2, maxBytes: 2048);
    final lease = journal.startSession(isSessionCurrent: () => true);
    expect(lease.record(
      area: 'coordinates 47.0,23.0',
      code: 'token=private',
      platform: 'android',
    ), isTrue);
    expect(lease.entries.single.area, 'unknown');
    expect(lease.entries.single.code, 'unknown');
    lease.record(area: 'ocr', code: 'save_failed', platform: 'android');
    lease.record(area: 'gps', code: 'no_signal', platform: 'android');
    expect(lease.entries, hasLength(2));
    expect(lease.entries.every((e) => e.area != 'coordinates 47.0,23.0'),
        isTrue);
    final report = lease.buildReport();
    expect(report, isNotNull);
    expect(report, isNot(contains('token=private')));
    expect(report, isNot(contains('47.0')));
  });

  test('event summaries are immutable copies and coalesce for one session', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    for (var i = 0; i < 10; i++) {
      expect(lease.record(area: 'ocr', code: 'save_failed', platform: 'android'),
          isTrue);
    }
    final snapshot = lease.entries;
    expect(snapshot.single.count, 10);
    expect(() => snapshot.clear(), throwsUnsupportedError);
    expect(lease.resolve(snapshot.single.fingerprint), isTrue);
    expect(lease.entries.single.resolved, isTrue);
    lease.record(area: 'ocr', code: 'save_failed', platform: 'android');
    expect(lease.entries.single.count, 11);
    expect(lease.entries.single.resolved, isFalse);
  });

  test('report requires ownership again after synchronous generation', () {
    var checks = 0;
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => ++checks == 1);
    final report = lease.buildReport();
    expect(report, isNull);
    expect(lease.isCurrent, isFalse);
    expect(lease.entries, isEmpty);
  });

  test('explicit logout discards journal and previously created leases', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    lease.record(area: 'fcm', code: 'token_failed', platform: 'web');
    journal.revoke();
    expect(lease.isCurrent, isFalse);
    expect(lease.entries, isEmpty);
    expect(lease.record(area: 'fcm', code: 'late', platform: 'web'), isFalse);
    final newLease = journal.startSession(isSessionCurrent: () => true);
    expect(newLease.entries, isEmpty);
  });
}
