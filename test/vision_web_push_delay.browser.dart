// Browser-only entrypoint, invoked explicitly in the compile-only CI workflow.
// It must not enter the default VM discovery of *_test.dart.
import 'dart:async';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';
import 'support/security_home_fixture.dart' as secured;

class _Permission extends Fake implements NotificationSettings {
  @override AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;
}
class _WebPush extends Fake implements FirebaseMessaging {
  int permissionCalls = 0, tokenCalls = 0, starts = 0, cancels = 0;
  final keys = <String?>[];
  late final refresh = StreamController<String>.broadcast(
    onListen: () { starts++; }, onCancel: () { cancels++; });
  @override Future<NotificationSettings> getNotificationSettings() async {
    permissionCalls++; return _Permission();
  }
  @override Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) async {
    tokenCalls++; keys.add(vapidKey); return 'synthetic_browser_token';
  }
  @override Stream<String> get onTokenRefresh => refresh.stream;
  @override Future<RemoteMessage?> getInitialMessage() async => null;
}
int refreshFailures() => VisionErrorTelemetry.log.entries.where((e) => e.area == 'fcm' &&
  e.code == 'token_refresh_failed').fold(0, (n, e) => n + e.count);

void main() {
  for (final returnBeforeDelay in [false, true]) {
    testWidgets('real browser FCM700 rejects A1, returnBeforeDelay=$returnBeforeDelay, B remains legitimate', (tester) async {
      expect(kIsWeb, isTrue, reason: 'This fixture must execute in Chrome, not with a platform label override.');
      final auth = SessionAuth(), db = SessionFirestore(); final home = secured.HomeSyncFixture();
      final a = _WebPush(), b = _WebPush();
      bool Function()? originalOwner;
      await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) {
        final returning = profile.uid == 'a' && originalOwner != null && !originalOwner!();
        if (profile.uid == 'a' && originalOwner == null) originalOwner = current;
        return secured.FixtureHomePage(key: key, profile: profile, fixture: home,
          sessionIsCurrent: current, messaging: profile.uid == 'a' ? a : b, realPush: !returning);
      });
      db.profile('a'); await harness.flush(tester); expect(a.permissionCalls, 1);
      await tester.pump(const Duration(milliseconds: 699));
      expect(a.tokenCalls, 0); expect(a.starts, 0); expect(home.writes, isEmpty);
      auth.switchTo('b'); await harness.flush(tester); db.profile('b'); await harness.flush(tester);
      expect(originalOwner!(), isFalse); expect(b.permissionCalls, 1);
      if (returnBeforeDelay) {
        auth.switchTo('a'); await harness.flush(tester); db.profile('a'); await harness.flush(tester);
      }
      await tester.pump(const Duration(milliseconds: 1)); await harness.flush(tester);
      expect(a.tokenCalls, 0); expect(a.starts, 0); expect(home.writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 698)); expect(b.tokenCalls, 0);
      await tester.pump(const Duration(milliseconds: 1)); await harness.flush(tester);
      if (returnBeforeDelay) {
        expect(b.tokenCalls, 0); expect(b.starts, 0); expect(home.writes, isEmpty);
        auth.switchTo('b'); await harness.flush(tester); db.profile('b'); await harness.flush(tester);
        await tester.pump(const Duration(milliseconds: 699)); expect(b.tokenCalls, 0);
        await tester.pump(const Duration(milliseconds: 1)); await harness.flush(tester);
      }
      expect(b.tokenCalls, 1); expect(b.starts, 1);
      expect(b.keys, ['synthetic-test-only-vapid']);
      expect(home.writes, hasLength(1));
      final data = home.writes.single['data'] as Map;
      expect(data['platform'], 'web'); expect(data['deviceOwnerUid'], 'b');
      expect(home.writes.single['path'], startsWith('users/b/pushTokens/'));
      b.refresh.add('synthetic_browser_refresh'); await harness.flush(tester);
      expect(home.writes, hasLength(2));
      final before = refreshFailures(); b.refresh.addError(StateError('PRIVATE WEB TOKEN'));
      await harness.flush(tester); expect(refreshFailures(), before + 1);
      expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE')));
      auth.switchTo('a'); await harness.flush(tester); db.profile('a'); await harness.flush(tester);
      expect(a.tokenCalls, 0); expect(a.starts, 0); expect(b.cancels, 1);
      expect(home.writes.every((w) => (w['path'] as String).startsWith('users/b/')), isTrue);
      await tester.pumpWidget(const SizedBox()); await tester.pump(const Duration(seconds: 1));
      expect(home.activeCount, 0); expect(tester.takeException(), isNull);
      await auth.events.close(); await db.close(); await home.close();
      await a.refresh.close(); await b.refresh.close();
    });
  }
}
