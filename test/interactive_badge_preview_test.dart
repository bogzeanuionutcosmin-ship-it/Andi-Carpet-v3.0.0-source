import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/interactive_badge_preview.dart';

Widget _fakeBadge(String asset, {required double size, Color? color}) =>
    Text('$asset:$size');

void main() {
  testWidgets('tap pins and toggles the enlarged badge preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveBadgePreview(
            asset: 'badge-test',
            size: 32,
            badgeGraphic: _fakeBadge,
          ),
        ),
      ),
    );

    expect(find.text('badge-test:32.0'), findsOneWidget);
    await tester.tap(find.text('badge-test:32.0'));
    await tester.pumpAndSettle();
    expect(find.text('badge-test:74.0'), findsOneWidget);

    await tester.tap(find.text('badge-test:32.0'));
    await tester.pumpAndSettle();
    expect(find.text('badge-test:74.0'), findsNothing);
  });

  testWidgets('hover previews temporarily and exit removes the overlay',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveBadgePreview(
            asset: 'badge-test',
            size: 40,
            badgeGraphic: _fakeBadge,
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('badge-test:40.0')));
    await tester.pumpAndSettle();
    expect(find.text('badge-test:86.0'), findsOneWidget);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('badge-test:86.0'), findsNothing);
    await mouse.removePointer();
  });
}
