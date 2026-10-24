part of '../main.dart';

/// Owns subscriptions started by Home and cancels late registrations after
/// the owning State has been disposed.
class HomeSubscriptionRegistry {
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _disposed = false;

  void add(StreamSubscription<dynamic> subscription) {
    if (_disposed) {
      unawaited(subscription.cancel());
      return;
    }
    _subscriptions.add(subscription);
  }

  Future<void> cancelAll() async {
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  }

  Future<void> dispose() {
    _disposed = true;
    return cancelAll();
  }
}
