import 'package:flutter/material.dart';

import 'vision_session_journal.dart';
import 'vision_session_lifecycle_coordinator.dart';

/// Optional bridge for an authenticated subtree, not an AuthGate replacement.
///
/// Mount this only inside the currently authenticated AuthGate page and pass
/// AuthGate's authoritative `sessionIsCurrent` callback (UID + generation).
/// The callback must be bound to one actual session epoch; a UID-only check
/// or `() => true` must never be used outside synthetic tests.
///
/// This wrapper never opens the global device-wide diagnostic journal, adds
/// routes, accesses Firebase or captures user information. Its [builder] gets
/// null when ownership is unproven. Calling [clear] on the authoritative
/// session transition and disposing the prior Navigator root remains mandatory.
class VisionAuthenticatedSessionScope extends StatefulWidget {
  const VisionAuthenticatedSessionScope({
    super.key,
    required this.sessionIsCurrent,
    required this.builder,
  });

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

  void _updateFromAuth() {
    // Fail closed before considering a replacement. The old AuthGate closure
    // becomes invalid when either its UID or generation changes.
    final oldLease = _lease;
    final oldCurrent = oldLease?.isCurrent == true;
    final nextCurrent = _authoritativeCurrent(widget.sessionIsCurrent);
    if (!nextCurrent) {
      _coordinator.clear();
      _lease = null;
      return;
    }
    if (!oldCurrent) {
      _lease = _coordinator.replaceSession(
        isSessionCurrent: widget.sessionIsCurrent,
      );
    }
    // A harmless rebuild in the same authenticated epoch must not discard
    // local events. We retain the old lease only while its OWN predicate
    // remains true; a new UID/generation forces replacement.
  }

  @override
  void initState() {
    super.initState();
    _updateFromAuth();
  }

  @override
  void didUpdateWidget(covariant VisionAuthenticatedSessionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateFromAuth();
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
    if (!_authoritativeCurrent(widget.sessionIsCurrent)) {
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
