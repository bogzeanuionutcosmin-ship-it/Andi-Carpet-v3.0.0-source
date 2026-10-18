import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_session_lifecycle_coordinator.dart';

void main() {
  test('A1 to B to A2, no cross-epoch events, including returning UID', () {
    var uid = 'A';
    var epoch = 1;
    final bridge = VisionSessionLifecycleCoordinator();
    final a1 = bridge.replaceSession(
      isSessionCurrent: () => uid == 'A' && epoch == 1,
    );
    expect(a1.record(area: 'ocr', code: 'a1', platform: 'android'), isTrue);
    uid = 'B';
    epoch = 2;
    final b = bridge.replaceSession(
      isSessionCurrent: () => uid == 'B' && epoch == 2,
    );
    expect(a1.isCurrent, isFalse);
    expect(a1.entries, isEmpty);
    expect(b.entries, isEmpty);
    expect(b.record(area: 'gps', code: 'b2', platform: 'android'), isTrue);
    uid = 'A';
    epoch = 3;
    final a2 = bridge.replaceSession(
      isSessionCurrent: () => uid == 'A' && epoch == 3,
    );
    expect(a1.isCurrent, isFalse);
    expect(b.isCurrent, isFalse);
    expect(a2.entries, isEmpty);
    expect(bridge.activeLease, same(a2));
  });

  test('same UID with a new AuthGate generation always revokes prior lease', () {
    var generation = 12;
    final bridge = VisionSessionLifecycleCoordinator();
    final a1 = bridge.replaceSession(
      isSessionCurrent: () => generation == 12,
    );
    a1.record(area: 'fcm', code: 'old_epoch', platform: 'android');
    generation = 13;
    final a2 = bridge.replaceSession(
      isSessionCurrent: () => generation == 13,
    );
    expect(a1.entries, isEmpty);
    expect(a2.entries, isEmpty);
  });

  test('explicit clear notifies viewers, discards journal, blocks late writes', () {
    final bridge = VisionSessionLifecycleCoordinator();
    final old = bridge.replaceSession(isSessionCurrent: () => true);
    var notifications = 0;
    old.listenRevocation(() => notifications++);
    old.record(area: 'gps', code: 'before_logout', platform: 'web');
    bridge.clear();
    expect(notifications, 1);
    expect(bridge.activeLease, isNull);
    expect(old.record(area: 'gps', code: 'after_logout', platform: 'web'), isFalse);
    expect(old.buildReport(), isNull);
    final newLease = bridge.replaceSession(isSessionCurrent: () => true);
    expect(newLease.entries, isEmpty);
  });

  test('an external epoch change is denied upon next access', () {
    var valid = true;
    final bridge = VisionSessionLifecycleCoordinator();
    final old = bridge.replaceSession(isSessionCurrent: () => valid);
    old.record(area: 'ocr', code: 'prior', platform: 'android');
    valid = false;
    expect(bridge.activeLease, isNull);
    expect(old.entries, isEmpty);
    expect(old.buildReport(), isNull);
  });

  test('ownership exception cannot expose a stale journal', () {
    final bridge = VisionSessionLifecycleCoordinator();
    final lease = bridge.replaceSession(
      isSessionCurrent: () => throw StateError('auth disposed'),
    );
    expect(bridge.activeLease, isNull);
    expect(lease.entries, isEmpty);
  });

  test('dispose is idempotent, revokes and blocks later replacement', () {
    final bridge = VisionSessionLifecycleCoordinator();
    final lease = bridge.replaceSession(isSessionCurrent: () => true);
    var revoked = 0;
    lease.listenRevocation(() => revoked++);
    bridge.dispose();
    bridge.dispose();
    expect(revoked, 1);
    expect(bridge.activeLease, isNull);
    expect(() => bridge.replaceSession(isSessionCurrent: () => true),
        throwsStateError);
  });

  test('bad notification subscriber does not prevent clear', () {
    final bridge = VisionSessionLifecycleCoordinator();
    final old = bridge.replaceSession(isSessionCurrent: () => true);
    old.listenRevocation(() => throw StateError('UI disappeared'));
    bridge.clear();
    expect(old.isCurrent, isFalse);
    expect(old.entries, isEmpty);
  });

  test('old lease cannot erase newer session after replacement', () {
    final bridge = VisionSessionLifecycleCoordinator();
    final a = bridge.replaceSession(isSessionCurrent: () => true);
    final b = bridge.replaceSession(isSessionCurrent: () => true);
    expect(a.resolve('not_existing'), isFalse);
    expect(b.record(area: 'gps', code: 'current', platform: 'android'), isTrue);
    expect(b.entries.single.code, 'current');
  });
}
