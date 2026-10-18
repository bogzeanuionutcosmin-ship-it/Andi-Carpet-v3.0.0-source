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
class _FinanceVisionFlight {
  final String digest;
  final bool reconciliation;
  final Future<FinanceCoordinatedResult> future;
  const _FinanceVisionFlight(this.digest, this.reconciliation, this.future);
}

class FinanceVisionObservedCoordinator {
  FinanceVisionObservedCoordinator({
    required this.coordinator,
    required this.sink,
    required this.platform,
  });

  final FinanceIntentCoordinator coordinator;
  final VisionScopedSignalSink sink;
  final VisionSignalPlatform platform;

  // Single-flight ONLY inside this opt-in wrapper instance. This protects
  // repeated taps/reentrant UI callbacks, not a second tab/process/device.
  // The server still needs its own atomic operation marker and revision.
  final Map<String, _FinanceVisionFlight> _flights = {};

  // The checked journal serializes preparations within an isolate, but does
  // not stop two distinct wrappers from overlapping BEFORE either prepare.
  // This ephemeral guard covers ONLY this Dart isolate, across wrapper
  // instances. A new login never receives the other epoch's Future/result.
  // No storage, polling, Firebase calls or durable payloads are added.
  static final Map<(String, String), Object> _isolateTargetOwners = {};

  // Session authority is owned by the existing Finance coordinator and
  // journal, not by diagnostics. One observed invalidation is irreversible,
  // including A1 -> B -> A2 returning to the same UID.
  bool _open = true;

  void dispose() {
    _open = false;
    // Do not touch the durable journal or pretend an in-flight server write
    // was cancelled; its own AuthGate session predicates control authority.
  }

  bool _ownsSession() {
    if (!_open) return false;
    try {
      if (coordinator.repository.sessionIsCurrent() &&
          coordinator.journal.sessionIsCurrent()) {
        return true;
      }
    } catch (_) {
      // A throwing AuthGate callback is a denial, never an authorization.
    }
    _open = false;
    return false;
  }

  static const FinanceCoordinatedResult _expired =
      FinanceCoordinatedResult(
    FinanceIntentResult(
      FinanceIntentStatus.uncertain, 'finance_session_expired',
    ),
    journalPending: true,
  );

  // An unexpected coordinator exception has UNKNOWN commit status. It is
  // categorically not a confirmed pre-write rejection or a retry instruction.
  // Never forward raw exception text, operation IDs or amounts to Vision.
  static const FinanceCoordinatedResult _unclassified =
      FinanceCoordinatedResult(
    FinanceIntentResult(
      FinanceIntentStatus.uncertain, 'finance_unclassified_result',
    ),
    journalPending: true,
  );

  Future<FinanceCoordinatedResult> _explicit(
    FinanceIntent intent, {
    required bool reconciliation,
  }) {
    // Refuse stale wrappers BEFORE sharing any old in-flight Future, even when
    // A2 signs in later with the same UID as A1.
    if (!_ownsSession()) {
      return Future<FinanceCoordinatedResult>.value(_expired);
    }
    final path = intent.targetPath;
    final active = _flights[path];
    if (active != null) {
      // Identical overlapping taps await the SAME completed result and create
      // exactly one diagnostic observation, not another server transaction.
      if (active.digest == intent.digest &&
          active.reconciliation == reconciliation) {
        return active.future;
      }
      return Future<FinanceCoordinatedResult>.value(
        const FinanceCoordinatedResult(
          FinanceIntentResult(
            FinanceIntentStatus.uncertain,
            'finance_operation_still_in_flight',
          ),
          journalPending: true,
          blockedByPendingIntent: true,
        ),
      );
    }
    final ownerKey = (coordinator.repository.ownerUid, path);
    if (_isolateTargetOwners.containsKey(ownerKey)) {
      // Never share a financial Future across different wrapper instances:
      // the other callback may belong to A1 while this belongs to A2.
      return Future<FinanceCoordinatedResult>.value(
        const FinanceCoordinatedResult(
          FinanceIntentResult(
            FinanceIntentStatus.uncertain,
            'finance_operation_in_another_scope',
          ),
          journalPending: true,
          blockedByPendingIntent: true,
        ),
      );
    }
    final lease = Object();
    _isolateTargetOwners[ownerKey] = lease;
    final future = reconciliation
        ? _reconcileOnce(intent)
        : _executeOnce(intent);
    _flights[path] = _FinanceVisionFlight(
      intent.digest, reconciliation, future,
    );
    void clear() {
      if (identical(_flights[path]?.future, future)) {
        _flights.remove(path);
      }
      if (identical(_isolateTargetOwners[ownerKey], lease)) {
        _isolateTargetOwners.remove(ownerKey);
      }
    }
    // Register both completion paths. A chained whenComplete() with no error
    // consumer could emit an unhandled asynchronous exception.
    future.then((_) => clear(), onError: (Object _, StackTrace __) => clear());
    return future;
  }

  /// Explicit user action; the underlying coordinator persists-before-send.
  ///
  /// An intent already present in the durable journal must be reconciled, not
  /// re-executed by a reopened button. In particular a lost server ACK is NOT
  /// proof that the prior transaction failed. This gate is per invocation and
  /// does not claim cross-process/tab compare-and-swap on secure storage.
  Future<FinanceCoordinatedResult> executeExplicitly(
    FinanceIntent intent,
  ) => _explicit(intent, reconciliation: false);

  Future<FinanceCoordinatedResult> _executeOnce(
    FinanceIntent intent,
  ) async {
    late final List<FinanceIntent> pending;
    try {
      pending = await coordinator.journal.pending();
    } catch (_) {
      const result = FinanceCoordinatedResult(
        FinanceIntentResult(
          FinanceIntentStatus.uncertain,
          'finance_pending_journal_unavailable',
        ),
        journalPending: true,
      );
      _observe(result);
      return result;
    }
    for (final existing in pending) {
      if (existing.operationId == intent.operationId) {
        final identicalRequest = existing.digest == intent.digest;
        final result = FinanceCoordinatedResult(
          FinanceIntentResult(
            identicalRequest
                ? FinanceIntentStatus.uncertain
                : FinanceIntentStatus.rejectedBeforeWrite,
            identicalRequest
                ? 'finance_existing_intent_requires_reconciliation'
                : 'finance_intent_identity_reuse',
          ),
          journalPending: true,
          blockedByPendingIntent: !identicalRequest,
        );
        _observe(result);
        return result;
      }
      if (existing.targetPath == intent.targetPath) {
        const result = FinanceCoordinatedResult(
          FinanceIntentResult(
            FinanceIntentStatus.rejectedBeforeWrite,
            'finance_unresolved_target',
          ),
          journalPending: true,
          blockedByPendingIntent: true,
        );
        _observe(result);
        return result;
      }
    }
    if (!_ownsSession()) return _expired;
    late final FinanceCoordinatedResult result;
    try {
      result = await coordinator.executeExplicitly(intent);
    } catch (_) {
      // The durable journal MAY contain a submitted intent. Fail closed and
      // require explicit recovery, without claiming that the write failed.
      if (!_ownsSession()) return _expired;
      _observe(_unclassified);
      return _unclassified;
    }
    if (!_ownsSession()) return result;
    _observe(result);
    return result;
  }

  /// Explicit reconciliation only. Never schedule from login/startup/rebuild.
  Future<FinanceCoordinatedResult> reconcileExplicitly(
    FinanceIntent intent,
  ) => _explicit(intent, reconciliation: true);

  Future<FinanceCoordinatedResult> _reconcileOnce(
    FinanceIntent intent,
  ) async {
    if (!_ownsSession()) return _expired;
    late final FinanceCoordinatedResult result;
    try {
      result = await coordinator.reconcileExplicitly(intent);
    } catch (_) {
      if (!_ownsSession()) return _expired;
      _observe(_unclassified);
      return _unclassified;
    }
    if (!_ownsSession()) return result;
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
