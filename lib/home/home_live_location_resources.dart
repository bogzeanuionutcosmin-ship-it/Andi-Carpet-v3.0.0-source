part of '../main.dart';

/// Owns Home's periodic web poll and native location stream subscription.
class HomeLiveLocationResources {
  Timer? _periodicTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _disposed = false;

  void startPeriodicPolling({
    required Duration interval,
    required void Function() onTick,
  }) {
    if (_disposed) return;
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => onTick());
  }

  Future<void> clearPositionSubscription() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  Future<void> replacePositionSubscription(
    StreamSubscription<Position> subscription,
  ) async {
    if (_disposed) {
      await subscription.cancel();
      return;
    }
    final previous = _positionSubscription;
    _positionSubscription = subscription;
    await previous?.cancel();
  }

  Future<void> stop() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    await clearPositionSubscription();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }
}
