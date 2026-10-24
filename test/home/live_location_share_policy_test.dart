import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/home/live_location_share_policy.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);

  LiveLocationSharePolicy policy({
    String mode = 'economic',
    bool inWork = false,
    bool boost = false,
    int interval = 10,
    DateTime? lastSharedAt,
  }) =>
      liveLocationSharePolicy(
        personalMode: mode,
        inWork: inWork,
        nativeLocationProximityBoost: boost,
        preferredIntervalMinutes: interval,
        now: now,
        lastSharedAt: lastSharedAt,
      );

  group('effective mode and offline eligibility', () {
    test('operational work temporarily promotes offline to economic', () {
      final result = policy(mode: 'offline', inWork: true);
      expect(result.effectiveMode, 'economic');
      expect(result.clearWhenOutsideWork, isFalse);
    });

    test('offline outside work requests the existing one-time clear', () {
      final result = policy(mode: 'offline');
      expect(result.effectiveMode, 'offline');
      expect(result.clearWhenOutsideWork, isTrue);
    });

    test('live and economic preferences are preserved', () {
      expect(policy(mode: 'live', inWork: true).effectiveMode, 'live');
      expect(policy(mode: 'economic', inWork: false).effectiveMode, 'economic');
    });
  });

  group('minimum interval', () {
    test('work proximity boost uses twenty seconds even for live mode', () {
      expect(
        policy(mode: 'live', inWork: true, boost: true).minimumInterval,
        const Duration(seconds: 20),
      );
    });

    test('live mode uses one minute without proximity boost', () {
      expect(
        policy(mode: 'live', inWork: true).minimumInterval,
        const Duration(minutes: 1),
      );
      expect(
        policy(mode: 'live').minimumInterval,
        const Duration(minutes: 1),
      );
    });

    test('work intervals clamp to one through three minutes', () {
      for (final entry in <int, int>{-4: 1, 0: 1, 1: 1, 3: 3, 4: 3, 60: 3}.entries) {
        expect(
          policy(interval: entry.key, inWork: true).minimumInterval,
          Duration(minutes: entry.value),
          reason: 'work interval clamp',
        );
      }
    });

    test('outside-work intervals clamp to one through sixty minutes', () {
      for (final entry in <int, int>{-4: 1, 0: 1, 1: 1, 10: 10, 60: 60, 90: 60}.entries) {
        expect(
          policy(interval: entry.key).minimumInterval,
          Duration(minutes: entry.value),
          reason: 'outside-work interval clamp',
        );
      }
    });
  });

  group('accuracy and movement thresholds', () {
    test('high accuracy is retained for live mode or operational work', () {
      expect(policy(mode: 'live').useHighAccuracy, isTrue);
      expect(policy(inWork: true).useHighAccuracy, isTrue);
      expect(policy(mode: 'economic').useHighAccuracy, isFalse);
    });

    test('movement thresholds remain ten, twenty-five, and one hundred fifty meters', () {
      expect(policy(mode: 'live').movementThresholdMeters, 10);
      expect(policy(inWork: true).movementThresholdMeters, 25);
      expect(policy(mode: 'economic').movementThresholdMeters, 150);
    });
  });

  group('heartbeat boundary', () {
    test('first share and every operational check require a heartbeat', () {
      expect(policy().heartbeatDue, isTrue);
      expect(
        policy(
          inWork: true,
          lastSharedAt: now.subtract(const Duration(days: 1)),
        ).heartbeatDue,
        isTrue,
      );
    });

    test('live heartbeat becomes due exactly at five minutes', () {
      expect(
        policy(
          mode: 'live',
          lastSharedAt: now.subtract(const Duration(minutes: 4, seconds: 59)),
        ).heartbeatDue,
        isFalse,
      );
      expect(
        policy(
          mode: 'live',
          lastSharedAt: now.subtract(const Duration(minutes: 5)),
        ).heartbeatDue,
        isTrue,
      );
    });

    test('economic mode has no timed heartbeat outside work', () {
      expect(
        policy(
          mode: 'economic',
          lastSharedAt: now.subtract(const Duration(days: 1)),
        ).heartbeatDue,
        isFalse,
      );
    });
  });
}
