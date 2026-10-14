import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';
import 'support/home_sync_fixture.dart';

void main() {
  testWidgets('KNOWN DEFECT: shared root settings retain A visual preferences until B supplies replacements', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final shared = AppSettings()..autoCloseWhenAllDone = false;
    Future<void> mount(String uid) => tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: ValueKey(uid), profile: fixtureHomeProfile(uid), fixture: db, settings: shared)));
    await mount('a');
    db.document('users/a').add(GateFixtureSnapshot({'theme': 'dark', 'fontFamily': 'Roboto'}));
    db.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 87, 'brandingLogoId': 'shared-logo'}));
    await flushHomeFixture(tester);
    await mount('b');
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    expect(state.currentUserId, 'b');
    expect(identical(state.settings, shared), isTrue);
    expect(shared.theme, AppThemeChoice.dark);
    expect(shared.fontFamily, 'Roboto');
    expect(shared.defaultPerDiem, 87);
    db.document('users/b').add(GateFixtureSnapshot(null));
    db.document('users/b').addError('B unavailable');
    await flushHomeFixture(tester);
    expect(shared.theme, AppThemeChoice.dark);
    expect(state.coreSyncError, 'Profil propriu: B unavailable');
    // Missing fields fall back to the already shared object, not fresh defaults.
    db.document('users/b').add(GateFixtureSnapshot({'locationMode': 'offline'}));
    db.document('users/a').add(GateFixtureSnapshot({'theme': 'light'}));
    await flushHomeFixture(tester);
    expect(shared.theme, AppThemeChoice.dark);
    expect(shared.fontFamily, 'Roboto');
    db.document('users/b').add(GateFixtureSnapshot({'theme': 'light', 'fontFamily': 'System'}));
    await flushHomeFixture(tester);
    expect(shared.theme, AppThemeChoice.light);
    expect(shared.fontFamily, 'System');
    expect(db.active['users/a'], 0);
    expect(db.active['users/b'], 1);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
  });

  testWidgets('global settings preserve partial/null/error/reconnect semantics and clamps for a member', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false;
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db, settings: settings)));
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    final starts = Map<String, int>.from(db.starts);
    final routingMode = settings.learning['routing']!.mode;
    db.document('meta/uiSettings').add(GateFixtureSnapshot({
      'backgroundOpacity': 9, 'defaultPerDiem': 91, 'allowUndo': false,
      'backupRetentionDays': -4, 'notificationHistoryDays': 999,
      'smsPreviousDayTime': '23:59', 'smsTemplates': {'initial': '  Synthetic  ', 'other': 'ignored'},
      'learning': {'duration': {'enabled': false, 'mode': 'automatic'},
        'routing': {'mode': 'unknown'}, 'unknown': {'enabled': false}},
    }));
    await flushHomeFixture(tester);
    expect(settings.backgroundOpacity, .70);
    expect(settings.defaultPerDiem, 91);
    expect(settings.allowUndo, isFalse);
    expect(settings.backupRetentionDays, 1);
    expect(settings.notificationHistoryDays, 365);
    expect(settings.smsPreviousDayTime, '23:59');
    expect(settings.smsTemplates['initial'], 'Synthetic');
    expect(settings.smsTemplates.containsKey('other'), isFalse);
    expect(settings.learning['duration']!.enabled, isFalse);
    expect(settings.learning['duration']!.mode, LearningMode.automatic);
    expect(settings.learning['routing']!.mode, routingMode);
    expect(settings.learning.containsKey('unknown'), isFalse);
    db.document('meta/uiSettings').add(GateFixtureSnapshot(null));
    db.document('meta/uiSettings').addError('global disconnected');
    await flushHomeFixture(tester);
    expect(state.coreSyncError, isNull); // Existing member error policy.
    expect(settings.defaultPerDiem, 91);
    db.document('meta/uiSettings').add(GateFixtureSnapshot({
      'backgroundOpacity': -1, 'smsPreviousDayTime': '24:00',
      'smsTemplates': {'initial': '  '}, 'allowUndo': 'invalid',
    }));
    await flushHomeFixture(tester);
    expect(settings.backgroundOpacity, 0);
    expect(settings.smsPreviousDayTime, '23:59');
    expect(settings.smsTemplates['initial'], 'Synthetic');
    expect(settings.allowUndo, isFalse);
    expect(settings.defaultPerDiem, 91);
    expect(db.starts, starts);
    await tester.pumpWidget(const SizedBox());
    db.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 999}));
    await flushHomeFixture(tester);
    expect(settings.defaultPerDiem, 91);
    expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KNOWN DEFECT: queued background settings callback runs after Home dispose', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    dynamic state;
    final mountedAtCallback = <bool>[];
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db,
      onSettingsChanged: () => mountedAtCallback.add(state.mounted as bool))));
    state = tester.state(find.byType(FixtureHomePage));
    db.emit('backgrounds', 'bg', {'imageBase64': 'synthetic'});
    await tester.idle(); // Deliver stream data, but leave the scheduled frame pending.
    expect(mountedAtCallback, isEmpty);
    expect(state.settings.customBackgrounds.keys, ['bg']);
    await tester.pumpWidget(const SizedBox());
    expect(state.mounted, isFalse);
    expect(mountedAtCallback, [false]);
    expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KNOWN DEFECT: A queued visual callback can notify root after keyed B mounts', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final shared = AppSettings()..autoCloseWhenAllDone = false;
    dynamic old;
    final callbackOwners = <String>[];
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db, settings: shared,
      onSettingsChanged: () => callbackOwners.add('a:${old.mounted}'))));
    old = tester.state(find.byType(FixtureHomePage));
    db.document('users/a').add(GateFixtureSnapshot({'theme': 'dark'}));
    await tester.idle();
    expect(callbackOwners, isEmpty);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('b'), profile: fixtureHomeProfile('b'), fixture: db, settings: shared,
      onSettingsChanged: () => callbackOwners.add('b'))));
    final dynamic next = tester.state(find.byType(FixtureHomePage));
    expect(old.mounted, isFalse);
    expect(next.currentUserId, 'b');
    expect(callbackOwners, ['a:false']);
    expect(shared.theme, AppThemeChoice.dark);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('injected delayed startup completion is not cancelled by Home replacement', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final completion = Completer<void>();
    final trace = <String>[];
    dynamic old;
    final effects = HomePlatformEffects(startLocation: () => trace.add('location:a'), initializePush: () async {
      trace.add('push:start:a');
      await completion.future;
      trace.add('push:end:a:${old.mounted}');
    });
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db, platformEffects: effects)));
    old = tester.state(find.byType(FixtureHomePage));
    expect(trace, ['location:a', 'push:start:a']);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('b'), profile: fixtureHomeProfile('b'), fixture: db)));
    completion.complete();
    await flushHomeFixture(tester);
    expect(trace, ['location:a', 'push:start:a', 'push:end:a:false']);
    expect(db.active['users/a'], 0);
    expect(db.active['users/b'], 1);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    // This exercises the injection boundary; it does not certify real FCM/GPS ownership.
    expect(tester.takeException(), isNull);
  });
}
