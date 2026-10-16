import 'package:andi_carpeta/vision/vision_authgate_epoch_bridge.dart';
import 'package:andi_carpeta/vision/vision_diagnostic_advisor.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_scoped_signal_sink.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all production signal labels are fixed and safe to serialize', () {
    final combinations = <String>{};
    for (final signal in VisionDiagnosticSignal.values) {
      expect(VisionErrorLog.safeCode(signal.area), signal.area);
      expect(VisionErrorLog.safeCode(signal.code), signal.code);
      expect(combinations.add('${signal.area}/${signal.code}'), isTrue);
      expect(signal.area, isNot(contains('uid')));
      // "token_unavailable" is a static safe label, not a token value.
      expect(signal.code, isNot(contains('=')));
      expect(signal.code, isNot(contains(' ')));
    }
    for (final platform in VisionSignalPlatform.values) {
      expect(VisionErrorLog.safeCode(platform.name), platform.name);
    }
    expect(VisionDiagnosticSignal.values.length, greaterThan(10));
  });

  test('identical signals aggregate without transmitting business context', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    final sink = VisionScopedSignalSink(lease);

    for (var i = 0; i < 10000; i++) {
      expect(sink.emit(
        VisionDiagnosticSignal.financeOperationUncertain,
        platform: VisionSignalPlatform.android,
      ), isTrue);
    }
    final entry = lease.entries.single;
    expect(entry.fingerprint, 'finance/operation_uncertain/android');
    expect(entry.count, 10000);
    expect(entry.severity, VisionErrorSeverity.warning);
    final report = lease.buildReport()!;
    expect(report, contains('operation_uncertain'));
    expect(report, isNot(contains('€')));
    expect(report, isNot(contains('FirebaseAuth')));
    expect(lease.entries.length, 1);
  });

  test('uncertain finance is not misreported as a failed save', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    final sink = VisionScopedSignalSink(lease);
    expect(sink.emit(
      VisionDiagnosticSignal.financeOperationUncertain,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    final advice = VisionDiagnosticAdvisor.assess(
      lease.snapshotForDisplay()!,
    ).single;
    expect(advice.title, 'Rezultat financiar incert');
    expect(advice.explanation, contains('ar putea fi deja aplicată'));
    expect(advice.explanation, contains('aceeași intenție și revizie'));
    expect(advice.explanation, contains('Nu retrimite automat'));
    expect(advice.explanation, isNot(contains('Operațiune financiară nereușită')));
  });

  test('different constant platform/signal labels remain separate and bounded',
      () {
    final journal = VisionSessionJournal(maxEntries: 2, maxBytes: 512);
    final lease = journal.startSession(isSessionCurrent: () => true);
    final sink = VisionScopedSignalSink(lease);
    expect(sink.emit(
      VisionDiagnosticSignal.gpsPermissionDenied,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    expect(sink.emit(
      VisionDiagnosticSignal.gpsPermissionDenied,
      platform: VisionSignalPlatform.web,
    ), isTrue);
    expect(sink.emit(
      VisionDiagnosticSignal.ocrAmountInvalid,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    expect(lease.entries.length, lessThanOrEqualTo(2));
    expect(lease.snapshotForDisplay()!.encodedBytes, lessThanOrEqualTo(512));
  });

  test('A to B to A2 denies old producer without moving any events', () {
    final journal = VisionSessionJournal();
    var uid = 'a';
    var epoch = 1;
    final a = journal.startSession(
      isSessionCurrent: () => uid == 'a' && epoch == 1,
    );
    final sinkA = VisionScopedSignalSink(a);
    expect(sinkA.emit(
      VisionDiagnosticSignal.ocrRecognitionFailed,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    uid = 'b';
    epoch = 2;
    final b = journal.startSession(
      isSessionCurrent: () => uid == 'b' && epoch == 2,
    );
    expect(sinkA.emit(
      VisionDiagnosticSignal.ocrRecognitionFailed,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(a.entries, isEmpty);
    expect(b.entries, isEmpty);

    final sinkB = VisionScopedSignalSink(b);
    expect(sinkB.emit(
      VisionDiagnosticSignal.fcmTokenUnavailable,
      platform: VisionSignalPlatform.web,
    ), isTrue);
    uid = 'a';
    epoch = 3;
    final a2 = journal.startSession(
      isSessionCurrent: () => uid == 'a' && epoch == 3,
    );
    expect(sinkB.emit(
      VisionDiagnosticSignal.fcmTokenUnavailable,
      platform: VisionSignalPlatform.web,
    ), isFalse);
    expect(b.entries, isEmpty);
    expect(a2.entries, isEmpty);
    expect(VisionScopedSignalSink(a2).emit(
      VisionDiagnosticSignal.syncOffline,
      platform: VisionSignalPlatform.windows,
    ), isTrue);
    expect(a2.entries.single.fingerprint, 'sync/offline/windows');
  });

  test('revocation, throwing authority and disposal fail closed', () {
    final journal = VisionSessionJournal();
    var valid = true;
    final lease = journal.startSession(isSessionCurrent: () {
      if (!valid) throw StateError('private failure details');
      return true;
    });
    final sink = VisionScopedSignalSink(lease);
    expect(sink.emit(
      VisionDiagnosticSignal.authProfileUnavailable,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    valid = false;
    expect(sink.emit(
      VisionDiagnosticSignal.authProfileUnavailable,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(lease.entries, isEmpty);
    expect(lease.buildReport(), isNull);
    valid = true;
    expect(sink.emit(
      VisionDiagnosticSignal.authProfileUnavailable,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    journal.revoke();
    expect(sink.emit(
      VisionDiagnosticSignal.authProfileUnavailable,
      platform: VisionSignalPlatform.android,
    ), isFalse);
  });

  test('session log expires old anonymous signals without network or timer', () {
    var now = DateTime.utc(2026, 10, 16);
    final journal = VisionSessionJournal(
      clock: () => now,
      retention: const Duration(days: 7),
    );
    final lease = journal.startSession(isSessionCurrent: () => true);
    final sink = VisionScopedSignalSink(lease);
    expect(sink.emit(
      VisionDiagnosticSignal.mapRouteUnavailable,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    now = now.add(const Duration(days: 8));
    expect(lease.entries, isEmpty);
    expect(lease.buildReport(), isNotNull);
  });

  testWidgets('authenticated widget supplies sink only during valid epoch',
      (tester) async {
    var generation = 1;
    bool ownerA() => generation == 1;
    bool ownerB() => generation == 2;
    VisionScopedSignalSink? sinkA;
    VisionScopedSignalSink? sinkB;
    Widget screen(bool Function() owner, bool second) => MaterialApp(
      home: VisionAuthGateEpochBridge(
        sessionIsCurrent: owner,
        builder: (context, lease) {
          if (lease == null) {
            return const Scaffold(body: Text('DENIED'));
          }
          if (second) {
            sinkB = VisionScopedSignalSink(lease);
          } else {
            sinkA = VisionScopedSignalSink(lease);
          }
          return const Scaffold(body: Text('AUTHORIZED'));
        },
      ),
    );

    await tester.pumpWidget(screen(ownerA, false));
    expect(sinkA, isNotNull);
    expect(sinkA!.emit(
      VisionDiagnosticSignal.gpsLocationUnavailable,
      platform: VisionSignalPlatform.android,
    ), isTrue);

    generation = 2;
    await tester.pumpWidget(screen(ownerB, true));
    expect(sinkA!.emit(
      VisionDiagnosticSignal.gpsLocationUnavailable,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(sinkB, isNotNull);
    expect(sinkB!.emit(
      VisionDiagnosticSignal.gpsLocationUnavailable,
      platform: VisionSignalPlatform.android,
    ), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(sinkB!.emit(
      VisionDiagnosticSignal.gpsLocationUnavailable,
      platform: VisionSignalPlatform.android,
    ), isFalse);
    expect(tester.takeException(), isNull);
  });
}
