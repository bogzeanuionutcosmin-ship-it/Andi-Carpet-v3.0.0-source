import 'package:flutter/material.dart';

import 'vision_session_journal.dart';
import 'vision_session_lifecycle_coordinator.dart';

/// Optional bridge for an authenticated subtree, not an AuthGate replacement.
///
/// Mount this only inside the currently authenticated AuthGate page and pass
/// AuthGate's authoritative `sessionIsCurrent` callback (UID + generation).
/// The callback must be bound to one actual session epoch; a UID-only check
/// or `() => true` must never be used outside synthetic tests. The
/// [sessionEpochKey] must be unique for every genuine login generation; using
/// a stable UID or a static token would violate cross-session isolation.
///
/// This wrapper never opens the global device-wide diagnostic journal, adds
/// routes, accesses Firebase or captures user information. Its [builder] gets
/// null when ownership is unproven. Calling [clear] on the authoritative
/// session transition and disposing the prior Navigator root remains mandatory.
class VisionAuthenticatedSessionScope extends StatefulWidget {
  const VisionAuthenticatedSessionScope({
    super.key,
    required this.sessionEpochKey,
    required this.sessionIsCurrent,
    required this.builder,
  });

  /// A unique object for one real AuthGate session generation, NOT the UID.
  /// Reusing a key for a new login is forbidden: revocation is monotonic.
  final Object sessionEpochKey;
  final bool Function() sessionIsCurrent;
  final Widget Function(BuildContext, VisionSessionJournalLease?) builder;

  @override
  State<VisionAuthenticatedSessionScope> createState() =>
      _VisionAuthenticatedSessionScopeState();
}

class _VisionAuthenticatedSessionScopeState
    extends State<VisionAuthenticatedSessionScope> {
  final VisionSessionLifecycleCoordinator _coordinator =
      VisionSessionLifecycleCoordinator();

  VisionSessionJournalLease? _lease;

  bool _authoritativeCurrent(bool Function() check) {
    try {
      return check();
    } catch (_) {
      return false;
    }
  }

  void _beginNewEpoch() {
    // A distinct token is the only way to re-open a revoked view.
    _lease = null;
    _coordinator.clear();
    if (_authoritativeCurrent(widget.sessionIsCurrent)) {
      _lease = _coordinator.replaceSession(
        isSessionCurrent: widget.sessionIsCurrent,
      );
    }
  }

  void _checkExistingEpoch() {
    // Fail-closed is monotonic for this epoch. A false->true callback cannot
    // resurrect a journal after logout; a new sessionEpochKey is required.
    if (!_authoritativeCurrent(widget.sessionIsCurrent) ||
        _lease?.isCurrent != true) {
      _coordinator.clear();
      _lease = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _beginNewEpoch();
  }

  @override
  void didUpdateWidget(covariant VisionAuthenticatedSessionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sessionEpochKey, widget.sessionEpochKey)) {
      _beginNewEpoch();
    } else {
      _checkExistingEpoch();
    }
  }

  @override
  void dispose() {
    _lease = null;
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A revoked epoch is never passed to children. This extra check handles
    // an external AuthGate transition even before didUpdateWidget executes.
    if (!_authoritativeCurrent(widget.sessionIsCurrent) ||
        _lease?.isCurrent != true) {
      _coordinator.clear();
      _lease = null;
      return widget.builder(context, null);
    }
    final current = _coordinator.activeLease;
    if (current == null || !identical(current, _lease)) {
      _lease = null;
      return widget.builder(context, null);
    }
    return widget.builder(context, current);
  }
}
