import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/ui/section_visual_helpers.dart';

void main() {
  test('section accents retain their established labels and fallback', () {
    expect(sectionAccent('Acasă'), const Color(0xff2F6BFF));
    expect(sectionAccent('Grafic de lucru'), const Color(0xff7C4DFF));
    expect(sectionAccent('Decont'), const Color(0xff00A86B));
    expect(sectionAccent('necunoscut'), const Color(0xff315EA8));
  });

  test('plain background keeps settings and dark-mode mappings', () {
    final settings = AppSettings();

    settings.background = 'Alb simplu';
    expect(plainBackgroundColor(settings, Brightness.light), Colors.white);
    settings.background = 'Gri deschis';
    expect(plainBackgroundColor(settings, Brightness.light), const Color(0xffeef0f3));
    settings.background = 'Albastru discret';
    expect(plainBackgroundColor(settings, Brightness.light), const Color(0xffeef5fb));
    settings.background = 'Imagine / logo';
    expect(plainBackgroundColor(settings, Brightness.light), const Color(0xfffffbf3));
    settings.background = 'Fundal 1';
    expect(plainBackgroundColor(settings, Brightness.light), const Color(0xfff5f6f8));
    expect(plainBackgroundColor(settings, Brightness.dark), const Color(0xff111318));
  });

  testWidgets('success and error messages retain snackbar content and colors', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(children: [
            TextButton(
              onPressed: () => showSuccessMessage(context, 'Salvat'),
              child: const Text('success'),
            ),
            TextButton(
              onPressed: () => showErrorMessage(context, 'Eroare'),
              child: const Text('error'),
            ),
          ]),
        ),
      ),
    ));

    await tester.tap(find.text('success'));
    await tester.pumpAndSettle();
    expect(find.text('Salvat'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        const Color(0xff087F5B));

    await tester.tap(find.text('error'));
    await tester.pumpAndSettle();
    expect(find.text('Eroare'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        const Color(0xffB42318));
  });
}
