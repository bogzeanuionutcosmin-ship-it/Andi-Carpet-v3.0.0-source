import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_assistant_avatar.dart';
import 'package:andi_carpeta/vision/vision_avatar_preview_app.dart';

void main() {
  testWidgets('offline preview starts in light mode, no private diagnostics',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VisionAvatarPreviewApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(find.text('Vision · corpul asistentului'), findsOneWidget);
    expect(find.byKey(const Key('vision-preview-disclaimer')), findsOneWidget);
    expect(find.byType(VisionAssistantAvatar), findsOneWidget);
    expect(find.textContaining('nu un asistent activ'), findsOneWidget);
    expect(find.textContaining('gps / '), findsNothing);
    expect(find.textContaining('Incidente locale'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme control switches only preview appearance',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VisionAvatarPreviewApp());
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light);

    await tester.tap(find.byKey(const Key('vision-preview-theme-toggle')));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
    expect(find.byType(VisionAssistantAvatar), findsOneWidget);

    await tester.tap(find.byKey(const Key('vision-preview-theme-toggle')));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('size choices redraw the same static body',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VisionAvatarPreviewApp());

    for (final size in <int>[64, 176, 112]) {
      await tester.ensureVisible(
        find.byKey(Key('vision-preview-size-$size')),
      );
      await tester.tap(find.byKey(Key('vision-preview-size-$size')));
      await tester.pumpAndSettle();
      final avatar = find.byType(VisionAssistantAvatar);
      expect(tester.getSize(avatar), Size.square(size.toDouble()));
      expect(find.byKey(const Key('vision-assistant-avatar-artwork')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('compact portrait/landscape and text scale do not overflow',
      (WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final size in <Size>[
      const Size(320, 568),
      const Size(568, 320),
      const Size(360, 640),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: const VisionAvatarPreviewApp(),
      ));
      await tester.pumpAndSettle();
      // The scrollable preview legitimately builds below-fold content lazily.
      // Test actual reachability, not a false assumption that every child
      // must be painted on the first frame of a 320 px landscape viewport.
      await tester.scrollUntilVisible(
        find.byType(VisionAssistantAvatar),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(VisionAssistantAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('preview has no navigation, permission or action to upload',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VisionAvatarPreviewApp());
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('vision-preview-offline-note')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('conexiune la server'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
