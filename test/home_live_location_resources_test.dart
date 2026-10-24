import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  group('HomeLiveLocationResources', () {
    test('restart replaces the periodic timer instead of adding another', () async {
      final resources = app.HomeLiveLocationResources();
      var oldTicks = 0;
      var newTicks = 0;

      resources.startPeriodicPolling(
        interval: const Duration(milliseconds: 5),
        onTick: () => oldTicks++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(oldTicks, greaterThan(0));

      resources.startPeriodicPolling(
        interval: const Duration(milliseconds: 5),
        onTick: () => newTicks++,
      );
      final oldTicksAtRestart = oldTicks;
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(oldTicks, oldTicksAtRestart);
      expect(newTicks, greaterThan(0));
      await resources.dispose();
    });

    test('stop cancels the timer and active position subscription', () async {
      final resources = app.HomeLiveLocationResources();
      final positions = StreamController<Position>.broadcast();
      var ticks = 0;
      await resources.replacePositionSubscription(positions.stream.listen((_) {}));
      resources.startPeriodicPolling(
        interval: const Duration(milliseconds: 5),
        onTick: () => ticks++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ticks, greaterThan(0));
      expect(positions.hasListener, isTrue);

      await resources.stop();
      final stoppedTicks = ticks;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(ticks, stoppedTicks);
      expect(positions.hasListener, isFalse);
      await resources.dispose();
      await positions.close();
    });

    test('replacing a position stream cancels the previous listener', () async {
      final resources = app.HomeLiveLocationResources();
      final first = StreamController<Position>.broadcast();
      final second = StreamController<Position>.broadcast();

      await resources.replacePositionSubscription(first.stream.listen((_) {}));
      expect(first.hasListener, isTrue);
      await resources.replacePositionSubscription(second.stream.listen((_) {}));

      expect(first.hasListener, isFalse);
      expect(second.hasListener, isTrue);
      await resources.dispose();
      expect(second.hasListener, isFalse);
      await first.close();
      await second.close();
    });

    test('dispose is idempotent and prevents later timer restarts', () async {
      final resources = app.HomeLiveLocationResources();
      var ticks = 0;
      resources.startPeriodicPolling(
        interval: const Duration(milliseconds: 5),
        onTick: () => ticks++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ticks, greaterThan(0));

      await resources.dispose();
      await resources.dispose();
      resources.startPeriodicPolling(
        interval: const Duration(milliseconds: 5),
        onTick: () => ticks++,
      );
      final disposedTicks = ticks;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(ticks, disposedTicks);
    });
  });
}
