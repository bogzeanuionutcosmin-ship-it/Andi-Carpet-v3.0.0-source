import 'dart:async';
import 'package:andi_carpeta/vision/vision_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:andi_carpeta/vision/vision_local_persistence.dart';
import 'package:andi_carpeta/vision/vision_persistence_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';

void main() {
  for (final platform in ['android', 'web', 'windows']) {
    testWidgets('cold restored device journal remains closed for B on $platform', (tester) async {
      final seed = VisionErrorLog()..record(area: 'system', code: 'prior_installation_marker', platform: platform);
      final deviceLog = VisionErrorTelemetry.log;
      final persistence = VisionLocalPersistence(log: deviceLog,
        read: () async => seed.encode(), write: (_) async => throw StateError('unavailable'));
      await persistence.initialize(); await persistence.flush();
      expect(persistence.status.state, VisionPersistenceState.memoryOnly);
      expect(deviceLog.entries.any((e) => e.code == 'prior_installation_marker'), isTrue);
      final auth = SessionAuth()..switchTo('b'); final db = SessionFirestore();
      addTearDown(auth.events.close); addTearDown(db.close);
      var copies = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copies++;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) =>
        VisionDiagnosticsPage(key: key, log: deviceLog, isSessionCurrent: current));
      db.profile('b'); await harness.flush(tester);
      for (var i = 0; i < 3; i++) {
        expect(find.textContaining('prior_installation_marker'), findsNothing);
        expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
        db.profile('b'); await harness.flush(tester);
      }
      expect(copies, 0);
      expect(deviceLog.entries.any((e) => e.code == 'prior_installation_marker'), isTrue);
      await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
    });
  }

  testWidgets('copy callback captured in old A epoch cannot revive when A returns', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    var copies = 0; final owners = <bool Function()>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copies++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) {
      owners.add(current);
      final local = VisionErrorLog()..record(area: 'gps', code: 'epoch_${profile.uid}', platform: 'android');
      return VisionDiagnosticsPage(key: key, log: local, isSessionCurrent: current);
    });
    db.profile('a'); await harness.flush(tester);
    final originalOwner = owners.last;
    final staleCopy = tester.widget<IconButton>(find.byTooltip('Copiază raport tehnic anonimizat')).onPressed!;
    expect(originalOwner(), isTrue);
    auth.switchTo('b'); await harness.flush(tester); db.profile('b'); await harness.flush(tester);
    expect(originalOwner(), isFalse);
    auth.switchTo('a'); await harness.flush(tester); db.profile('a'); await harness.flush(tester);
    expect(originalOwner(), isFalse); expect(owners.last(), isTrue);
    staleCopy(); await tester.pump(); expect(copies, 0);
    await tester.tap(find.byTooltip('Copiază raport tehnic anonimizat')); await tester.pump();
    expect(copies, 1); // Legitimate new A epoch remains usable.
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });
}
