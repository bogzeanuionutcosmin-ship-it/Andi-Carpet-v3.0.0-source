import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../download_file.dart';
import '../vision/vision_diagnostics_page.dart';
import '../vision/vision_error_telemetry.dart';

/// Standalone, offline manual test application.
/// IMPORTANT: this is deliberately NOT the production entry point:
/// no Firebase.initializeApp, Auth, Firestore, location or AI calls.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VisionErrorTelemetry.initialize();
  VisionErrorTelemetry.installFlutterHandlers();
  runApp(const _OfflineTestApp());
}

/// Compile-time stamp supplied only by the isolated GitHub Actions test build.
const String _visionSmokeRun =
    String.fromEnvironment('VISION_SMOKE_RUN', defaultValue: 'local');

class _OfflineTestApp extends StatelessWidget {
  const _OfflineTestApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: true,
        title: 'AndiCarpet - TEST Offline',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const _SmokeHome(),
      );
}

class _SmokeHome extends StatefulWidget {
  const _SmokeHome();

  @override
  State<_SmokeHome> createState() => _SmokeHomeState();
}

class _SmokeHomeState extends State<_SmokeHome> {
  bool _working = false;

  Future<void> _pdfAction({
    required String asset,
    required String fileName,
    required bool share,
  }) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final bundled = await rootBundle.load(asset);
      final bytes = bundled.buffer.asUint8List(
        bundled.offsetInBytes, bundled.lengthInBytes);
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        _message('A fost deschis dialogul de partajare.');
      } else {
        final saved = await downloadFile(
          bytes, fileName, mimeType: 'application/pdf');
        if (saved) {
          _message('A fost solicitată salvarea fișierului.');
        } else {
          _message('Salvarea a fost anulată.');
        }
      }
    } catch (_) {
      // Do not show exception details or PDF contents in diagnostics.
      VisionErrorTelemetry.report(
        area: 'offline_test', code: 'pdf_action_failed');
      _message('Acțiunea PDF a eșuat. Nu sunt afectate date de lucru.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _pdfCard(String label, String path, String filename) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    onPressed: _working
                        ? null
                        : () => _pdfAction(
                              asset: path,
                              fileName: filename,
                              share: false,
                            ),
                    label: const Text('Descarcă PDF'),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: _working
                        ? null
                        : () => _pdfAction(
                              asset: path,
                              fileName: filename,
                              share: true,
                            ),
                    label: const Text('Partajează PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AndiCarpet Vision TEST')),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              'VISION TEST OFFLINE · BUILD #$_visionSmokeRun',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Fiecare build de test are o aplicație Android separată. '
              'Nu este un update al aplicației de lucru.',
            ),
            const SizedBox(height: 12),
            const Text(
              'MOD DE TEST, SEPARAT DE APLICAȚIA DE LUCRU.\n'
              'Fără login, Firebase, GPS sau date financiare. '
              'Aici verificăm doar salvarea/partajarea PDF-urilor '
              'și jurnalul local de erori.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _pdfCard('Proces verbal MAGIC',
                'assets/pv_magic.pdf', 'PV_MAGIC.pdf'),
            _pdfCard('Proces verbal MILLION',
                'assets/pv_million.pdf', 'PV_MILLION.pdf'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Vision · jurnal erori locale'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const VisionDiagnosticsPage()),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Test persistență: deschide jurnalul, apasă pictograma '
              '„Test local”, revino la ecranul principal, închide '
              'aplicația și redeschide-o. Verifică apoi că '
              '„vision_test / persistence_probe” este încă afișat.',
            ),
          ],
        ),
      );
}
