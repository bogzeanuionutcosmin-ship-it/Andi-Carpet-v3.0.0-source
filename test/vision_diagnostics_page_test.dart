import 'package:flutter/material.dart';
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
}
