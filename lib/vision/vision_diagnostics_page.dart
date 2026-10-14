import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vision_error_log.dart';
import 'vision_diagnostic_report.dart';
import 'vision_diagnostic_advisor.dart';
import 'vision_diagnostic_coverage.dart';
import 'vision_error_telemetry.dart';

/// Read-only diagnostics from THIS device only; no remote-user data queries.
class VisionDiagnosticsPage extends StatefulWidget {
  const VisionDiagnosticsPage({super.key, this.log});

  /// Optional pure log for offline unit/widget testing.
  final VisionErrorLog? log;

  @override
  State<VisionDiagnosticsPage> createState() => _VisionDiagnosticsPageState();
}

class _VisionDiagnosticsPageState extends State<VisionDiagnosticsPage> {
  static const bool _offlineTestBuild =
      bool.fromEnvironment('VISION_OFFLINE_SMOKE', defaultValue: false);
  static const String _smokeRun =
      String.fromEnvironment('VISION_SMOKE_RUN', defaultValue: 'local');

  @override
  Widget build(BuildContext context) {
    // The persistent telemetry key is shared by the entire installation,
    // not partitioned by authenticated UID. A newly signed-in user must not
    // be able to inspect the prior user's diagnostic history. Until an
    // authenticated session-scoped projection exists, deny access to the
    // device-wide journal in the real app. Injected logs are for isolated
    // tests/explicitly scoped integrations; the offline smoke app is separate
    // from login and Firebase.
    if (!_offlineTestBuild &&
        (widget.log == null || identical(widget.log, VisionErrorTelemetry.log))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vision')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Diagnosticul local nu este disponibil aici până când '
              'istoricul poate fi izolat sigur pentru sesiunea curentă. '
              'Nu au fost șterse date și nu a fost trimis niciun raport.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final currentLog = widget.log ?? VisionErrorTelemetry.log;
    final entries = currentLog.entries;
    final insights = VisionDiagnosticAdvisor.assess(currentLog, maxInsights: 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision'),
        actions: <Widget>[
          // Only debug builds can create a harmless local persistence probe.
          // Release builds remain read-only; this never writes to Firebase.
          if (kDebugMode && widget.log == null)
            IconButton(
              tooltip: 'Test local · salvare jurnal',
              icon: const Icon(Icons.science_outlined),
              onPressed: () async {
                VisionErrorTelemetry.report(
                  area: 'vision_test',
                  code: 'persistence_probe',
                  severity: VisionErrorSeverity.warning,
                );
                await VisionErrorTelemetry.flush();
                if (mounted) setState(() {});
              },
            ),
          IconButton(
            tooltip: 'Copiază raport tehnic anonimizat',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final report = VisionDiagnosticReport.build(
                widget.log ?? VisionErrorTelemetry.log,
              );
              try {
                await Clipboard.setData(ClipboardData(text: report));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(
                    'Raportul tehnic a fost copiat. Verifică-l înainte de distribuire.',
                  )),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(
                    'Nu s-a putut copia raportul pe acest dispozitiv.',
                  )),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Ce monitorizează Vision',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (sheetContext) => FractionallySizedBox(
                  heightFactor: 0.72,
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Acoperirea diagnosticului Vision',
                          style: Theme.of(sheetContext).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                          'Aceasta este o listă statică a modulelor instrumentate '
                          'în versiunea de probă. Nu este un test automat al '
                          'tuturor funcțiilor și nu certifică lipsa erorilor.',
                        ),
                        const SizedBox(height: 12),
                        for (final area in VisionDiagnosticCoverage.areas)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(area.name,
                                    style: Theme.of(sheetContext)
                                        .textTheme.titleSmall),
                                  const SizedBox(height: 4),
                                  Text(area.statusLabel),
                                  const SizedBox(height: 4),
                                  Text('Observă: ${area.observes}'),
                                  Text('Nu verifică: ${area.doesNotVerify}'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Actualizează',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_offlineTestBuild)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'VISION TEST OFFLINE · BUILD #$_smokeRun',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Diagnostic local al acestui dispozitiv. Nu trimitem '
              'erorile la Firebase sau către un AI online. '
              'Rezumatele vechi se curăță automat după 7 zile. '
              'Raportul se copiază doar la cerere; nu se trimite automat. '
              'Dacă nu există erori în listă, nu înseamnă că '
              'toate funcțiile au fost verificate.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.log == null
                    ? VisionErrorTelemetry.persistenceMessage
                    : 'Jurnal de probă: salvarea pe dispozitiv nu este testată.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (insights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vision observă: ${insights.first.title}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insights.first.occurrenceLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insights.first.explanation,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('Nu există erori locale în jurnal.'),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      final date = item.lastSeen.toLocal().toString();
                      final dateLabel = date.length > 16
                          ? date.substring(0, 16)
                          : date;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Icon(
                            item.severity == VisionErrorSeverity.critical
                                ? Icons.error_outline
                                : Icons.bug_report_outlined,
                          ),
                          title: Text(
                            item.area == 'vision_test' &&
                            item.code == 'persistence_probe'
                                ? 'Test de persistență · fără eroare'
                                : item.area + ' / ' + item.code,
                          ),
                          subtitle: Text(
                            'Platformă: ' + item.platform +
                            ' · Ultima apariție: ' + dateLabel +
                            ' · ' + (item.area == 'vision_test' &&
                            item.code == 'persistence_probe'
                                ? 'Probă locală'
                                : (item.resolved ? 'Rezolvată' : 'Deschisă')),
                          ),
                          trailing: Text('×' + item.count.toString()),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
