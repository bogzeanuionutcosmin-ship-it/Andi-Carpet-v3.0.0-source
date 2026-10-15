import 'package:flutter/material.dart';

import 'vision_diagnostics_page.dart';
import 'vision_session_journal.dart';

/// Read-only bridge between an externally verified session lease and the
/// existing fail-closed VisionDiagnosticsPage.
///
/// This widget does NOT grant identity or create a session. AuthGate (UID AND
/// generation) must supply the lease's authoritative ownership callback.
/// A different account or a stale route gets only the denied diagnostics UI.
/// No access to installation-wide VisionErrorTelemetry.log is requested.
class VisionScopedDiagnosticsPage extends StatefulWidget {
  const VisionScopedDiagnosticsPage({
    super.key,
    required this.lease,
  });

  final VisionSessionJournalLease lease;

  @override
  State<VisionScopedDiagnosticsPage> createState() =>
      _VisionScopedDiagnosticsPageState();
}

class _VisionScopedDiagnosticsPageState
    extends State<VisionScopedDiagnosticsPage> {
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _listenToCurrentLease();
  }

  void _listenToCurrentLease() {
    _unsubscribe = widget.lease.listenRevocation(_onLeaseRevoked);
  }

  @override
  void didUpdateWidget(covariant VisionScopedDiagnosticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lease, widget.lease)) {
      _unsubscribe?.call();
      _listenToCurrentLease();
    }
  }

  void _onLeaseRevoked() {
    if (!mounted) return;
    // An AuthGate transition can invalidate a route during parent build.
    // A post-frame rebuild is safe both within and outside the build phase.
    // Explicitly request a frame when there is no ongoing frame; there are
    // no timers, repeated callbacks or persistent background listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unsubscribe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.lease.snapshotForDisplay();
    return VisionDiagnosticsPage(
      log: snapshot,
      isSessionCurrent: () => widget.lease.isCurrent,
    );
  }
}
