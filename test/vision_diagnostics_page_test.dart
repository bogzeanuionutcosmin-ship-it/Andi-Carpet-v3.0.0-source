import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';

void main() {
  testWidgets('authenticated device-wide journal stays closed without a '
      'session-scoped source', (WidgetTester tester) async {
    // No injected/scope-verified log and no offline-smoke define: do not
    // expose a persisted installation-wide journal across account changes.
    await tester.pumpWidget(
      const MaterialApp(home: VisionDiagnosticsPage()),
    );
    expect(find.text('Vision'), findsOneWidget);
    expect(find.textContaining('istoricul poate fi izolat sigur'),
        findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
    expect(find.byTooltip('Actualizează'), findsNothing);
    expect(find.byTooltip('Test local · salvare jurnal'), findsNothing);
    expect(find.textContaining('Incidente locale:'), findsNothing);

    // Passing the same installation-wide singleton explicitly must not
    // bypass the closed production view.
    await tester.pumpWidget(MaterialApp(
      home: VisionDiagnosticsPage(log: VisionErrorTelemetry.log),
    ));
    expect(find.textContaining('istoricul poate fi izolat sigur'),
        findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
  });

  testWidgets('small screen keeps full Vision title and test is not an alert',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final log = VisionErrorLog();
    log.record(area: 'vision_test', code: 'persistence_probe',
      platform: 'android', severity: VisionErrorSeverity.warning);
    log.record(area: 'vision_test', code: 'persistence_probe',
      platform: 'android', severity: VisionErrorSeverity.warning);
    await tester.pumpWidget(MaterialApp(
      home: VisionDiagnosticsPage(log: log),
    ));
    expect(find.text('Vision'), findsOneWidget);
    expect(find.textContaining('Vision observă:'), findsNothing);
    expect(find.textContaining('Test de persistență'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.textContaining('Probă locală'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('injected log never claims local persistence',
      (WidgetTester tester) async {
    final log = VisionErrorLog();
    log.record(area: 'ocr', code: 'save_failed', platform: 'android');
    await tester.pumpWidget(MaterialApp(home: VisionDiagnosticsPage(log: log)));
    expect(find.textContaining('Jurnal de probă'), findsOneWidget);
    expect(find.textContaining('salvată local'), findsNothing);
  });

  testWidgets('Vision shows local summarized events without raw messages',
      (WidgetTester tester) async {
    final log = VisionErrorLog();
    log.record(area: 'ocr', code: 'save_failed', platform: 'android');
    log.record(area: 'ocr', code: 'save_failed', platform: 'android');

    await tester.pumpWidget(MaterialApp(home: VisionDiagnosticsPage(log: log)));

    expect(find.text('Vision'), findsOneWidget);
    expect(find.text('ocr / save_failed'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.textContaining('Nu trimitem'), findsOneWidget);
    // Injected read-only logs must not expose the test-error action.
    expect(find.byTooltip('Test local · salvare jurnal'), findsNothing);
  });

  testWidgets('Vision explains that an empty log is not a health guarantee',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: VisionDiagnosticsPage(log: VisionErrorLog())),
    );
    expect(find.text('Nu există erori locale în jurnal.'), findsOneWidget);
    expect(find.textContaining('nu înseamnă că'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.text('Nu există erori locale în jurnal.'), findsOneWidget);
  });
  testWidgets('Vision copies an opt-in sanitized report, without networking',
      (WidgetTester tester) async {
    final log = VisionErrorLog();
    log.record(
      area: 'ocr',
      code: 'save_failed',
      platform: 'android',
    );
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      MaterialApp(home: VisionDiagnosticsPage(log: log)),
    );
    expect(clipboard, isNull); // Copy is NEVER automatic.
    await tester.tap(find.byTooltip('Copiază raport tehnic anonimizat'));
    await tester.pump();
    expect(clipboard, contains('ocr/save_failed'));
    expect(clipboard, contains('fara upload automat'));
    expect(clipboard, isNot(contains('FirebaseFirestore')));
    expect(find.textContaining('Raportul tehnic a fost copiat'), findsOneWidget);
  });

  testWidgets('Vision gives read-only actionable advice for OCR save failures',
      (WidgetTester tester) async {
    final log = VisionErrorLog();
    log.record(area: 'ocr', code: 'document_save_failed',
      platform: 'android');
    await tester.pumpWidget(MaterialApp(home: VisionDiagnosticsPage(log: log)));
    expect(find.text('Vision observă: Salvarea documentului necesită verificare'), findsOneWidget);
    expect(find.textContaining('Verifică evidența'), findsOneWidget);
    expect(log.entries.single.count, 1);
  });

  testWidgets('Vision displays single versus repeated observation counts',
      (WidgetTester tester) async {
    final log = VisionErrorLog();
    log.record(area: 'ocr', code: 'document_save_failed',
      platform: 'android');
    await tester.pumpWidget(MaterialApp(home: VisionDiagnosticsPage(log: log)));
    expect(find.text('Observată o singură dată'), findsOneWidget);

    log.record(area: 'ocr', code: 'document_save_failed',
      platform: 'android');
    await tester.tap(find.byTooltip('Actualizează'));
    await tester.pump();
    expect(find.text('Repetată: 2 apariții în jurnalul local'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('Vision explains which areas are instrumented and which are not',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: VisionDiagnosticsPage(log: VisionErrorLog())),
    );
    expect(find.text('Acoperirea diagnosticului Vision'), findsNothing);
    await tester.tap(find.byTooltip('Ce monitorizează Vision'));
    await tester.pumpAndSettle();
    expect(find.text('Acoperirea diagnosticului Vision'), findsOneWidget);
    expect(find.text('Flutter / Dart'), findsOneWidget);
    expect(find.text('Parțial instrumentat'), findsWidgets);
    expect(find.textContaining('nu certifică lipsa erorilor'), findsOneWidget);
  });

  testWidgets('Vision does not invent health advice without active incidents',
      (WidgetTester tester) async {
    final log = VisionErrorLog();
    log.record(area: 'gps', code: 'location_update_failed',
      platform: 'android');
    expect(log.resolve(log.entries.single.fingerprint), isTrue);
    await tester.pumpWidget(MaterialApp(home: VisionDiagnosticsPage(log: log)));
    expect(find.textContaining('Vision observă:'), findsNothing);
    expect(find.text('gps / location_update_failed'), findsOneWidget);
  });

}
