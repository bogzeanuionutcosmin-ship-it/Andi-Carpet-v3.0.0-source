import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vision_diagnostic_advisor.dart';
import 'vision_session_journal.dart';

/// Opt-in authenticated diagnostics view. Mount ONLY below the current
/// AuthGate UID+generation scope with its [VisionSessionJournalLease].
///
/// There is no device-wide persisted log, network API, Firestore access,
/// background timer, handler registration, finance execution or raw error text.
/// A null/revoked lease renders a closed view, never a remembered snapshot.
class VisionSessionDiagnosticsPanel extends StatefulWidget {
  const VisionSessionDiagnosticsPanel({
    super.key,
    required this.lease,
  });

  final VisionSessionJournalLease? lease;

  @override
  State<VisionSessionDiagnosticsPanel> createState() =>
      _VisionSessionDiagnosticsPanelState();
}

class _VisionSessionDiagnosticsPanelState
    extends State<VisionSessionDiagnosticsPanel> {
  void Function()? _unsubscribe;
  int _viewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final lease = widget.lease;
    if (lease == null || !lease.isCurrent) return;
    _unsubscribe = lease.listenRevocation(() {
      // The journal revokes before delivering this callback. No old-owner
      // snapshot is retained in this widget's state.
      _viewGeneration++;
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant VisionSessionDiagnosticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lease, widget.lease)) {
      _viewGeneration++;
      _unsubscribe?.call();
      _unsubscribe = null;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _viewGeneration++;
    _unsubscribe?.call();
    _unsubscribe = null;
    super.dispose();
  }

  bool _owns(VisionSessionJournalLease? lease, int generation) =>
      mounted &&
      generation == _viewGeneration &&
      identical(widget.lease, lease) &&
      lease?.isCurrent == true;

  Future<void> _copyReport() async {
    final lease = widget.lease;
    final generation = _viewGeneration;
    if (!_owns(lease, generation)) return;
    final report = lease!.buildReport();
    if (report == null || !_owns(lease, generation)) return;
    // Synchronous check directly before handing the sanitized snapshot to
    // the OS clipboard. An asynchronous clipboard implementation cannot
    // retract bytes after ownership is revoked mid-call; no success claim is
    // displayed on a different session.
    try {
      await Clipboard.setData(ClipboardData(text: report));
      if (!_owns(lease, generation)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Raportul local a fost copiat la cerere.'),
        ));
      }
    } catch (_) {
      if (!_owns(lease, generation)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nu s-a putut copia raportul local.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lease = widget.lease;
    if (lease?.isCurrent != true) {
      return const Center(
        key: ValueKey('vision-session-closed'),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Diagnosticul Vision este închis pentru această sesiune. '
            'Nu este afișat istoricul altui cont.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final log = lease!.snapshotForDisplay();
    if (log == null || !lease.isCurrent) {
      return const Center(
        key: ValueKey('vision-session-closed'),
        child: Text('Sesiunea de diagnostic nu mai este disponibilă.'),
      );
    }
    final insights = VisionDiagnosticAdvisor.assess(log);
    final entries = log.entries;
    return Column(
      key: const ValueKey('vision-session-open'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Vision observă numai coduri tehnice locale ale acestei '
            'sesiuni. Nu verifică automat toate funcțiile, nu salvează '
            'rapoarte în cloud și nu retrimite operațiuni financiare.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('vision-session-copy'),
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: _copyReport,
                  label: const Text('Copiază raportul anonim'),
                ),
              ),
              IconButton(
                key: const ValueKey('vision-session-refresh'),
                tooltip: 'Actualizează diagnostic',
                onPressed: () {
                  if (lease.isCurrent && mounted) setState(() {});
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text(
                  'Niciun incident local înregistrat. '
                  'Acest lucru nu certifică lipsa defectelor.',
                ))
              : ListView(
                  children: [
                    for (final insight in insights)
                      Card(
                        child: ListTile(
                          title: Text(insight.title),
                          subtitle: Text(insight.explanation),
                          trailing: Text(
                            insight.occurrences.toString(),
                            key: const ValueKey('vision-insight-count'),
                          ),
                        ),
                      ),
                    for (final entry in entries)
                      ListTile(
                        title: Text('${entry.area}/${entry.code}'),
                        subtitle: Text(
                          '${entry.platform} · ${entry.severity.name} · '
                          '${entry.resolved ? 'rezolvat' : 'deschis'}',
                        ),
                        trailing: Text('${entry.count}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
