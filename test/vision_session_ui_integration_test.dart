import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/vision/vision_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';

void main() {
  testWidgets('clipboard completion from A cannot show feedback after SDK B before disposal', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    final copied = Completer<void>(); var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') { calls++; await copied.future; }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) => Builder(key: key, builder: (context) => Scaffold(body: TextButton(
      child: const Text('Open internal diagnostic'), onPressed: () {
        final local = VisionErrorLog()..record(area: 'fcm', code: 'initialization_failed', platform: 'android');
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VisionDiagnosticsPage(log: local, isSessionCurrent: current)));
      },
    ))));
    db.profile('a'); await harness.flush(tester);
    await tester.tap(find.text('Open internal diagnostic')); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copiază raport tehnic anonimizat')); await tester.idle();
    expect(calls, 1);
    auth.switchTo('b'); await tester.idle();
    copied.complete(); await tester.idle();
    expect(find.textContaining('Raportul tehnic a fost copiat'), findsNothing);
    await harness.flush(tester);
    expect(find.byType(VisionDiagnosticsPage), findsNothing);
    expect(calls, 1); // An OS copy already initiated is not retroactively revoked.
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });

  for (final logout in [false, true]) {
    testWidgets('test-only Vision context drops routes, sheets and clipboard feedback on ${logout ? "logout" : "A B A"}', (tester) async {
      final auth = SessionAuth(); final db = SessionFirestore();
      addTearDown(auth.events.close); addTearDown(db.close);
      var copies = 0; final reports = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copies++; reports.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      var contexts = 0;
      await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) => Builder(key: key, builder: (context) => Scaffold(body: TextButton(
        child: const Text('Open internal diagnostic'), onPressed: () {
          if (!current()) return;
          contexts++;
          final local = VisionErrorLog()..record(area: 'gps', code: 'background_start_failed', platform: 'android');
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VisionDiagnosticsPage(log: local, isSessionCurrent: current)));
        },
      ))));
      db.profile('a'); await harness.flush(tester);
      await tester.tap(find.text('Open internal diagnostic')); await tester.pumpAndSettle();
      expect(find.byType(VisionDiagnosticsPage), findsOneWidget); expect(copies, 0);
      await tester.tap(find.byTooltip('Copiază raport tehnic anonimizat')); await tester.pumpAndSettle();
      expect(copies, 1); expect(reports.single, isNot(contains('users/a')));
      await tester.tap(find.byTooltip('Ce monitorizează Vision')); await tester.pumpAndSettle();
      expect(find.text('Acoperirea diagnosticului Vision'), findsOneWidget);
      if (logout) { auth.switchTo(null); } else { auth.switchTo('b'); }
      await harness.flush(tester);
      expect(find.byType(VisionDiagnosticsPage), findsNothing);
      expect(find.text('Acoperirea diagnosticului Vision'), findsNothing);
      expect(find.textContaining('Raportul tehnic a fost copiat'), findsNothing);
      expect(copies, 1); // No automatic copy on session teardown/rebuild.
      auth.switchTo('a'); await harness.flush(tester); db.profile('a'); await harness.flush(tester);
      expect(find.byType(VisionDiagnosticsPage), findsNothing); expect(contexts, 1);
      await tester.tap(find.text('Open internal diagnostic')); await tester.pumpAndSettle();
      expect(contexts, 2); expect(copies, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
