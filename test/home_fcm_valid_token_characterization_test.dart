import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'support/auth_gate_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalFcm = FirebaseMessagingPlatform.instance;
  final originalGps = GeolocatorPlatform.instance;
  final fcm = ValidTokenFcmFixture();
  late HomeSyncFixture sync;
  late PushFirestoreFixture db;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseMessagingPlatform.instance = fcm;
  });
  tearDownAll(() async {
    await fcm.refresh.close();
    FirebaseMessagingPlatform.instance = originalFcm;
    GeolocatorPlatform.instance = originalGps;
  });
  setUp(() {
    fcm.reset(); fcm.status = AuthorizationStatus.authorized;
    fcm.token = 'synthetic-only-token'; fcm.initialResult = null;
    fcm.refreshStarts = 0; fcm.refreshCancels = 0;
    sync = HomeSyncFixture(); db = PushFirestoreFixture();
    GeolocatorPlatform.instance = HomeGpsSdkFixture()..enabled = false;
  });
  tearDown(() async { await sync.close(); });
  Future<void> mount(WidgetTester tester, {String uid = 'a'}) async {
    await tester.pumpWidget(MaterialApp(home: PushSdkHomePage(uid: uid, sync: sync, push: db)));
    await flushHomeFixture(tester);
  }
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await flushHomeFixture(tester);
    expect(db.unexpected, isEmpty);
    expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  }
  String tokenId(String value) => base64UrlEncode(utf8.encode(value)).replaceAll('=', '');

  testWidgets('valid token saves exact owner and merge payload, refresh writes once and cancels on dispose', (tester) async {
    await mount(tester);
    expect(fcm.trace, ['permission', 'token', 'refresh', 'initial']);
    expect(db.writes.length, 1);
    final first = db.writes.single;
    expect(first.path, 'users/a/pushTokens/${tokenId(fcm.token!)}');
    expect(first.merge, isTrue);
    expect(first.data.keys.toSet(), {'token', 'platform', 'deviceOwnerUid', 'active', 'lastSeenAt', 'updatedAt'});
    expect(first.data['token'], fcm.token);
    expect(first.data['deviceOwnerUid'], 'a'); expect(first.data['active'], isTrue);
    expect(first.data['lastSeenAt'], isA<FieldValue>());
    expect(first.data['updatedAt'], isA<FieldValue>());
    expect(fcm.refreshStarts, 1);
    fcm.refresh.add('synthetic-refresh');
    await flushHomeFixture(tester);
    expect(db.writes.length, 2);
    expect(db.writes.last.path, 'users/a/pushTokens/${tokenId('synthetic-refresh')}');
    expect(db.writes.last.data['deviceOwnerUid'], 'a');
    await finish(tester);
    expect(fcm.refreshCancels, 1);
    fcm.refresh.add('synthetic-after-dispose');
    FirebaseMessagingPlatform.onMessageOpenedApp.add(const RemoteMessage(data: {'type': 'chat', 'senderId': 'later'}));
    await flushHomeFixture(tester);
    expect(db.writes.length, 2); expect(db.reads, isEmpty);
  });

  testWidgets('listeners and initial read await successful token write; refresh stream error causes no retry', (tester) async {
    final gate = Completer<void>(); db.beforeSet = (_) => gate.future;
    await mount(tester);
    expect(db.attempts.length, 1); expect(db.writes, isEmpty);
    expect(fcm.trace, ['permission', 'token']); expect(fcm.refreshStarts, 0);
    gate.complete(); await flushHomeFixture(tester);
    expect(db.writes.length, 1); expect(fcm.refreshStarts, 1);
    expect(fcm.trace.last, 'initial');
    fcm.refresh.addError(StateError('synthetic refresh failure'));
    await flushHomeFixture(tester);
    expect(db.attempts.length, 1); expect(fcm.refreshStarts, 1);
    await finish(tester); expect(fcm.refreshCancels, 1);
  });

  testWidgets('token-write rejection is caught without attach, initial read or retry', (tester) async {
    db.beforeSet = (_) async { throw StateError('synthetic rejected write'); };
    await mount(tester);
    expect(db.attempts.length, 1); expect(db.writes, isEmpty);
    expect(fcm.trace, ['permission', 'token']); expect(fcm.refreshStarts, 0);
    await finish(tester);
  });

  testWidgets('delayed initial chat after dispose schedules callback but guard prevents directory read/navigation', (tester) async {
    final initial = Completer<RemoteMessage?>(); fcm.initialResult = initial.future;
    await mount(tester); expect(fcm.trace.last, 'initial');
    await finish(tester); expect(fcm.refreshCancels, 1);
    initial.complete(const RemoteMessage(data: {'type': 'chat', 'senderId': 'sender'}));
    await flushHomeFixture(tester); await flushHomeFixture(tester);
    expect(db.reads, isEmpty); expect(db.writes.length, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opened chat performs memberDirectory read and ignores result after dispose', (tester) async {
    final read = Completer<DocumentSnapshot<Map<String, dynamic>>>();
    db.scriptedReads['memberDirectory/sender'] = () => read.future;
    await mount(tester);
    FirebaseMessagingPlatform.onMessageOpenedApp.add(const RemoteMessage(data: {'type': 'chat', 'senderId': 'sender'}));
    await flushHomeFixture(tester);
    expect(db.reads, ['memberDirectory/sender']);
    expect(db.writes.length, 1);
    await finish(tester);
    read.complete(GateFixtureSnapshot({'name': 'Synthetic Sender'}));
    await flushHomeFixture(tester);
    expect(find.text('Synthetic Sender'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KNOWN DEFECT: delayed A token still attempts A write after keyed Home replaced by B', (tester) async {
    final tokenA = Completer<String?>(); fcm.tokenResult = tokenA.future;
    db.beforeSet = (write) async {
      if (write.data['deviceOwnerUid'] == 'a') throw StateError('synthetic reject stale A');
    };
    await mount(tester);
    expect(db.attempts, isEmpty);
    fcm.tokenResult = null; fcm.token = 'synthetic-B';
    await mount(tester, uid: 'b');
    expect(db.writes.single.data['deviceOwnerUid'], 'b');
    tokenA.complete('synthetic-delayed-A');
    await flushHomeFixture(tester);
    expect(db.attempts.map((w) => w.data['deviceOwnerUid']), ['b', 'a']);
    expect(db.attempts.last.path, 'users/a/pushTokens/${tokenId('synthetic-delayed-A')}');
    expect(db.writes.length, 1); expect(fcm.refreshStarts, 1);
    await finish(tester); expect(fcm.refreshCancels, 1);
    // Rejected fake write avoids leaked late listeners. This is not a full
    // AuthGate A->B, backend authorization or successful late-attach test.
  });
  testWidgets('KNOWN DEFECT: refresh write rejection escapes unawaited callback; only a new event retries', (tester) async {
    final errors = <Object>[];
    await runZonedGuarded<Future<void>>(() async {
      await mount(tester);
      db.beforeSet = (_) async { throw StateError('synthetic refresh write rejection'); };
      fcm.refresh.add('synthetic-rejected-refresh');
      await flushHomeFixture(tester);
    }, (error, stack) { errors.add(error); });
    expect(errors, hasLength(1)); expect(errors.single, isA<StateError>());
    expect(errors.single.toString(), contains('synthetic refresh write rejection'));
    expect(db.attempts, hasLength(2)); expect(db.writes, hasLength(1));
    await flushHomeFixture(tester); expect(db.attempts, hasLength(2));
    db.beforeSet = null; fcm.refresh.add('synthetic-new-refresh');
    await flushHomeFixture(tester);
    expect(db.attempts, hasLength(3)); expect(db.writes, hasLength(2));
    expect(db.writes.last.data['deviceOwnerUid'], 'a');
    expect(fcm.trace.where((e) => e == 'refresh'), hasLength(1));
    await finish(tester); expect(fcm.refreshCancels, 1);
  });

}
