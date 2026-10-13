import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/app_backdrop.dart';

void main() {
  testWidgets('keeps child and contrast overlay when custom base64 is invalid',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: AppBackdrop(
            plainBackground: Colors.pink,
            bundledAsset: null,
            customBackgroundBase64: '*invalid*',
            backgroundOpacity: .42,
            child: const Text('Screen content'),
          ),
        ),
      ),
    );

    expect(find.text('Screen content'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    final backgrounds = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(backgrounds.length, 2);
    expect(backgrounds.first.color, Colors.pink);
    expect(backgrounds.last.color, Colors.white.withValues(alpha: .10));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: AppBackdrop(
            plainBackground: Colors.pink,
            bundledAsset: null,
            customBackgroundBase64: '*invalid*',
            backgroundOpacity: .42,
            child: const Text('Screen content'),
          ),
        ),
      ),
    );

    final darkBackgrounds = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(darkBackgrounds.length, 1);
    expect(darkBackgrounds.single.color, Colors.pink);
  });
}
