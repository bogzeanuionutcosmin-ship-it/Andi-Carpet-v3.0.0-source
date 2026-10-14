import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vision_error_log.dart';
import 'vision_diagnostic_report.dart';
import 'vision_diagnostic_advisor.dart';
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
  @override
  Widget build(BuildContext context) {
    final currentLog = widget.log ?? VisionErrorTelemetry.log;
    final entries = currentLog.entries;
    final insights = VisionDiagnosticAdvisor.assess(currentLog, maxInsights: 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision · Error Log'),
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
            tooltip: 'Actualizează',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
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
                          title: Text(item.area + ' / ' + item.code),
                          subtitle: Text(
                            'Platformă: ' + item.platform +
                            ' · Ultima apariție: ' + dateLabel +
                            ' · ' + (item.resolved ? 'Rezolvată' : 'Deschisă'),
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
