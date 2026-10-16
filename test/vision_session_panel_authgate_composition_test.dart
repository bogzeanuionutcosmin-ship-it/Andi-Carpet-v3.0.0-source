import 'package:andi_carpeta/vision/vision_authgate_epoch_bridge.dart';
import 'package:andi_carpeta/vision/vision_scoped_signal_sink.dart';
import 'package:andi_carpeta/vision/vision_session_diagnostics_panel.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real epoch bridge and panel keep harmless rebuild, isolate A-B-A2',
      (tester) async {
    var epoch = 1;
    VisionSessionJournalLease? visibleLease;
    Widget ui(bool Function() isCurrent) => MaterialApp(
      home: VisionAuthGateEpochBridge(
        sessionIsCurrent: isCurrent,
        builder: (context, lease) {
          visibleLease = lease;
          return Scaffold(
            body: SizedBox(
              height: 600,
              child: VisionSessionDiagnosticsPanel(lease: lease),
            ),
          );
        },
      ),
    );

    bool first() => epoch == 1;
    await tester.pumpWidget(ui(first));
    final a = visibleLease!;
    expect(a.isCurrent, isTrue);
    expect(VisionScopedSignalSink(a).emit(
      VisionDiagnosticSignal.financeOperationUncertain,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    await tester.tap(find.byKey(const ValueKey('vision-session-refresh')));
    await tester.pump();
    expect(find.text('finance/operation_uncertain'), findsOneWidget);

    // Harmless rebuild: closure instance changes but the first generation
    // remains authoritative. This must retain the same lease and data.
    await tester.pumpWidget(ui(() => epoch == 1));
    expect(identical(visibleLease, a), isTrue);
    expect(find.text('finance/operation_uncertain'), findsOneWidget);

    epoch = 2;
    await tester.pumpWidget(ui(() => epoch == 2));
    final b = visibleLease!;
    expect(identical(b, a), isFalse);
    expect(a.isCurrent, isFalse);
    expect(a.entries, isEmpty);
    expect(find.text('finance/operation_uncertain'), findsNothing);
    expect(find.textContaining('Niciun incident local'), findsOneWidget);
    expect(VisionScopedSignalSink(b).emit(
      VisionDiagnosticSignal.ocrRecognitionFailed,
      platform: VisionSignalPlatform.web,
    ), isTrue);
    await tester.tap(find.byKey(const ValueKey('vision-session-refresh')));
    await tester.pump();
    expect(find.text('ocr/recognition_failed'), findsOneWidget);

    epoch = 3; // Same UID A, new AuthGate generation, still a fresh journal.
    await tester.pumpWidget(ui(() => epoch == 3));
    final a2 = visibleLease!;
    expect(identical(a2, a), isFalse);
    expect(identical(a2, b), isFalse);
    expect(a2.isCurrent, isTrue);
    expect(b.isCurrent, isFalse);
    expect(find.text('finance/operation_uncertain'), findsNothing);
    expect(find.text('ocr/recognition_failed'), findsNothing);
    expect(find.textContaining('Niciun incident local'), findsOneWidget);
    expect(a.buildReport(), isNull);
    expect(b.buildReport(), isNull);
    expect(tester.takeException(), isNull);
  });
}
