import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';
import 'support/security_home_fixture.dart' as secured;
import 'support/home_platform_sdk_fixture.dart';

class _Permission extends Fake implements NotificationSettings {
  final AuthorizationStatus status;
  _Permission(this.status);
  @override AuthorizationStatus get authorizationStatus => status;
}
class _EpochPush extends Fake implements FirebaseMessaging {
  final String stage;
  final gate = Completer<void>();
  int tokens = 0, starts = 0, cancels = 0;
  late final refresh = StreamController<String>.broadcast(
    onListen: () { starts++; }, onCancel: () { cancels++; });
  _EpochPush(this.stage);
  @override Future<NotificationSettings> getNotificationSettings() async {
    if (stage == 'permission') await gate.future;
    return _Permission(stage == 'request' ? AuthorizationStatus.notDetermined : AuthorizationStatus.authorized);
  }
  @override Future<NotificationSettings> requestPermission({bool alert = true,
    bool announcement = false, bool badge = true, bool carPlay = false,
    bool criticalAlert = false, bool provisional = false, bool sound = true,
    bool providesAppNotificationSettings = false}) async {
    await gate.future; return _Permission(AuthorizationStatus.authorized);
  }
  @override Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) async {
    tokens++; if (stage == 'token') await gate.future; return 'synthetic_${stage}_token';
  }
  @override Stream<String> get onTokenRefresh => refresh.stream;
  @override Future<RemoteMessage?> getInitialMessage() async => null;
}

class _EpochGps extends HomeGpsSdkFixture {
  final String stage;
  final gate = Completer<void>();
  _EpochGps(this.stage);
  @override Future<bool> isLocationServiceEnabled() async {
    if (stage == 'service') await gate.future;
    return true;
  }
  @override Future<LocationPermission> checkPermission() async {
    if (++checks == 1) return LocationPermission.denied; // No live location I/O.
    if (stage == 'permission') await gate.future;
    return stage == 'request' ? LocationPermission.denied : LocationPermission.whileInUse;
  }
  @override Future<LocationPermission> requestPermission() async {
    await gate.future; return LocationPermission.whileInUse;
  }
}

int _count(String area, String code) => VisionErrorTelemetry.log.entries
  .where((e) => e.area == area && e.code == code).fold(0, (n, e) => n + e.count);

void main() {
  for (final stage in ['permission', 'request', 'token']) {
    testWidgets('FCM old A $stage cannot revive after A B A while B refresh works', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final auth = SessionAuth(); final db = SessionFirestore(); final home = secured.HomeSyncFixture();
      final a = _EpochPush(stage), b = _EpochPush('active');
      addTearDown(auth.events.close); addTearDown(db.close); addTearDown(home.close);
      addTearDown(a.refresh.close); addTearDown(b.refresh.close);
      bool Function()? originalOwner;
      await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) {
        final returning = profile.uid == 'a' && originalOwner != null && !originalOwner!();
        if (profile.uid == 'a' && originalOwner == null) originalOwner = current;
        return secured.FixtureHomePage(key: key, profile: profile, fixture: home,
          sessionIsCurrent: current, messaging: profile.uid == 'b' ? b : a, realPush: !returning);
      });
      db.profile('a'); await harness.flush(tester); expect(home.writes, isEmpty);
      auth.switchTo('b'); await harness.flush(tester); db.profile('b'); await harness.flush(tester);
      expect(home.writes.single['path'], startsWith('users/b/pushTokens/'));
      final before = _count('fcm', 'token_refresh_failed');
      b.refresh.addError(StateError('PRIVATE B token')); await harness.flush(tester);
      expect(_count('fcm', 'token_refresh_failed'), before + 1);
      b.refresh.add('synthetic_B_refresh'); await harness.flush(tester); expect(home.writes, hasLength(2));
      auth.switchTo('a'); await harness.flush(tester); db.profile('a'); await harness.flush(tester);
      a.gate.complete(); await harness.flush(tester);
      expect(originalOwner!(), isFalse); expect(a.starts, 0);
      expect(home.writes.every((w) => (w['path'] as String).startsWith('users/b/')), isTrue);
      expect(b.starts, 1); expect(b.cancels, 1);
      expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
      await tester.pumpWidget(const SizedBox()); expect(home.activeCount, 0); expect(tester.takeException(), isNull);
    });
  }

  for (final stage in ['service', 'permission', 'request']) {
    testWidgets('GPS A delayed $stage cannot attach while B native stream works', (tester) async {
      final previous = GeolocatorPlatform.instance;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() { GeolocatorPlatform.instance = previous; debugDefaultTargetPlatformOverride = null; });
      final a = _EpochGps(stage), b = HomeGpsSdkFixture();
      GeolocatorPlatform.instance = a;
      final auth = SessionAuth(); final db = SessionFirestore(); final home = secured.HomeSyncFixture();
      addTearDown(auth.events.close); addTearDown(db.close); addTearDown(home.close);
      addTearDown(a.positions.close); addTearDown(b.positions.close);
      await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) =>
        secured.FixtureHomePage(key: key, profile: profile, fixture: home,
          sessionIsCurrent: current, realLocation: true));
      db.profile('a'); await harness.flush(tester); expect(a.starts, 0);
      GeolocatorPlatform.instance = b;
      auth.switchTo('b'); await harness.flush(tester); db.profile('b'); await harness.flush(tester);
      expect(b.starts, 1);
      final before = _count('gps', 'background_stream_failed');
      b.positions.addError(StateError('PRIVATE GPS coordinates')); await harness.flush(tester);
      expect(_count('gps', 'background_stream_failed'), before + 1);
      a.gate.complete(); await harness.flush(tester); expect(a.starts, 0); expect(a.lastSubscription, isNull);
      expect(home.writes, isEmpty); expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
      await tester.pumpWidget(const SizedBox()); expect(b.cancels, 1); expect(home.activeCount, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
