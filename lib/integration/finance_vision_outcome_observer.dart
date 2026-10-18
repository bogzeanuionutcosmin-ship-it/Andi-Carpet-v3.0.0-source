import '../finance/intents/finance_intent.dart';
import '../vision/vision_scoped_signal_sink.dart';

/// Opt-in, one-way, status-only observation of the finance protocol.
///
/// Do not pass FinanceIntent, operationId, money, customer name, UID or server
/// error text into Vision. An uncertain result MAY HAVE COMMITTED; the observer
/// can never infer success/failure, retry, reconcile or mutate financial state.
/// This adapter is not mounted in Home and is not a release integration.
class FinanceVisionOutcomeObserver {
  const FinanceVisionOutcomeObserver._();

  /// Compatibility for existing tests and coordinator results. Does not read
  /// the result's code, intent, UID, amount or revision.
  static bool observe({
    required FinanceIntentResult result,
    required VisionScopedSignalSink sink,
    required VisionSignalPlatform platform,
  }) => observeStatus(status: result.status, sink: sink, platform: platform);

  /// Preferred entrypoint for demo UI: no financial payload can cross this
  /// boundary by type. Even a successful server result produces no telemetry.
  static bool observeStatus({
    required FinanceIntentStatus status,
    required VisionScopedSignalSink sink,
    required VisionSignalPlatform platform,
  }) {
    switch (status) {
      case FinanceIntentStatus.uncertain:
        return sink.emit(
          VisionDiagnosticSignal.financeOperationUncertain,
          platform: platform,
        );
      case FinanceIntentStatus.conflict:
        return sink.emit(
          VisionDiagnosticSignal.financeRevisionConflict,
          platform: platform,
        );
      case FinanceIntentStatus.confirmed:
        // Normal results are not errors and carry no useful diagnostic.
        return false;
      case FinanceIntentStatus.rejectedBeforeWrite:
        // A definite local refusal does not imply an ACL failure; the status
        // alone must never fabricate an authorization incident.
        return false;
    }
  }
}
