import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';

void main() {
  testWidgets('Vision shows local summarized events without raw messages',
      (WidgetTester tester) async {
    final log = VisionErrorLog();
    log.record(area: 'ocr', code: 'save_failed', platform: 'android');
    log.record(area: 'ocr', code: 'save_failed', platform: 'android');

    await tester.pumpWidget(MaterialApp(home: VisionDiagnosticsPage(log: log)));

    expect(find.text('Vision · Error Log'), findsOneWidget);
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

}
