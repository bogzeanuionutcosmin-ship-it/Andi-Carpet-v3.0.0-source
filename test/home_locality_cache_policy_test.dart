import 'package:flutter_test/flutter_test.dart';

import '../lib/home/live_locality_cache_policy.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);

  test('reuses cached locality strictly inside movement and age limits', () {
    expect(
      shouldReuseLiveLocalityCache(
        label: 'Craiova',
        resolvedAt: now.subtract(const Duration(minutes: 29, seconds: 59)),
        distanceMovedMeters: 4999.9,
        now: now,
      ),
      isTrue,
    );
  });

  test('expires at exactly five kilometres or thirty minutes', () {
    expect(
      shouldReuseLiveLocalityCache(
        label: 'Craiova',
        resolvedAt: now,
        distanceMovedMeters: 5000,
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldReuseLiveLocalityCache(
        label: 'Craiova',
        resolvedAt: now.subtract(const Duration(minutes: 30)),
        distanceMovedMeters: 0,
        now: now,
      ),
      isFalse,
    );
  });

  test('requires a label, timestamp, and prior position distance', () {
    expect(
      shouldReuseLiveLocalityCache(
        label: '',
        resolvedAt: now,
        distanceMovedMeters: 0,
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldReuseLiveLocalityCache(
        label: 'Craiova',
        resolvedAt: null,
        distanceMovedMeters: 0,
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldReuseLiveLocalityCache(
        label: 'Craiova',
        resolvedAt: now,
        distanceMovedMeters: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('preserves reuse when the system clock moves backwards', () {
    expect(
      shouldReuseLiveLocalityCache(
        label: 'Craiova',
        resolvedAt: now.add(const Duration(minutes: 2)),
        distanceMovedMeters: 0,
        now: now,
      ),
      isTrue,
    );
  });
}
