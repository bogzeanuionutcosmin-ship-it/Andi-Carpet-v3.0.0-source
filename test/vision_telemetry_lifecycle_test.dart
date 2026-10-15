import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_telemetry_lifecycle.dart';

void main() {
  test('paused, hidden and detached flush pending diagnostic snapshots',
      () async {
    var pending = true;
    var flushes = 0;
    final observer = VisionTelemetryLifecycleObserver(
      hasPending: () => pending,
      flush: () async {
        flushes++;
        pending = false; // Mirrors cancellation of the debounce timer.
      },
    );
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 1);

    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 1); // No redundant write once the timer is gone.

    pending = true;
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 2);

    pending = true;
    observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 3);
  });

  test('inactive/resumed or an empty queue never cause a flush', () async {
    var pending = false;
    var flushes = 0;
    final observer = VisionTelemetryLifecycleObserver(
      hasPending: () => pending,
      flush: () async { flushes++; },
    );
    for (final state in AppLifecycleState.values) {
      observer.didChangeAppLifecycleState(state);
    }
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 0);

    pending = true;
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(flushes, 0);
  });

  test('async and synchronous storage errors never escape lifecycle callback',
      () async {
    final asyncFailure = Completer<void>();
    final observer = VisionTelemetryLifecycleObserver(
      hasPending: () => true,
      flush: () => asyncFailure.future,
    );
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    asyncFailure.completeError(StateError('synthetic storage error'));
    await Future<void>.delayed(Duration.zero);

    final broken = VisionTelemetryLifecycleObserver(
      hasPending: () => true,
      flush: () => throw StateError('synthetic synchronous error'),
    );
    expect(
      () => broken.didChangeAppLifecycleState(AppLifecycleState.detached),
      returnsNormally,
    );
  });
}
