import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';
import 'support/security_home_fixture.dart';

class _AllowedPush extends Fake implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;
}
class _ActivePush extends Fake implements FirebaseMessaging {
  final token = Completer<String?>();
  int starts = 0, cancels = 0;
  late final refresh = StreamController<String>.broadcast(
    onListen: () { starts++; }, onCancel: () { cancels++; });
  @override
  Future<NotificationSettings> getNotificationSettings() async => _AllowedPush();
  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) => token.future;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}
class _ActiveLocation extends GeolocatorPlatform {
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
  testWidgets('acceptance: changed SDK UID plus auth stream error cannot retain A route', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) => Builder(key: key,
      builder: (context) => Scaffold(body: FilledButton(child: Text('Identity ${profile.uid}'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: Text('Auth error private ${profile.uid}'))))))));
    db.profile('a'); await harness.flush(tester);
    await tester.tap(find.text('Identity a')); await tester.pumpAndSettle();
    auth.user = SessionUser('b');
    auth.events.addError('synthetic auth stream error'); await harness.flush(tester);
    expect(find.text('Auth error private a'), findsNothing);
    db.profile('b'); await harness.flush(tester);
    expect(find.text('Identity b'), findsOneWidget);
    expect(db.requests.where((p) => p == 'users/b').length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('same SDK UID auth stream error keeps the legitimate profile fallback', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) => Text('Valid ${profile.uid}'));
    db.profile('a'); await harness.flush(tester);
    auth.events.addError('same UID offline'); await harness.flush(tester);
    expect(find.text('Valid a'), findsOneWidget);
    expect(db.requests.where((p) => p == 'users/a').length, 1);
    expect(db.cancels['users/a'], isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acceptance: private root SnackBar cannot transfer from A to B loading or Home', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) => Builder(key: key,
      builder: (context) => Scaffold(body: FilledButton(child: Text('Show private message ${profile.uid}'),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(minutes: 1), content: Text('Private snackbar ${profile.uid}')))))));
    db.profile('a'); await harness.flush(tester);
    await tester.tap(find.text('Show private message a')); await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Private snackbar a'), findsOneWidget);
    auth.switchTo('b'); await harness.flush(tester);
    expect(find.text('Private snackbar a'), findsNothing);
    db.profile('b'); await harness.flush(tester);
    expect(find.text('Private snackbar a'), findsNothing);
    expect(find.text('Show private message b'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('same UID keeps personal preferences; B resets only personal fields and preserves global settings', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore(); final homeDb = HomeSyncFixture();
    addTearDown(auth.events.close); addTearDown(db.close); addTearDown(homeDb.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false..defaultPerDiem = 73..backgroundOpacity = .51;
    settings.smsTemplates['initial'] = 'Global template';
    settings.customBackgrounds['shared'] = {'name': 'Shared', 'imageBase64': 'synthetic'};
    await harness.mount(tester, auth, db, settings: settings, homeBuilder: (key, profile, current) =>
      FixtureHomePage(key: key, profile: profile, fixture: homeDb, settings: settings, sessionIsCurrent: current));
    db.profile('a'); await harness.flush(tester);
    homeDb.document('users/a').add(SessionSnapshot({'theme': 'dark', 'fontFamily': 'Georgia'}));
    await harness.flush(tester);
    auth.events.add(null); auth.events.add(SessionUser('a'));
    db.controller('users/a').addError('same UID reconnect'); await harness.flush(tester);
    expect(settings.theme, AppThemeChoice.dark); expect(settings.fontFamily, 'Serif');
    auth.switchTo('b'); await harness.flush(tester);
    expect(settings.theme, AppThemeChoice.light); expect(settings.fontFamily, 'System');
    expect(settings.personalBackgroundId, 'global');
    expect(settings.defaultPerDiem, 73); expect(settings.backgroundOpacity, .51);
    expect(settings.smsTemplates['initial'], 'Global template');
    expect(settings.customBackgrounds['shared']!['name'], 'Shared');
    await tester.pumpWidget(const SizedBox()); expect(homeDb.activeCount, 0);
  });

  testWidgets('real member Home keeps own team financial scope and B starts with no A ledger', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore(); final homeDb = HomeSyncFixture();
    addTearDown(auth.events.close); addTearDown(db.close); addTearDown(homeDb.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false;
    await harness.mount(tester, auth, db, settings: settings, homeBuilder: (key, profile, current) =>
      FixtureHomePage(key: key, profile: profile, fixture: homeDb, settings: settings, sessionIsCurrent: current));
    db.profile('a'); await harness.flush(tester);
    homeDb.emit('teams', 'ta', {'name': 'A team', 'members': ['a']}); await harness.flush(tester);
    homeDb.emit('expenses[where:teamId=ta]', 'private-a-expense', {'teamId': 'ta', 'amount': 50});
    await harness.flush(tester);
    final dynamic a = tester.state(find.byType(FixtureHomePage));
    expect(a.me.teamId, 'ta'); expect(a.canEditTeam('ta'), isTrue);
    expect(a.canEditTeam('foreign'), isFalse);
    expect(a.expenses.single.id, 'private-a-expense'); expect(homeDb.activeCount, 18);
    auth.switchTo('b'); await harness.flush(tester);
    expect(a.mounted, isFalse); expect(homeDb.activeCount, 0);
    db.profile('b'); await harness.flush(tester);
    final dynamic b = tester.state(find.byType(FixtureHomePage));
    expect(b.expenses, isEmpty); expect(b.me.teamId, isNull);
    homeDb.emit('teams', 'tb', {'name': 'B team', 'members': ['b']}); await harness.flush(tester);
    homeDb.emit('expenses[where:teamId=ta]', 'late-a', {'teamId': 'ta', 'amount': 999});
    homeDb.emit('expenses[where:teamId=tb]', 'own-b', {'teamId': 'tb', 'amount': 75});
    await harness.flush(tester);
    expect(b.me.teamId, 'tb'); expect(b.expenses.single.id, 'own-b');
    expect(homeDb.active['expenses[where:teamId=ta]'], 0);
    expect(homeDb.active['expenses[where:teamId=tb]'], 1);
    await tester.pumpWidget(const SizedBox()); expect(homeDb.activeCount, 0);
  });

  testWidgets('session guard becomes false before the old Home is disposed and rejects queued own-profile mutation', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore(); final homeDb = HomeSyncFixture();
    addTearDown(auth.events.close); addTearDown(db.close); addTearDown(homeDb.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false;
    await harness.mount(tester, auth, db, settings: settings, homeBuilder: (key, profile, current) =>
      FixtureHomePage(key: key, profile: profile, fixture: homeDb, settings: settings, sessionIsCurrent: current));
    db.profile('a'); await harness.flush(tester);
    final dynamic old = tester.state(find.byType(FixtureHomePage));
    auth.switchTo('b'); await tester.idle();
    expect(old.mounted, isTrue); // The replacing frame has not run yet.
    expect(old.widget.sessionIsCurrent(), isFalse);
    homeDb.document('users/a').add(SessionSnapshot({'theme': 'dark', 'fontFamily': 'Georgia'}));
    await tester.idle();
    expect(settings.theme, AppThemeChoice.light); expect(settings.fontFamily, 'System');
    await harness.flush(tester); expect(old.mounted, isFalse);
    await tester.pumpWidget(const SizedBox()); expect(homeDb.activeCount, 0);
  });

  testWidgets('active FCM initialization writes its owner token and refresh; dispose cancels refresh', (tester) async {
    final db = HomeSyncFixture(); final push = _ActivePush();
    addTearDown(db.close); addTearDown(push.refresh.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(key: const ValueKey('a'),
      profile: fixtureHomeProfile('a'), fixture: db, messaging: push, realPush: true, sessionIsCurrent: () => true)));
    push.token.complete('synthetic-token-one'); await harness.flush(tester);
    expect(db.writes.length, 1); expect(push.starts, 1);
    expect(db.writes.single['path'], startsWith('users/a/pushTokens/'));
    expect((db.writes.single['data'] as Map)['deviceOwnerUid'], 'a');
    push.refresh.add('synthetic-token-two'); await harness.flush(tester);
    expect(db.writes.length, 2);
    expect(db.writes.every((w) => (w['data'] as Map)['deviceOwnerUid'] == 'a'), isTrue);
    await tester.pumpWidget(const SizedBox()); expect(push.cancels, 1);
    push.refresh.add('late-after-dispose'); await harness.flush(tester);
    expect(db.writes.length, 2); expect(db.activeCount, 0);
  });

  testWidgets('active native GPS startup attaches normally and dispose cancels its subscription', (tester) async {
    final previous = GeolocatorPlatform.instance; final location = _ActiveLocation();
    GeolocatorPlatform.instance = location;
    addTearDown(() { GeolocatorPlatform.instance = previous; }); addTearDown(location.positions.close);
    final db = HomeSyncFixture(); addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(key: const ValueKey('a'),
      profile: fixtureHomeProfile('a'), fixture: db, realLocation: true, sessionIsCurrent: () => true)));
    location.enabled.complete(true); await harness.flush(tester);
    expect(location.starts, 1); expect(location.cancels, 0);
    await tester.pumpWidget(const SizedBox()); expect(location.cancels, 1);
    expect(db.writes, isEmpty); expect(db.activeCount, 0);
  });

  testWidgets('system Back pops a private route normally within the same session', (tester) async {
    final auth = SessionAuth(); final db = SessionFirestore();
    addTearDown(auth.events.close); addTearDown(db.close);
    await harness.mount(tester, auth, db, homeBuilder: (key, profile, current) => Builder(key: key,
      builder: (context) => Scaffold(body: FilledButton(child: Text('Home ${profile.uid}'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private route'))))))));
    db.profile('a'); await harness.flush(tester);
    await tester.tap(find.text('Home a')); await tester.pumpAndSettle();
    expect(find.text('Private route'), findsOneWidget);
    await tester.binding.handlePopRoute(); await tester.pumpAndSettle();
    expect(find.text('Private route'), findsNothing); expect(find.text('Home a'), findsOneWidget);
    expect(db.requests.where((p) => p == 'users/a').length, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
