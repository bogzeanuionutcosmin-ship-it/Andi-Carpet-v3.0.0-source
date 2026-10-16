import 'package:flutter/material.dart';

import 'vision_authenticated_session_scope.dart';
import 'vision_session_journal.dart';

/// Opt-in adapter for AuthGate's actual UID+generation session predicate.
///
/// AuthGate recreates its callback when a widget rebuilds, so callback object
/// identity is NOT a session epoch. Retain the first generation-bound callback:
/// it stays valid through harmless profile refreshes, and becomes permanently
/// false when AuthGate advances its generation. Only then can a new, valid
/// callback establish a fresh unique epoch token.
///
/// Mount below AuthGate's activeSessionPageBuilder, not over an unauthenticated
/// or globally shared route. This adapter never unlocks the device-wide log.
class VisionAuthGateEpochBridge extends StatefulWidget {
  const VisionAuthGateEpochBridge({
    super.key,
    required this.sessionIsCurrent,
    required this.builder,
  });

  final bool Function() sessionIsCurrent;
  final Widget Function(BuildContext, VisionSessionJournalLease?) builder;

  @override
  State<VisionAuthGateEpochBridge> createState() =>
      _VisionAuthGateEpochBridgeState();
}

class _VisionAuthGateEpochBridgeState
    extends State<VisionAuthGateEpochBridge> {
  late bool Function() _epochAuthority;
  Object _epochToken = Object();
  bool _revoked = false;

  bool _valid(bool Function() check) {
    try {
      return check();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _epochAuthority = widget.sessionIsCurrent;
    _revoked = !_valid(_epochAuthority);
  }

  @override
  void didUpdateWidget(covariant VisionAuthGateEpochBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final originalStillCurrent = _valid(_epochAuthority);
    final incomingCurrent = _valid(widget.sessionIsCurrent);
    if (!originalStillCurrent) _revoked = true;

    // A generation-bound AuthGate predicate never becomes current again
    // after a real generation transition. A harmless new closure alone is
    // insufficient to rotate the journal. A false->true return on the SAME
    // callback cannot resurrect a revoked epoch.
    if (_revoked &&
        !originalStillCurrent &&
        incomingCurrent &&
        !identical(widget.sessionIsCurrent, _epochAuthority)) {
      _epochAuthority = widget.sessionIsCurrent;
      _epochToken = Object();
      _revoked = false;
    }
  }

  bool _currentEpoch() {
    if (!_valid(_epochAuthority) || !_valid(widget.sessionIsCurrent)) {
      _revoked = true;
    }
    return !_revoked;
  }

  @override
  Widget build(BuildContext context) {
    return VisionAuthenticatedSessionScope(
      sessionEpochKey: _epochToken,
      sessionIsCurrent: _currentEpoch,
      builder: widget.builder,
    );
  }
}
