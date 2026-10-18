import 'dart:async';

import 'package:flutter/widgets.dart';

/// Flushes an already-pending device-local diagnostic snapshot when the app
/// enters the background. No storage, network, Firebase or timers live here:
/// the owner supplies the pending predicate and the flush operation.
///
/// Lifecycle callbacks are best effort; process termination may happen before
/// an asynchronous platform write completes.
class VisionTelemetryLifecycleObserver extends WidgetsBindingObserver {
  VisionTelemetryLifecycleObserver({
    required bool Function() hasPending,
    required Future<void> Function() flush,
  }) : _hasPending = hasPending,
       _flush = flush;

  final bool Function() _hasPending;
  final Future<void> Function() _flush;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive can be a transient overlay. Flushing is needed only when
    // entering background/hidden or when the framework is detached.
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached) {
      return;
    }
    try {
      if (!_hasPending()) return;
      // Diagnostics cannot make the host app fail when storage does.
      unawaited(_flush().catchError((Object _) {}));
    } catch (_) {
      // Also tolerate a bad synchronous callback from a test or adapter.
    }
  }
}
