import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'support/home_fcm_write_fixture.dart';
import 'support/home_platform_sdk_fixture.dart';
import 'support/home_sync_fixture.dart';

// ONE test in its own Flutter test-file isolate. Cleanup closes the synthetic
// global opened-message source, so this must not be mixed into a shared suite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('KNOWN DEFECT: A late successful token attaches listeners after B and continues refresh after B dispose', (tester) async {
    final originalFcm = FirebaseMessagingPlatform.instance;
    final originalGps = GeolocatorPlatform.instance;
    setupFirebaseCoreMocks(); await Firebase.initializeApp();
    final fcm = ValidTokenFcmFixture()..status = AuthorizationStatus.authorized;
    final db = PushFirestoreFixture(); final sync = HomeSyncFixture();
    FirebaseMessagingPlatform.instance = fcm;
    GeolocatorPlatform.instance = HomeGpsSdkFixture()..enabled = false;
    final tokenA = Completer<String?>(); fcm.tokenResult = tokenA.future;
    try {
      await tester.pumpWidget(MaterialApp(home: PushSdkHomePage(uid: 'a', sync: sync, push: db)));
      await flushHomeFixture(tester); expect(db.attempts, isEmpty);
      fcm.tokenResult = null; fcm.token = 'synthetic-B';
      await tester.pumpWidget(MaterialApp(home: PushSdkHomePage(uid: 'b', sync: sync, push: db)));
      await flushHomeFixture(tester); expect(db.writes.single.data['deviceOwnerUid'], 'b');
      tokenA.complete('synthetic-late-A'); await flushHomeFixture(tester);
      expect(db.writes.map((w) => w.data['deviceOwnerUid']), ['b', 'a']);
      expect(fcm.trace.where((e) => e == 'refresh'), hasLength(2));
      expect(fcm.trace.where((e) => e == 'initial'), hasLength(2));
      await tester.pumpWidget(const SizedBox()); await flushHomeFixture(tester);
      expect(sync.activeCount, 0);
      expect(fcm.refresh.hasListener, isTrue); // orphan A remains; B cancellation is insufficient
      fcm.refresh.add('synthetic-after-B-dispose'); await flushHomeFixture(tester);
      expect(db.writes.map((w) => w.data['deviceOwnerUid']), ['b', 'a', 'a']);
      expect(db.unexpected, isEmpty); expect(db.reads, isEmpty);
    } finally {
      // Cancel-only cleanup of fake event sources, not a runtime remedy. Start
      // closes before pumping their done events to avoid fake-async deadlock.
      final openedClose = FirebaseMessagingPlatform.onMessageOpenedApp.close();
      final refreshClose = fcm.refresh.close();
      await flushHomeFixture(tester); await openedClose; await refreshClose;
      await sync.close();
      FirebaseMessagingPlatform.instance = originalFcm;
      GeolocatorPlatform.instance = originalGps;
    }
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
