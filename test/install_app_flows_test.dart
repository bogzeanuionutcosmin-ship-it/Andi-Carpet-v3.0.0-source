import 'dart:async';

import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/ui/install_app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mount(WidgetTester tester, VoidCallback Function(BuildContext) action) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
    builder: (context) => TextButton(onPressed: action(context), child: const Text('Open')),
  ))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text('Continuă la descărcare'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cancel retains instructions and never launches a URL', (tester) async {
    var calls = 0;
    late Future<void> operation;
    await _mount(tester, (context) => () {
      operation = showAndroidInstallFlow(context,
        AppSettings()..androidDownloadUrl = 'https://example.invalid/synthetic.apk',
        launchExternal: (uri) async { calls++; return true; });
    });
    expect(find.textContaining('Auto Blocker'), findsOneWidget);
    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();
    await operation;
    expect(calls, 0);
  });

  testWidgets('empty and invalid URLs retain their error paths without launching', (tester) async {
    for (final raw in ['', 'https://[invalid']) {
      var calls = 0;
      late Future<void> operation;
      await _mount(tester, (context) => () {
        operation = showAndroidInstallFlow(context,
          AppSettings()..androidDownloadUrl = raw,
          launchExternal: (uri) async { calls++; return true; });
      });
      await _confirm(tester);
      await operation;
      expect(calls, 0);
      expect(find.textContaining(raw.isEmpty
          ? 'Linkul APK nu este încă publicat.'
          : 'Linkul pentru APK nu a putut fi deschis.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('confirmation trims once and forwards exactly one URI', (tester) async {
    final uris = <Uri>[];
    late Future<void> operation;
    await _mount(tester, (context) => () {
      operation = showAndroidInstallFlow(context,
        AppSettings()..androidDownloadUrl = ' https://example.invalid/synthetic.apk ',
        launchExternal: (uri) async { uris.add(uri); return false; });
    });
    await _confirm(tester);
    await operation;
    expect(uris, [Uri.parse('https://example.invalid/synthetic.apk')]);
    expect(find.text('Linkul pentru APK nu a putut fi deschis.'), findsOneWidget);
  });

  testWidgets('late launcher result after page disposal produces no snackbar', (tester) async {
    final pending = Completer<bool>();
    late Future<void> operation;
    await _mount(tester, (context) => () {
      operation = showAndroidInstallFlow(context,
        AppSettings()..androidDownloadUrl = 'https://example.invalid/synthetic.apk',
        launchExternal: (uri) => pending.future);
    });
    await _confirm(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(false);
    await operation;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('launcher exceptions propagate without implicit retry', (tester) async {
    final pending = Completer<bool>();
    late Future<void> operation;
    var calls = 0;
    await _mount(tester, (context) => () {
      operation = showAndroidInstallFlow(context,
        AppSettings()..androidDownloadUrl = 'https://example.invalid/synthetic.apk',
        launchExternal: (uri) { calls++; return pending.future; });
    });
    final failure = StateError('synthetic launcher failure');
    final assertion = expectLater(operation, throwsA(same(failure)));
    await _confirm(tester);
    pending.completeError(failure);
    await assertion;
    expect(calls, 1);
  });

  testWidgets('Apple flow retains Safari instructions and dismisses normally', (tester) async {
    late Future<void> operation;
    await _mount(tester, (context) => () {
      operation = showAppleInstallFlow(context);
    });
    expect(find.textContaining('Safari → Partajare → Adaugă pe ecranul principal'), findsOneWidget);
    await tester.tap(find.text('Am înțeles'));
    await tester.pumpAndSettle();
    await operation;
  });
}
