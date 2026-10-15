import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'support/security_gate_fixture.dart';
import 'support/security_home_fixture.dart';

Future<void> flush(WidgetTester t) async { await t.pump(); await t.pump(); }

Future<void> mount(WidgetTester tester, SessionAuth auth, SessionFirestore db,
    {AppSettings? settings, Widget Function(Key, FirebaseUserProfile, bool Function())? homeBuilder}) async {
  await tester.pumpWidget(AndiCarpetaApp(authSources: AuthGateSources(
      currentUser: () => auth.currentUser, authStateChanges: auth.authStateChanges,
      uiSettingsSnapshots: () => db.collection('meta').doc('uiSettings').snapshots(),
      profileSnapshots: (uid) => db.collection('users').doc(uid).snapshots(includeMetadataChanges: true)),
    settings: settings ?? (AppSettings()..brandingBackgroundId = 'none'),
    homeBuilder: homeBuilder));
  await flush(tester);
}

class _PrivatePage extends StatefulWidget {
  final FirebaseUserProfile profile;
  const _PrivatePage({super.key, required this.profile});
  @override
  State<_PrivatePage> createState() => _PrivatePageState();
}
class _PrivatePageState extends State<_PrivatePage> {
  @override
  Widget build(BuildContext context) => Scaffold(body: Column(children: [
    Text('private:${widget.profile.uid}:${widget.profile.name}'),
    FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Text('route:${widget.profile.uid}')))), child: const Text('Open private route')),
    FilledButton(onPressed: () => showDialog<void>(context: context, builder: (_) =>
      AlertDialog(content: Text('dialog:${widget.profile.uid}'))), child: const Text('Open private dialog')),
  ]));
}

class _Permission extends Fake implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;
}
class _Push extends Fake implements FirebaseMessaging {
  final token = Completer<String?>();
  late final refresh = StreamController<String>.broadcast(
    onListen: () { starts++; }, onCancel: () { cancels++; });
  int starts = 0, cancels = 0;
  @override
  Future<NotificationSettings> getNotificationSettings() async => _Permission();
  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) => token.future;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}
class _Location extends GeolocatorPlatform {
  final enabled = Completer<bool>();
  int checks = 0, starts = 0, cancels = 0;
  late final positions = StreamController<Position>.broadcast(
    onListen: () { starts++; }, onCancel: () { cancels++; });
  @override
  Future<bool> isLocationServiceEnabled() => enabled.future;
  @override
  Future<LocationPermission> checkPermission() async => ++checks == 1
      ? LocationPermission.denied : LocationPermission.whileInUse;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) => positions.stream;
}

void main() {
  testWidgets('acceptance: A pending profile disappears immediately on B before its snapshot', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await mount(tester, auth, db);
    db.profile('a', active: false, name: 'Private Alice'); await flush(tester);
    expect(find.textContaining('Private Alice'), findsWidgets);
    auth.switchTo('b'); await flush(tester);
    expect(find.textContaining('Private Alice'), findsNothing);
    expect(find.text('Se încarcă profilul...'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acceptance: B profile error plus global settings cannot reveal A', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await mount(tester, auth, db);
    db.profile('a', active: false, name: 'Private Alice'); await flush(tester);
    auth.switchTo('b'); await flush(tester);
    db.controller('users/b').addError('synthetic B offline');
    db.controller('meta/uiSettings').add(SessionSnapshot({'brandingLogoId': 'standard', 'backgroundOpacity': .6}));
    await flush(tester);
    expect(find.textContaining('Private Alice'), findsNothing);
    expect(find.textContaining('synthetic B offline'), findsOneWidget);
    db.controller('users/b').add(SessionSnapshot(null, exists: false)); await flush(tester);
    expect(find.textContaining('a@example.test'), findsNothing);
    expect(find.textContaining('b@example.test'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acceptance: real Home A and all its listeners are disposed before profile B', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore(); final homeDb = HomeSyncFixture();
    addTearDown(auth.events.close); addTearDown(db.close); addTearDown(homeDb.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false;
    await mount(tester, auth, db, settings: settings, homeBuilder: (key, profile, current) =>
      FixtureHomePage(key: key, profile: profile, fixture: homeDb, settings: settings, sessionIsCurrent: current));
    db.profile('a'); await flush(tester);
    final dynamic old = tester.state(find.byType(FixtureHomePage));
    old.tab = 3;
    homeDb.emit('memberDirectory', 'a', {'name': 'Cached Private Alice', 'active': true});
    homeDb.document('users/a').add(SessionSnapshot({'theme': 'dark', 'fontFamily': 'Georgia'}));
    await flush(tester);
    expect(homeDb.activeCount, 14);
    auth.switchTo('b'); await flush(tester);
    expect(old.mounted, isFalse);
    expect(homeDb.activeCount, 0);
    expect(find.byType(FixtureHomePage), findsNothing);
    homeDb.document('users/a').add(SessionSnapshot({'theme': 'dark'})); await flush(tester);
    expect(settings.theme, AppThemeChoice.light);
    expect(settings.fontFamily, 'System');
    db.profile('b'); await flush(tester);
    final dynamic next = tester.state(find.byType(FixtureHomePage));
    expect(next.currentUserId, 'b'); expect(next.tab, 0);
    expect(next.me.name, 'Private b');
    expect(homeDb.active['users/a'], 0); expect(homeDb.active['users/b'], 1);
    await tester.pumpWidget(const SizedBox()); expect(homeDb.activeCount, 0);
  });

  testWidgets('acceptance: private route A disappears on B and cannot survive B profile', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await mount(tester, auth, db, homeBuilder: (key, profile, current) => _PrivatePage(key: key, profile: profile));
    db.profile('a'); await flush(tester);
    await tester.tap(find.text('Open private route')); await tester.pumpAndSettle();
    expect(find.text('route:a'), findsOneWidget);
    auth.switchTo('b'); await flush(tester);
    expect(find.text('route:a'), findsNothing);
    db.profile('b'); await flush(tester);
    expect(find.text('private:b:Private b'), findsOneWidget);
    expect(find.text('route:a'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acceptance: default root dialog from A is removed at UID B', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await mount(tester, auth, db, homeBuilder: (key, profile, current) => _PrivatePage(key: key, profile: profile));
    db.profile('a'); await flush(tester);
    await tester.tap(find.text('Open private dialog')); await tester.pumpAndSettle();
    expect(find.text('dialog:a'), findsOneWidget);
    auth.switchTo('b'); await flush(tester);
    expect(find.text('dialog:a'), findsNothing);
    db.profile('b'); await flush(tester);
    expect(find.text('private:b:Private b'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acceptance: logout removes private route and login cannot revive it', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await mount(tester, auth, db, homeBuilder: (key, profile, current) => _PrivatePage(key: key, profile: profile));
    db.profile('a'); await flush(tester);
    await tester.tap(find.text('Open private route')); await tester.pumpAndSettle();
    auth.switchTo(null); await flush(tester);
    expect(find.text('route:a'), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    auth.switchTo('b'); await flush(tester); db.profile('b'); await flush(tester);
    expect(find.text('route:a'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acceptance: rapid A B A rejects callbacks from the first A epoch', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await mount(tester, auth, db, homeBuilder: (key, profile, current) => _PrivatePage(key: key, profile: profile));
    db.profile('a'); await flush(tester);
    auth.switchTo('b'); await flush(tester);
    auth.switchTo('a'); await flush(tester);
    db.lateProfile('a', 0, 'Stale private Alice'); await flush(tester);
    expect(find.textContaining('Stale private Alice'), findsNothing);
    expect(find.text('Se încarcă profilul...'), findsOneWidget);
    db.profile('a', name: 'Fresh Alice'); await flush(tester);
    expect(find.text('private:a:Fresh Alice'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acceptance: queued personal post-frame callback cannot run after session owner disposal', (tester) async {
    final db = HomeSyncFixture(); addTearDown(db.close);
    var callbacks = 0;
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(key: const ValueKey('a'),
      profile: fixtureHomeProfile('a'), fixture: db, onSettingsChanged: () { callbacks++; })));
    db.document('users/a').add(SessionSnapshot({'theme': 'dark'})); await tester.idle();
    expect(callbacks, 0);
    await tester.pumpWidget(const SizedBox());
    expect(callbacks, 0);
    expect(db.activeCount, 0);
  });

  testWidgets('acceptance: delayed real FCM initialization cannot write or attach after dispose', (tester) async {
    final db = HomeSyncFixture(); final push = _Push();
    addTearDown(db.close); addTearDown(push.refresh.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(key: const ValueKey('a'),
      profile: fixtureHomeProfile('a'), fixture: db, messaging: push, realPush: true)));
    await tester.idle();
    await tester.pumpWidget(const SizedBox());
    push.token.complete('synthetic-not-real-token'); await flush(tester);
    expect(db.writes, isEmpty);
    expect(push.starts, 0);
    expect(db.activeCount, 0);
  });

  testWidgets('acceptance: delayed native GPS startup cannot create a subscription after dispose', (tester) async {
    final previous = GeolocatorPlatform.instance;
    final location = _Location(); GeolocatorPlatform.instance = location;
    addTearDown(() { GeolocatorPlatform.instance = previous; });
    addTearDown(location.positions.close);
    final db = HomeSyncFixture(); addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(key: const ValueKey('a'),
      profile: fixtureHomeProfile('a'), fixture: db, realLocation: true)));
    await tester.idle(); await tester.pumpWidget(const SizedBox());
    location.enabled.complete(true); await flush(tester);
    expect(location.starts, 0);
    expect(db.writes, isEmpty);
  });

  testWidgets('regression: same UID null/reconnect/error preserves profile and private route', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await mount(tester, auth, db, homeBuilder: (key, profile, current) => _PrivatePage(key: key, profile: profile));
    db.profile('a'); await flush(tester);
    await tester.tap(find.text('Open private route')); await tester.pumpAndSettle();
    auth.events.add(null); auth.events.add(SessionUser('a'));
    db.controller('users/a').addError('same user disconnected'); await flush(tester);
    expect(find.text('route:a'), findsOneWidget);
    expect(db.requests.where((p) => p == 'users/a').length, 1);
    expect(db.cancels['users/a'], isNull);
    Navigator.of(tester.element(find.text('route:a'))).pop(); await tester.pumpAndSettle();
    expect(find.text('private:a:Private a'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
