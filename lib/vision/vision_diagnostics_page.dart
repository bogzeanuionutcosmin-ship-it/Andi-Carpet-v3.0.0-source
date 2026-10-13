import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'vision_error_log.dart';
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
    final entries = (widget.log ?? VisionErrorTelemetry.log).entries;
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
              'Dacă nu există erori în listă, nu înseamnă că '
              'toate funcțiile au fost verificate.',
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
