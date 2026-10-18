import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_assistant_avatar.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';

const avatarKey = Key('vision-diagnostics-avatar');

void main() {
  testWidgets('closed diagnostics keeps the mascot but denies private history',
      (WidgetTester tester) async {
    final log = VisionErrorLog()
      ..record(area: 'gps', code: 'private_test', platform: 'android');

    await tester.pumpWidget(MaterialApp(
      home: VisionDiagnosticsPage(log: log),
    ));

    expect(find.byType(VisionAssistantAvatar), findsOneWidget);
    expect(find.byKey(avatarKey), findsOneWidget);
    expect(find.text('Vision'), findsOneWidget);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    expect(find.text('gps / private_test'), findsNothing);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session-scoped journal retains passive avatar after revocation',
      (WidgetTester tester) async {
    final log = VisionErrorLog()
      ..record(area: 'ocr', code: 'save_failed', platform: 'android');
    var current = true;

    Widget view() => MaterialApp(
      home: VisionDiagnosticsPage(
        log: log, isSessionCurrent: () => current,
      ),
    );
    await tester.pumpWidget(view());
    expect(find.byType(VisionAssistantAvatar), findsOneWidget);
    expect(find.text('ocr / save_failed'), findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsOneWidget);

    current = false;
    await tester.pumpWidget(view());
    expect(find.byType(VisionAssistantAvatar), findsOneWidget);
    expect(find.text('ocr / save_failed'), findsNothing);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device-wide journal remains denied even if owner closure says yes',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: VisionDiagnosticsPage(
        log: VisionErrorTelemetry.log,
        isSessionCurrent: () => true,
      ),
    ));
    expect(find.byKey(avatarKey), findsOneWidget);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen retains readable title and accessible static body',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(
      home: VisionDiagnosticsPage(),
    ));
    expect(find.text('Vision'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Vision, asistent grafic')), findsOneWidget);
    expect(tester.getSize(find.byKey(avatarKey)), const Size(40, 40));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
