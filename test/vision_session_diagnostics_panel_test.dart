import 'dart:async';

import 'package:andi_carpeta/vision/vision_scoped_signal_sink.dart';
import 'package:andi_carpeta/vision/vision_session_diagnostics_panel.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _screen(VisionSessionJournalLease? lease) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 640,
      child: VisionSessionDiagnosticsPanel(lease: lease),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unauthenticated or null lease never exposes device log',
      (tester) async {
    await tester.pumpWidget(_screen(null));
    expect(find.byKey(const ValueKey('vision-session-closed')), findsOneWidget);
    expect(find.byKey(const ValueKey('vision-session-copy')), findsNothing);
    expect(find.textContaining('istoricul altui cont'), findsOneWidget);
  });

  testWidgets('session A report is fixed-code, manual and not shared to B',
      (tester) async {
    final copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final journal = VisionSessionJournal();
    var ownerA = true;
    final leaseA = journal.startSession(
      isSessionCurrent: () => ownerA,
    );
    final sinkA = VisionScopedSignalSink(leaseA);
    await tester.pumpWidget(_screen(leaseA));
    expect(find.byKey(const ValueKey('vision-session-open')), findsOneWidget);
    expect(find.textContaining('Niciun incident local'), findsOneWidget);

    expect(sinkA.emit(
      VisionDiagnosticSignal.financeOperationUncertain,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    await tester.tap(find.byKey(const ValueKey('vision-session-refresh')));
    await tester.pump();
    expect(find.text('Rezultat financiar incert'), findsOneWidget);
    expect(find.textContaining('ar putea fi deja aplicată'), findsOneWidget);
    expect(find.text('finance/operation_uncertain'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vision-session-copy')));
    await tester.pump();
    expect(copied, hasLength(1));
    expect(copied.single, contains('finance/operation_uncertain'));
    expect(copied.single, isNot(contains('private')));
    expect(copied.single, isNot(contains('token=')));

    ownerA = false;
    final leaseB = journal.startSession(isSessionCurrent: () => true);
    await tester.pumpWidget(_screen(leaseB));
    await tester.pump();
    expect(find.byKey(const ValueKey('vision-session-open')), findsOneWidget);
    expect(find.text('finance/operation_uncertain'), findsNothing);
    expect(find.textContaining('Niciun incident local'), findsOneWidget);
    expect(leaseA.buildReport(), isNull);
    expect(sinkA.emit(
      VisionDiagnosticSignal.financeOperationUncertain,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    await tester.tap(find.byKey(const ValueKey('vision-session-copy')));
    await tester.pump();
    expect(copied, hasLength(2));
    expect(copied.last, isNot(contains('operation_uncertain')));
  });

  testWidgets('revoking live lease closes panel synchronously on next frame',
      (tester) async {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    expect(VisionScopedSignalSink(lease).emit(
      VisionDiagnosticSignal.gpsPermissionDenied,
      platform: VisionSignalPlatform.web,
    ), isTrue);
    await tester.pumpWidget(_screen(lease));
    expect(find.text('gps/permission_denied'), findsOneWidget);
    journal.revoke();
    await tester.pump();
    expect(find.byKey(const ValueKey('vision-session-closed')), findsOneWidget);
    expect(find.text('gps/permission_denied'), findsNothing);
    expect(find.byKey(const ValueKey('vision-session-copy')), findsNothing);
  });

  testWidgets('late clipboard result cannot display success in other session',
      (tester) async {
    final copied = <String>[];
    final clipboardGate = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
        await clipboardGate.future;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final journal = VisionSessionJournal();
    final a = journal.startSession(isSessionCurrent: () => true);
    expect(VisionScopedSignalSink(a).emit(
      VisionDiagnosticSignal.financeOperationUncertain,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    await tester.pumpWidget(_screen(a));
    await tester.tap(find.byKey(const ValueKey('vision-session-copy')));
    await tester.pump();
    expect(copied, hasLength(1));

    journal.revoke();
    final b = journal.startSession(isSessionCurrent: () => true);
    await tester.pumpWidget(_screen(b));
    clipboardGate.complete();
    await tester.pump();
    expect(find.text('Raportul local a fost copiat la cerere.'), findsNothing);
    expect(find.text('finance/operation_uncertain'), findsNothing);
    expect(find.byKey(const ValueKey('vision-session-open')), findsOneWidget);
    expect(a.buildReport(), isNull);
  });

  testWidgets('A1 to B to A2 with reused UID never reuses previous report',
      (tester) async {
    var uid = 'A', generation = 1;
    final journal = VisionSessionJournal();
    final a1 = journal.startSession(
      isSessionCurrent: () => uid == 'A' && generation == 1,
    );
    VisionScopedSignalSink(a1).emit(
      VisionDiagnosticSignal.ocrRecognitionFailed,
      platform: VisionSignalPlatform.android,
    );
    await tester.pumpWidget(_screen(a1));
    expect(find.text('ocr/recognition_failed'), findsOneWidget);
    uid = 'B';
    generation = 2;
    final b = journal.startSession(
      isSessionCurrent: () => uid == 'B' && generation == 2,
    );
    await tester.pumpWidget(_screen(b));
    expect(find.text('ocr/recognition_failed'), findsNothing);
    uid = 'A';
    generation = 3;
    final a2 = journal.startSession(
      isSessionCurrent: () => uid == 'A' && generation == 3,
    );
    await tester.pumpWidget(_screen(a2));
    expect(find.text('ocr/recognition_failed'), findsNothing);
    expect(a1.entries, isEmpty);
    expect(b.entries, isEmpty);
    expect(a2.entries, isEmpty);
  });
}
