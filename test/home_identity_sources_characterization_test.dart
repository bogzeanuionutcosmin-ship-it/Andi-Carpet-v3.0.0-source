import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';
import 'support/home_sync_fixture.dart';

void main() {
  testWidgets('member directory preserves hidden-user filtering, own fallback and team context across reconnect', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db)));
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    db.query('memberDirectory').add(HomeFixtureSnapshot([
      HomeFixtureDoc('hidden', {'name': 'Hidden admin', 'role': 'admin', 'hiddenFromMembers': true}),
      HomeFixtureDoc('director', {'name': 'Visible director', 'role': 'admin'}),
      HomeFixtureDoc('b', {'name': 'Bob', 'nickname': 'Bee', 'useNickname': true, 'active': true}),
    ]));
    db.query('teams').add(HomeFixtureSnapshot([
      HomeFixtureDoc('own', {'name': 'Own', 'members': ['a', 'b']}),
      HomeFixtureDoc('other', {'name': 'Other', 'members': ['c']}),
    ]));
    await flushHomeFixture(tester);
    expect(state.users.map((dynamic u) => u.id).toList(), ['director', 'b', 'a']);
    expect(state.userName('hidden'), 'Sistem');
    expect(state.userName('b'), 'Bee');
    expect(state.me.name, 'User a'); // Missing own directory entry uses the profile.
    expect(state.me.teamId, 'own');
    expect(state.canEditTeam('own'), isTrue);
    expect(state.canEditTeam('other'), isFalse);
    expect(state.canEditTeam('missing'), isFalse);
    final starts = Map<String, int>.from(db.starts);
    db.query('memberDirectory').addError('directory disconnected');
    await flushHomeFixture(tester);
    expect(state.coreSyncError, 'Conturi: directory disconnected');
    expect(state.userName('b'), 'Bee');
    db.emit('memberDirectory', 'a', {'name': 'Reconnected Alice', 'active': true});
    await flushHomeFixture(tester);
    expect(state.me.name, 'Reconnected Alice');
    expect(state.me.teamId, 'own');
    expect(db.starts, starts);
    expect(db.queries.containsKey('users'), isFalse);
    expect(db.queries.containsKey('audit[order:at:desc][limit:500]'), isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
  });

  testWidgets('own profile null/error/reconnect preserves settings semantics and one UID listener', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false;
    var changes = 0;
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db,
      settings: settings, onSettingsChanged: () { changes++; })));
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    final starts = Map<String, int>.from(db.starts);
    final originalTheme = settings.theme;
    db.document('users/a').add(GateFixtureSnapshot(null));
    await flushHomeFixture(tester);
    expect(settings.theme, originalTheme);
    expect(changes, 0);
    db.document('users/a').add(GateFixtureSnapshot({'theme': 'dark', 'fontFamily': 'Roboto'}));
    await flushHomeFixture(tester);
    expect(settings.theme, AppThemeChoice.dark);
    expect(settings.personalBackgroundId, 'global');
    expect(changes, 1);
    db.document('users/b').add(GateFixtureSnapshot({'theme': 'light'}));
    db.document('users/a').addError('own disconnected');
    await flushHomeFixture(tester);
    expect(state.coreSyncError, 'Profil propriu: own disconnected');
    expect(settings.theme, AppThemeChoice.dark);
    expect(changes, 1);
    db.document('users/a').add(GateFixtureSnapshot({'theme': 'light', 'fontFamily': 'Roboto'}));
    await flushHomeFixture(tester);
    expect(settings.theme, AppThemeChoice.light);
    expect(changes, 2);
    expect(db.starts, starts);
    expect(db.active['users/a'], 1);
    expect(db.active['users/b'], isNull);
    await tester.pumpWidget(const SizedBox());
    db.document('users/a').add(GateFixtureSnapshot({'theme': 'dark'}));
    await flushHomeFixture(tester);
    expect(settings.theme, AppThemeChoice.light);
    expect(changes, 2);
    expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated keyed Home A B A replacement cancels old sources and starts with fresh identity data', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    dynamic previous;
    for (final uid in ['a', 'b', 'a']) {
      await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
        key: ValueKey(uid), profile: fixtureHomeProfile(uid), fixture: db)));
      final dynamic state = tester.state(find.byType(FixtureHomePage));
      if (previous != null) expect(previous.mounted, isFalse);
      expect(state.currentUserId, uid);
      expect(state.users.length, 1);
      expect(state.me.name, 'User $uid');
      expect(state.tab, 0);
      expect(state.notifications, isEmpty);
      expect(state.expenses, isEmpty);
      expect(state.teams, isEmpty);
      expect(state.canEditTeam('old-team'), isFalse);
      expect(db.activeCount, 14);
      expect(db.active['users/$uid'], 1);
      final other = uid == 'a' ? 'b' : 'a';
      if (db.active.containsKey('users/$other')) expect(db.active['users/$other'], 0);
      db.emit('notifications[where:userId=$other]', 'late', {'userId': other, 'read': true});
      db.document('users/$other').addError('old account error');
      await flushHomeFixture(tester);
      expect(state.notifications, isEmpty);
      expect(state.coreSyncError, isNull);
      db.emit('memberDirectory', uid, {'name': 'Loaded $uid', 'active': true});
      db.emit('notifications[where:userId=$uid]', 'notice-$uid', {'userId': uid, 'read': true});
      await flushHomeFixture(tester);
      expect(state.me.name, 'Loaded $uid');
      expect(state.notifications.single.id, 'notice-$uid');
      state.tab = 3;
      previous = state;
    }
    expect(db.starts['users/a'], 2);
    expect(db.starts['users/b'], 1);
    expect(db.starts['memberDirectory'], 3);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    expect(db.trace.where((e) => e.startsWith('cancel:')).length, 42);
    expect(tester.takeException(), isNull);
  });
}
