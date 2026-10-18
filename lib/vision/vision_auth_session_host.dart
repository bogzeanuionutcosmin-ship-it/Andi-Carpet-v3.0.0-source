import 'package:flutter/material.dart';

import 'vision_session_journal.dart';
import 'vision_session_lifecycle_coordinator.dart';

/// Optional widget boundary for AuthGate's existing UID+generation callback.
///
/// The parent MUST supply AuthGate's authoritative `sessionIsCurrent` and
/// key this host by its authenticated identity. The host does not authenticate
/// anyone, create routes, access the global device log or touch Firebase.
///
/// Its coordinator is intentionally owned by the mounted widget. A removed
/// account's tree immediately disposes and clears its Vision lease. If a new
/// AuthGate generation reuses this widget, a stale callback invalidates the
/// old lease and a fresh lease is created only for the current generation.
///
/// Not yet mounted in the production Home or application's navigation.
class VisionAuthSessionHost extends StatefulWidget {
  const VisionAuthSessionHost({
    super.key,
    required this.sessionIsCurrent,
    required this.builder,
    this.inactiveBuilder,
  });

  final bool Function() sessionIsCurrent;
  final Widget Function(
    BuildContext context,
    VisionSessionJournalLease activeLease,
  ) builder;
  final WidgetBuilder? inactiveBuilder;

  @override
  State<VisionAuthSessionHost> createState() => _VisionAuthSessionHostState();
}

class _VisionAuthSessionHostState extends State<VisionAuthSessionHost> {
  final VisionSessionLifecycleCoordinator _coordinator =
      VisionSessionLifecycleCoordinator();

  bool _validOwner() {
    try {
      return widget.sessionIsCurrent();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The *old* lease retains its own generation-bound predicate. Updating
    // a profile snapshot without changing AuthGate generation preserves the
    // existing lease and its summaries rather than resetting on every build.
    var lease = _coordinator.activeLease;
    if (!_validOwner()) {
      _coordinator.clear();
      return widget.inactiveBuilder?.call(context) ?? const SizedBox.shrink();
    }
    lease ??= _coordinator.replaceSession(
      isSessionCurrent: widget.sessionIsCurrent,
    );
    if (!lease.isCurrent) {
      _coordinator.clear();
      return widget.inactiveBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return widget.builder(context, lease);
  }
}
