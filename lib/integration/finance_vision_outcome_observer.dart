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

  static bool observe({
    required FinanceIntentResult result,
    required VisionScopedSignalSink sink,
    required VisionSignalPlatform platform,
  }) => observeStatus(
    status: result.status,
    sink: sink,
    platform: platform,
  );

  /// Minimal callback surface for a future Home/ExpensePage boundary.
  ///
  /// FinanceHomeCandidate (Mission X, separate PR #78) accepts callback
  /// signatures for the ORIGINAL ExpensePage dialogs, not this repository's
  /// Vision types. Once explicitly authorized, the owner can pass only the
  /// *enum* status to this observer without exposing coordinator results,
  /// operation IDs, amounts, raw server text or durable journal data.
  ///
  /// This method neither installs that integration nor observes Home today.
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
