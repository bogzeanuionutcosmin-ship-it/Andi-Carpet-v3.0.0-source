import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_assistant_avatar.dart';

void main() {
  testWidgets('Vision body has a stable, accessible identity',
      (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: VisionAssistantAvatar())),
    ));

    expect(find.byType(VisionAssistantAvatar), findsOneWidget);
    expect(find.bySemanticsLabel('Vision, asistent grafic'),
        findsOneWidget);
    expect(find.byKey(const Key('vision-assistant-avatar-artwork')),
        findsOneWidget);
    expect(find.descendant(
      of: find.byType(VisionAssistantAvatar),
      matching: find.byType(GestureDetector),
    ), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(tester.takeException(), isNull);
    // Flutter verifies SemanticsHandle disposal before tearDown callbacks.
    semantics.dispose();
  });

  testWidgets('body scales to compact, normal and large sizes without overflow',
      (WidgetTester tester) async {
    for (final size in <double>[36, 48, 96, 180]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: VisionAssistantAvatar(
            key: ValueKey<double>(size), size: size)),
        ),
      ));
      final artwork = find.byKey(
        const Key('vision-assistant-avatar-artwork'));
      expect(tester.getSize(artwork), Size.square(size));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('same artwork works in dark and light themes',
      (WidgetTester tester) async {
    for (final brightness in <Brightness>[
      Brightness.light, Brightness.dark,
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        ),
        home: const Scaffold(body: VisionAssistantAvatar(size: 72)),
      ));
      expect(find.byType(VisionAssistantAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('static body does not animate, navigate or show diagnostics',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VisionAssistantAvatar()),
    ));
    await tester.pump(const Duration(seconds: 8));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.textContaining('gps / '), findsNothing);
    expect(find.textContaining('Incidente locale'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
