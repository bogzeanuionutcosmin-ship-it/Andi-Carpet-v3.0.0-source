import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';
import 'support/home_sync_fixture.dart';

void main() {
  testWidgets('member queries start once in original order before platform effects; dispose cancels all', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db)));
    expect(db.trace.where((e) => e.startsWith('listen:')).toList(), [
      'listen:locationCategories', 'listen:backgrounds', 'listen:functions',
      'listen:memberDirectory', 'listen:users/a', 'listen:teams', 'listen:cars',
      'listen:locations', 'listen:schedules', 'listen:records',
      'listen:notifications[where:userId=a]', 'listen:chatMessages[where:recipientId=a]',
      'listen:groupChatMessages[order:createdAt:desc][limit:20]', 'listen:meta/uiSettings',
    ]);
    expect(db.trace.sublist(db.trace.length - 2), ['effect:location', 'effect:push']);
    expect(db.activeCount, 14);
    expect(db.starts.values.every((v) => v == 1), isTrue);
    expect(db.queries.containsKey('users'), isFalse);
    expect(db.queries.containsKey('audit[order:at:desc][limit:500]'), isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real Home state consumes core groups, preserves data on error and reconnects without new listens', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false;
    var settingsChanges = 0;
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db,
      settings: settings, onSettingsChanged: () { settingsChanges++; })));
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    db.emit('memberDirectory', 'a', {'name': 'Alice', 'active': true});
    db.emit('teams', 't1', {'name': 'Team one', 'members': ['a']});
    db.emit('cars', 'car', {'plate': 'SYNTHETIC-1'});
    db.emit('locations', 'loc', {'name': 'Synthetic room'});
    db.emit('schedules', 'schedule', {'teamId': 't1', 'items': []});
    db.emit('records', 'record', {'teamId': 't1', 'locationId': 'loc'});
    db.emit('locationCategories', 'category', {'name': 'Synthetic category'});
    db.emit('functions', 'custom', {'name': 'Synthetic function', 'permissions': []});
    db.emit('backgrounds', 'bg', {'name': 'Synthetic background', 'imageBase64': 'synthetic'});
    db.emit('notifications[where:userId=a]', 'notice', {'userId': 'a', 'read': true});
    db.emit('chatMessages[where:recipientId=a]', 'message', {'senderId': 'a', 'read': true});
    db.emit('groupChatMessages[order:createdAt:desc][limit:20]', 'group', {'senderId': 'a'});
    db.document('users/a').add(GateFixtureSnapshot({'theme': 'dark', 'locationMode': 'offline'}));
    db.document('meta/uiSettings').add(GateFixtureSnapshot({'brandingBackgroundId': 'none'}));
    await flushHomeFixture(tester);
    expect(state.me.name, 'Alice');
    expect(state.me.teamId, 't1');
    expect(state.cars.single.plate, 'SYNTHETIC-1');
    expect(state.locations.single.id, 'loc');
    expect(state.schedules.single.id, 'schedule');
    expect(state.records.single.id, 'record');
    expect(state.categories.single.id, 'category');
    expect(state.functionDefinitions.single.id, 'custom');
    expect(state.notifications.single.id, 'notice');
    expect(settings.customBackgrounds.keys, ['bg']);
    expect(settings.theme, AppThemeChoice.dark);
    expect(settingsChanges, greaterThan(0));
    expect(db.activeCount, 18); // 14 core + 4 team-scoped financial.
    final before = Map<String, int>.from(db.starts);
    db.query('cars').addError('synthetic offline');
    await flushHomeFixture(tester);
    expect(state.coreSyncError, contains('synthetic offline'));
    expect(state.cars.single.plate, 'SYNTHETIC-1');
    db.emit('cars', 'car', {'plate': 'SYNTHETIC-2'});
    await flushHomeFixture(tester);
    expect(state.cars.single.plate, 'SYNTHETIC-2');
    expect(db.starts, before);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    db.emit('cars', 'late', {'plate': 'LATE'});
    await flushHomeFixture(tester);
    expect(state.cars.single.plate, 'SYNTHETIC-2');
  });

  testWidgets('team scope switch cancels four old listeners, clears financial lists and rejects queued old events', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db)));
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    db.emit('teams', 't1', {'name': 'One', 'members': ['a']});
    await flushHomeFixture(tester);
    db.emit('expenses[where:teamId=t1]', 'expense1', {'teamId': 't1', 'amount': 50});
    await flushHomeFixture(tester);
    expect(state.expenses.single.id, 'expense1');
    db.emit('teams', 't2', {'name': 'Two', 'members': ['a']});
    await flushHomeFixture(tester);
    expect(state.expenses, isEmpty);
    for (final collection in ['expenses', 'perDiems', 'finance', 'settlements']) {
      expect(db.active['$collection[where:teamId=t1]'], 0);
      expect(db.active['$collection[where:teamId=t2]'], 1);
    }
    db.emit('expenses[where:teamId=t1]', 'late-old', {'teamId': 't1', 'amount': 999});
    db.emit('expenses[where:teamId=t2]', 'expense2', {'teamId': 't2', 'amount': 75});
    await flushHomeFixture(tester);
    expect(state.expenses.single.id, 'expense2');
    final before = Map<String, int>.from(db.starts);
    db.emit('teams', 't2', {'name': 'Two', 'members': ['a']});
    await flushHomeFixture(tester);
    expect(db.starts, before);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
  });

  testWidgets('actual Home State of A disposes before profile B; B gets a fresh state', (tester) async {
    final db = HomeSyncFixture();
    final gate = GateFixture();
    addTearDown(db.close);
    addTearDown(gate.close);
    await mountFixtureGate(tester, gate, activePageBuilder: (key, profile) =>
      FixtureHomePage(key: key, profile: profile, fixture: db));
    gate.profile('a').add(GateFixtureSnapshot({'active': true}));
    await flushHomeFixture(tester);
    final dynamic old = tester.state(find.byType(FixtureHomePage));
    old.tab = 3;
    db.emit('memberDirectory', 'a', {'name': 'Cached Alice', 'active': true});
    await flushHomeFixture(tester);
    gate.user = GateFixtureUser('b', 'b@example.com');
    gate.auth.add(gate.user);
    await flushHomeFixture(tester);
    expect(find.byType(FixtureHomePage), findsNothing);
    expect(old.mounted, isFalse);
    expect(db.active['users/a'], 0);
    expect(db.activeCount, 0);
    gate.profile('b').add(GateFixtureSnapshot({'active': true}));
    await flushHomeFixture(tester);
    final dynamic next = tester.state(find.byType(FixtureHomePage));
    expect(identical(next, old), isFalse);
    expect(old.mounted, isFalse);
    expect(next.currentUserId, 'b');
    expect(next.me.id, 'b');
    expect(next.tab, 0);
    expect(db.active['users/a'], 0);
    expect(db.active['users/b'], 1);
    expect(db.activeCount, 14);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
  });
}
