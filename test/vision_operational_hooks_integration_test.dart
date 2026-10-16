import 'dart:async';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/expense_document_fixture.dart';
import 'support/home_platform_sdk_fixture.dart';
import 'support/home_sync_fixture.dart';
import 'support/security_gate_fixture.dart';
import 'support/security_home_fixture.dart' as secured;

int occurrences(String area, String code) => VisionErrorTelemetry.log.entries
    .where((e) => e.area == area && e.code == code).fold(0, (n, e) => n + e.count);

class _Permission extends Fake implements NotificationSettings {
  @override AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;
}
class _LatePush extends Fake implements FirebaseMessaging {
  final token = Completer<String?>();
  @override Future<NotificationSettings> getNotificationSettings() async => _Permission();
  @override Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) => token.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Home records GPS FCM and per-diem failures once with fixed anonymous codes', (tester) async {
    final originalFcm = FirebaseMessagingPlatform.instance;
    final originalGps = GeolocatorPlatform.instance;
    setupFirebaseCoreMocks(); await Firebase.initializeApp();
    final fcm = HomeFcmSdkFixture()..status = AuthorizationStatus.authorized;
    final token = Completer<String?>(); fcm.tokenResult = token.future;
    final gps = HomeGpsSdkFixture(); final sync = HomeSyncFixture();
    final beforeGps = occurrences('gps', 'background_stream_failed');
    final beforeFcm = occurrences('fcm', 'initialization_failed');
    final beforeDiem = occurrences('per_diem', 'sync_failed');
    FirebaseMessagingPlatform.instance = fcm; GeolocatorPlatform.instance = gps;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(MaterialApp(home: PlatformSdkHomePage(sync: sync)));
      await flushHomeFixture(tester);
      token.completeError(StateError('SECRET token user@example.test 123.45'));
      gps.positions.addError(StateError('SECRET GPS 44.41234 26.12345'));
      sync.emit('teams', 't1', {'members': ['a'], 'name': 'SECRET Team'});
      await flushHomeFixture(tester);
      sync.query('perDiems[where:teamId=t1]').addError(StateError('SECRET amount 987.65'));
      await flushHomeFixture(tester);
      expect(occurrences('gps', 'background_stream_failed'), beforeGps + 1);
      expect(occurrences('fcm', 'initialization_failed'), beforeFcm + 1);
      expect(occurrences('per_diem', 'sync_failed'), beforeDiem + 1);
      final snapshot = VisionErrorTelemetry.log.encode();
      for (final value in ['SECRET', '@', '123.45', '44.41234', '987.65']) { expect(snapshot, isNot(contains(value))); }
      expect(gps.starts, 1);
      await tester.pumpWidget(const SizedBox());
      expect(gps.cancels, 1); expect(sync.activeCount, 0);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FirebaseMessagingPlatform.instance = originalFcm; GeolocatorPlatform.instance = originalGps;
      await gps.positions.close(); await sync.close();
    }
  });

  testWidgets('late FCM error from A cannot add a diagnostic after UID B invalidates ownership', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    final home = secured.HomeSyncFixture(); final push = _LatePush();
    addTearDown(auth.events.close); addTearDown(db.close); addTearDown(home.close);
    final before = occurrences('fcm', 'initialization_failed');
    await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) => secured.FixtureHomePage(
      key: key, profile: profile, fixture: home, sessionIsCurrent: current,
      messaging: push, realPush: profile.uid == 'a',
    ));
    db.profile('a'); await harness.flush(tester);
    auth.switchTo('b'); await tester.idle();
    push.token.completeError(StateError('SECRET A token'));
    await harness.flush(tester);
    expect(occurrences('fcm', 'initialization_failed'), before);
    expect(home.active['users/a'], 0);
    await tester.pumpWidget(const SizedBox());
    expect(home.activeCount, 0); expect(tester.takeException(), isNull);
  });

  testWidgets('OCR recognition and save failures record once without raw text or retry', (tester) async {
    final beforeOcr = occurrences('ocr', 'recognition_failed');
    final beforeSave = occurrences('ocr', 'document_save_failed');
    final fixture = ExpenseDocumentFixture('SECRET OCR TOTAL 123.45')..failRecognition = true..failSave = true;
    await fixture.mount(tester); await fixture.scan(tester);
    await fixture.enter(tester, 'Nr. bon', 'MANUAL123');
    await fixture.enter(tester, 'Sumă', '200.00');
    await fixture.submit(tester);
    expect(occurrences('ocr', 'recognition_failed'), beforeOcr + 1);
    expect(occurrences('ocr', 'document_save_failed'), beforeSave + 1);
    expect(fixture.attempts, hasLength(1)); expect(fixture.expenses, isEmpty);
    expect(VisionErrorTelemetry.log.encode(), isNot(contains('SECRET')));
    expect(VisionErrorTelemetry.log.encode(), isNot(contains('200.00')));
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });
}
