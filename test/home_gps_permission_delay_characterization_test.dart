import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'support/home_platform_sdk_fixture.dart';
import 'support/home_sync_fixture.dart';

class PermissionGateGps extends HomeGpsSdkFixture {
  final nativePermission = Completer<LocationPermission>();
  @override
  Future<LocationPermission> checkPermission() {
    trace.add('check');
    return ++checks == 1 ? Future<LocationPermission>.value(LocationPermission.denied) : nativePermission.future;
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native permission await cannot attach after dispose even when service check already succeeded', (tester) async {
    final originalFcm = FirebaseMessagingPlatform.instance;
    final originalGps = GeolocatorPlatform.instance;
    setupFirebaseCoreMocks(); await Firebase.initializeApp();
    final gps = PermissionGateGps(); final sync = HomeSyncFixture();
    FirebaseMessagingPlatform.instance = HomeFcmSdkFixture();
    GeolocatorPlatform.instance = gps;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(MaterialApp(home: PlatformSdkHomePage(sync: sync)));
      await flushHomeFixture(tester);
      expect(gps.trace, ['check', 'enabled', 'check']); expect(gps.starts, 0);
      await tester.pumpWidget(const SizedBox()); expect(sync.activeCount, 0);
      gps.nativePermission.complete(LocationPermission.whileInUse);
      await flushHomeFixture(tester);
      expect(gps.starts, 0); expect(gps.cancels, 0);
      expect(gps.lastSubscription, isNull);
      await gps.positions.close(); await sync.close(); expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FirebaseMessagingPlatform.instance = originalFcm;
      GeolocatorPlatform.instance = originalGps;
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
