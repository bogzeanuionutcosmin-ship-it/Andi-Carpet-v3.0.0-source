import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/ui/install_app_buttons_view.dart';

void main() {
  testWidgets('renders full labels and forwards platform callbacks',
      (tester) async {
    var androidPressed = 0;
    var applePressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstallAppButtonsView(
            onAndroidPressed: () => androidPressed++,
            onApplePressed: () => applePressed++,
          ),
        ),
      ),
    );

    expect(find.text('Instalează aplicația · Android'), findsOneWidget);
    expect(find.text('Instalează aplicația · Apple'), findsOneWidget);
    await tester.tap(find.text('Instalează aplicația · Android'));
    await tester.tap(find.text('Instalează aplicația · Apple'));
    expect(androidPressed, 1);
    expect(applePressed, 1);
  });

  testWidgets('keeps compact labels for dashboard use', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstallAppButtonsView(
            compact: true,
            onAndroidPressed: () {},
            onApplePressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Android'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Instalează aplicația · Android'), findsNothing);
    expect(find.text('Instalează aplicația · Apple'), findsNothing);
  });
}
