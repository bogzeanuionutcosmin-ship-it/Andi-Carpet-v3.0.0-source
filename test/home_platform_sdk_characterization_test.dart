import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'support/home_platform_sdk_fixture.dart';
import 'support/home_sync_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fcm = HomeFcmSdkFixture();
  final originalMessaging = FirebaseMessagingPlatform.instance;
  final originalGps = GeolocatorPlatform.instance;
  late HomeGpsSdkFixture gps;
  late HomeSyncFixture sync;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp(); // Pigeon fake only, no real project.
    FirebaseMessagingPlatform.instance = fcm;
  });
  tearDownAll(() {
    FirebaseMessagingPlatform.instance = originalMessaging;
    GeolocatorPlatform.instance = originalGps;
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    fcm.reset(); gps = HomeGpsSdkFixture(); sync = HomeSyncFixture();
    GeolocatorPlatform.instance = gps;
  });
  tearDown(() async {
    await gps.positions.close(); await sync.close();
    GeolocatorPlatform.instance = originalGps;
    debugDefaultTargetPlatformOverride = null;
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: PlatformSdkHomePage(sync: sync)));
    await flushHomeFixture(tester);
  }

  testWidgets('real native GPS starts economic stream and cancels after stream error', (tester) async {
    await mount(tester);
    expect(gps.trace, ['check', 'enabled', 'check', 'stream', 'listen']);
    expect(gps.starts, 1); expect(gps.cancels, 0);
    final settings = gps.streamSettings as AndroidSettings;
    expect(settings.accuracy, LocationAccuracy.medium);
    expect(settings.distanceFilter, 60);
    expect(settings.intervalDuration, const Duration(minutes: 1));
    expect(settings.foregroundNotificationConfig, isNotNull);
    gps.positions.addError(StateError('synthetic stream error'));
    await flushHomeFixture(tester);
    expect(gps.starts, 1); expect(gps.cancels, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(gps.cancels, 1); expect(sync.activeCount, 0);
    expect(fcm.trace, ['permission']);
  });

  testWidgets('disabled GPS never checks native permission or attaches', (tester) async {
    gps.enabled = false;
    await mount(tester);
    expect(gps.trace, ['check', 'enabled']);
    expect(gps.starts, 0);
    await tester.pumpWidget(const SizedBox());
    expect(gps.cancels, 0); expect(sync.activeCount, 0);
  });

  testWidgets('denied native permission requests once and refusal stops attachment', (tester) async {
    gps.permission = LocationPermission.denied;
    await mount(tester);
    expect(gps.trace, ['check', 'enabled', 'check', 'request']);
    expect(gps.starts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('permanent GPS denial never opens a permission request', (tester) async {
    gps.permission = LocationPermission.deniedForever;
    await mount(tester);
    expect(gps.trace, ['check', 'enabled', 'check']);
    expect(gps.starts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('KNOWN DEFECT: native GPS can attach after Home dispose when enabled completes late', (tester) async {
    final enabled = Completer<bool>(); gps.enabledResult = enabled.future;
    await mount(tester);
    expect(gps.starts, 0);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
    enabled.complete(true); await flushHomeFixture(tester);
    expect(gps.starts, 1, reason: 'Historical characterization, NOT isolation acceptance');
    expect(gps.cancels, 0);
    // Close the synthetic stream ourselves; Home already disposed before attach.
    unawaited(gps.positions.close());
    await flushHomeFixture(tester); // Deliver done in the widget fake-async zone.
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('FCM requests undetermined permission then stops on refusal without token I/O', (tester) async {
    fcm.status = AuthorizationStatus.notDetermined;
    await mount(tester);
    expect(fcm.trace, ['permission', 'request:true:true:true']);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
  });

  testWidgets('authorized FCM with null or blank token never attaches listeners', (tester) async {
    fcm.status = AuthorizationStatus.authorized;
    await mount(tester);
    expect(fcm.trace, ['permission', 'token']);
    await tester.pumpWidget(const SizedBox());
    fcm.trace.clear(); fcm.token = '   '; gps.checks = 0;
    await mount(tester);
    expect(fcm.trace, ['permission', 'token']);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
  });

  testWidgets('FCM late getToken failure is caught after Home dispose without a retry', (tester) async {
    fcm.status = AuthorizationStatus.provisional;
    final token = Completer<String?>(); fcm.tokenResult = token.future;
    await mount(tester);
    expect(fcm.trace, ['permission', 'token']);
    await tester.pumpWidget(const SizedBox());
    token.completeError(StateError('synthetic offline token'));
    await flushHomeFixture(tester);
    expect(fcm.trace, ['permission', 'token']);
    expect(sync.activeCount, 0); expect(tester.takeException(), isNull);
  });
}
