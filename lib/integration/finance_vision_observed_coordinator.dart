import '../finance/intents/finance_coordinator.dart';
import '../finance/intents/finance_intent.dart';
import '../vision/vision_scoped_signal_sink.dart';
import 'finance_vision_outcome_observer.dart';

/// Optional composition boundary; NOT an automatic pending-intent runner.
///
/// The exact same financial result is returned unchanged to the caller. Only
/// its status is passed to a revocable, anonymous Vision session sink. No
/// operation IDs, amounts, names, errors or server snapshots go to Vision.
/// Never treat reporting failure as a financial failure or retry condition.
class FinanceVisionObservedCoordinator {
  const FinanceVisionObservedCoordinator({
    required this.coordinator,
    required this.sink,
    required this.platform,
  });

  final FinanceIntentCoordinator coordinator;
  final VisionScopedSignalSink sink;
  final VisionSignalPlatform platform;

  /// Explicit user action; the underlying coordinator persists-before-send.
  Future<FinanceCoordinatedResult> executeExplicitly(
    FinanceIntent intent,
  ) async {
    final result = await coordinator.executeExplicitly(intent);
    _observe(result);
    return result;
  }

  /// Explicit reconciliation only. Never schedule from login/startup/rebuild.
  Future<FinanceCoordinatedResult> reconcileExplicitly(
    FinanceIntent intent,
  ) async {
    final result = await coordinator.reconcileExplicitly(intent);
    _observe(result);
    return result;
  }

  void _observe(FinanceCoordinatedResult result) {
    // The sink performs its own authoritative UID+epoch check after await.
    // Diagnostics never influence the returned financial outcome.
    try {
      FinanceVisionOutcomeObserver.observe(
        result: result.result,
        sink: sink,
        platform: platform,
      );
    } catch (_) {
      // Never let a diagnostic observer turn a committed receipt into a retry.
    }
  }
}
