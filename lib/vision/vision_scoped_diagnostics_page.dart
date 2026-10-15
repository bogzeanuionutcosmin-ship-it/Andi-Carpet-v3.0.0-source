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
class VisionScopedDiagnosticsPage extends StatelessWidget {
  const VisionScopedDiagnosticsPage({
    super.key,
    required this.lease,
  });

  final VisionSessionJournalLease lease;

  @override
  Widget build(BuildContext context) {
    final snapshot = lease.snapshotForDisplay();
    return VisionDiagnosticsPage(
      log: snapshot,
      isSessionCurrent: () => lease.isCurrent,
    );
  }
}
