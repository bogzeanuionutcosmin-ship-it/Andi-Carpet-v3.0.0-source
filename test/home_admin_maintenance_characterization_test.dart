import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';
import 'support/home_sync_fixture.dart';
import 'support/home_maintenance_fixture.dart';

FirebaseUserProfile _admin() => FirebaseUserProfile(uid: 'admin', name: 'Synthetic admin',
  email: 'admin@example.test', role: 'admin', active: true, status: 'approved',
  function: UserFunction.director, functionIds: const ['admin']);

Future<void> _mount(WidgetTester tester, HomeSyncFixture sync, HomeMaintenanceFixture maintenance,
    {AppSettings? settings}) async {
  await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
    key: const ValueKey('admin'), profile: _admin(), fixture: sync, maintenanceFirestore: maintenance,
    settings: settings ?? (AppSettings()..automaticBackup = false..autoCloseWhenAllDone = false))));
  await flushHomeFixture(tester);
}

void main() {
  testWidgets('admin startup keeps audit/global finance listeners and real seed/migration reads; badge_v2 avoids writes', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    await _mount(tester, sync, maintenance);
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    expect(sync.activeCount, 18);
    expect(sync.trace.where((e) => e.startsWith('listen:')).toList(), [
      'listen:locationCategories', 'listen:backgrounds', 'listen:functions', 'listen:users',
      'listen:teams', 'listen:cars', 'listen:locations', 'listen:schedules', 'listen:records',
      'listen:notifications', 'listen:chatMessages[where:recipientId=admin]',
      'listen:groupChatMessages[order:createdAt:desc][limit:20]', 'listen:meta/uiSettings',
      'listen:audit[order:at:desc][limit:500]', 'listen:expenses', 'listen:perDiems',
      'listen:finance', 'listen:settlements',
    ]);
    expect(maintenance.trace.where((e) => e.startsWith('get:')).toList(), [
      'get:locations[limit:1]', 'get:locationCategories[limit:1]', 'get:meta/uiSettings', 'get:functions[limit:1]',
    ]);
    expect(maintenance.commits, isEmpty);
    expect(maintenance.directWrites, isEmpty);
    expect(maintenance.unexpected, isEmpty);
    sync.emit('audit[order:at:desc][limit:500]', 'one', {'actor': 'Fixture', 'action': 'Synthetic action', 'target': 'Synthetic target'});
    await flushHomeFixture(tester);
    expect(state.audit.single.action, 'Synthetic action');
    final starts = Map<String, int>.from(sync.starts);
    sync.query('audit[order:at:desc][limit:500]').addError('audit unavailable');
    await flushHomeFixture(tester);
    expect(state.coreSyncError, 'Audit: audit unavailable');
    expect(state.audit.single.id, 'one');
    sync.emit('audit[order:at:desc][limit:500]', 'two', {'action': 'Reconnected'});
    await flushHomeFixture(tester);
    expect(state.audit.single.id, 'two');
    expect(sync.starts, starts);
    await tester.pumpWidget(const SizedBox());
    sync.emit('audit[order:at:desc][limit:500]', 'late', {'action': 'Late'});
    await flushHomeFixture(tester);
    expect(state.audit.single.id, 'two');
    expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maintenance with automatic backup disabled still prunes notifications and backup items before parents', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('notifications[before:createdAt]', [MaintenanceDoc(maintenance, 'notifications/old', {})]);
    maintenance.setQuery('backups[before:createdAt]', [MaintenanceDoc(maintenance, 'backups/old', {})]);
    maintenance.setQuery('backups/old/items', [MaintenanceDoc(maintenance, 'backups/old/items/item', {})]);
    await _mount(tester, sync, maintenance);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot(null));
    await flushHomeFixture(tester);
    expect(maintenance.commits.map((batch) => batch.map((w) => '${w.operation}:${w.path}').toList()).toList(), [
      ['delete:notifications/old'], ['delete:backups/old/items/item'],
    ]);
    expect(maintenance.directWrites.map((w) => '${w.operation}:${w.path}'), ['delete:backups/old']);
    expect(maintenance.trace.indexOf('commit:1'), lessThan(maintenance.trace.indexOf('delete:backups/old')));
    expect(maintenance.trace.contains('get:meta/backupAutomation'), isFalse);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
  });

  testWidgets('KNOWN DEFECT: legacy badge migration deletes definitions and clears member function assignments', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting(migrated: false);
    addTearDown(sync.close);
    maintenance.setQuery('users', [
      MaintenanceDoc(maintenance, 'users/admin', {'role': 'admin', 'functionIds': ['custom']}),
      MaintenanceDoc(maintenance, 'users/member', {'role': 'member', 'functionIds': ['custom'], 'effectivePermissions': ['editProgram']}),
    ]);
    maintenance.setQuery('functions', [MaintenanceDoc(maintenance, 'functions/custom', {'active': true})]);
    await _mount(tester, sync, maintenance);
    final writes = maintenance.commits.single;
    expect(writes.map((w) => '${w.operation}:${w.path}'), [
      'delete:functions/custom', 'set:functions/admin', 'set:users/admin', 'set:users/member', 'set:meta/uiSettings',
    ]);
    final member = writes.singleWhere((w) => w.path == 'users/member');
    expect(member.data!['functionIds'], isEmpty);
    expect(member.data!['effectivePermissions'], isEmpty);
    expect(member.data!['function'], '');
    expect(member.merge, isTrue);
    final admin = writes.singleWhere((w) => w.path == 'users/admin');
    expect(admin.data!['functionIds'], ['admin']);
    expect(admin.data!['effectivePermissions'], FunctionPermission.values.map((p) => p.name).toList()..sort());
    expect(writes.last.data!['functionSystemVersion'], 'badge_v2');
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
  });

  testWidgets('function snapshot recomputes active permissions only and avoids unchanged member writes', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('users', [
      MaintenanceDoc(maintenance, 'users/changed', {'functionIds': ['active', 'inactive'], 'effectivePermissions': []}),
      MaintenanceDoc(maintenance, 'users/same', {'functionIds': ['active'], 'effectivePermissions': ['viewMap']}),
    ]);
    await _mount(tester, sync, maintenance);
    sync.query('functions').add(HomeFixtureSnapshot([
      HomeFixtureDoc('active', {'name': 'Active', 'active': true, 'permissions': ['viewMap']}),
      HomeFixtureDoc('inactive', {'name': 'Inactive', 'active': false, 'permissions': ['editProgram']}),
    ]));
    await flushHomeFixture(tester);
    final write = maintenance.commits.single.single;
    expect(write.path, 'users/changed');
    expect(write.data!['effectivePermissions'], ['viewMap']);
    expect(write.data!.containsKey('functionIds'), isFalse);
    expect(write.merge, isTrue);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
  });

  testWidgets('KNOWN DEFECT: in-flight maintenance can continue writes after Home dispose', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    final pending = Completer<QuerySnapshot<Map<String, dynamic>>>();
    maintenance.queryReads['notifications[before:createdAt]'] = () => pending.future;
    maintenance.setQuery('backups[before:createdAt]', []);
    await _mount(tester, sync, maintenance);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot(null));
    await tester.idle();
    sync.document('meta/uiSettings').add(GateFixtureSnapshot(null));
    await tester.idle();
    expect(maintenance.trace.where((e) => e == 'get:notifications[before:createdAt]').length, 1);
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    await tester.pumpWidget(const SizedBox());
    expect(state.mounted, isFalse);
    expect(sync.activeCount, 0);
    pending.complete(HomeFixtureSnapshot([MaintenanceDoc(maintenance, 'notifications/late', {})]));
    await flushHomeFixture(tester);
    expect(maintenance.commits.single.single.path, 'notifications/late');
    expect(maintenance.trace, contains('get:backups[before:createdAt]'));
    expect(maintenance.unexpected, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic backup runs all fifteen reads, records completed status and then marks automation owner', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('notifications[before:createdAt]', []);
    maintenance.setQuery('backups[before:createdAt]', []);
    maintenance.setDocument('meta/backupAutomation', {});
    const names = ['users','teams','cars','locations','locationCategories','functions',
      'schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit'];
    for (final name in names) { maintenance.setQuery(name, []); }
    await _mount(tester, sync, maintenance,
      settings: AppSettings()..automaticBackup = true..autoCloseWhenAllDone = false);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot({}));
    await flushHomeFixture(tester);
    expect(maintenance.directWrites.length, 3);
    final running = maintenance.directWrites[0];
    final complete = maintenance.directWrites[1];
    final automation = maintenance.directWrites[2];
    expect(running.path, startsWith('backups/'));
    expect(running.data!['status'], 'running');
    expect(running.data!['createdBy'], 'admin');
    expect(running.data!['collections'], names);
    expect(running.data!['uiSettings'], {'functionSystemVersion': 'badge_v2'});
    expect(running.merge, isFalse);
    expect(complete.path, running.path);
    expect(complete.data!['status'], 'complete');
    expect(complete.data!['documentCount'], 0);
    expect(complete.merge, isTrue);
    expect(automation.path, 'meta/backupAutomation');
    expect(automation.data!['lastRunBy'], 'admin');
    expect(automation.merge, isTrue);
    final start = maintenance.trace.indexOf('set:${running.path}');
    expect(maintenance.trace.skip(start + 1).where((e) => e.startsWith('get:')).toList(),
      names.map((name) => 'get:$name').toList());
    expect(maintenance.commits, isEmpty);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic backup read failure records failed status without successful automation marker', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('notifications[before:createdAt]', []);
    maintenance.setQuery('backups[before:createdAt]', []);
    maintenance.setDocument('meta/backupAutomation', {});
    maintenance.setQuery('users', []);
    maintenance.setQuery('teams', []);
    maintenance.queryReads['cars'] = () => Future<QuerySnapshot<Map<String, dynamic>>>.error(StateError('synthetic backup failure'));
    await _mount(tester, sync, maintenance,
      settings: AppSettings()..automaticBackup = true..autoCloseWhenAllDone = false);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot({}));
    await flushHomeFixture(tester);
    expect(maintenance.directWrites.length, 2);
    final running = maintenance.directWrites.first;
    final failed = maintenance.directWrites.last;
    expect(failed.path, running.path);
    expect(failed.data!['status'], 'failed');
    expect(failed.data!['error'], contains('synthetic backup failure'));
    expect(failed.data!['documentCount'], 0);
    expect(failed.merge, isTrue);
    expect(maintenance.trace.where((e) => e == 'get:cars').length, 1);
    expect(maintenance.trace.contains('get:locations'), isFalse);
    expect(maintenance.trace.contains('set:meta/backupAutomation'), isFalse);
    expect(maintenance.commits, isEmpty);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-empty backup preserves payloads and collection identity across batches of eight', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('notifications[before:createdAt]', []);
    maintenance.setQuery('backups[before:createdAt]', []);
    maintenance.setDocument('meta/backupAutomation', {});
    const names = ['users','teams','cars','locations','locationCategories','functions',
      'schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit'];
    for (final name in names) { maintenance.setQuery(name, []); }
    final users = List.generate(9, (i) => MaintenanceDoc(maintenance, 'users/id$i',
      {'name': 'Synthetic $i', 'nested': {'values': [i, null, true]}, 'at': Timestamp(123, i)}));
    final teams = List.generate(8, (i) => MaintenanceDoc(maintenance, 'teams/id$i', {'members': ['id$i']}));
    maintenance.setQuery('users', users); maintenance.setQuery('teams', teams);
    await _mount(tester, sync, maintenance,
      settings: AppSettings()..automaticBackup = true..autoCloseWhenAllDone = false);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot({}));
    await flushHomeFixture(tester);
    expect(maintenance.commits.map((batch) => batch.length).toList(), [8, 8, 1]);
    final root = maintenance.directWrites.first.path;
    final items = maintenance.commits.expand((batch) => batch).toList();
    expect(items.map((w) => w.path).toList(), [
      ...users.map((d) => '$root/items/users__${d.id}'),
      ...teams.map((d) => '$root/items/teams__${d.id}'),
    ]);
    for (var i = 0; i < items.length; i++) {
      final source = [...users, ...teams][i];
      expect(items[i].operation, 'set'); expect(items[i].merge, isFalse);
      expect(items[i].data, {'collection': i < 9 ? 'users' : 'teams',
        'documentId': source.id, 'data': source.data()});
    }
    expect(maintenance.directWrites[1].data!['status'], 'complete');
    expect(maintenance.directWrites[1].data!['documentCount'], 17);
    expect(maintenance.directWrites.last.path, 'meta/backupAutomation');
    expect(maintenance.trace.lastIndexOf('commit:1'), lessThan(maintenance.trace.lastIndexOf('set:$root')));
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox()); expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KNOWN DEFECT: backup batch failure keeps earlier items and counts attempted documents without rollback', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('notifications[before:createdAt]', []);
    maintenance.setQuery('backups[before:createdAt]', []);
    maintenance.setDocument('meta/backupAutomation', {});
    maintenance.setQuery('users', List.generate(17, (i) =>
      MaintenanceDoc(maintenance, 'users/id$i', {'name': 'Synthetic $i'})));
    maintenance.beforeCommit = (_) async {
      if (maintenance.commitAttempts.length == 2) throw StateError('synthetic second batch failure');
    };
    await _mount(tester, sync, maintenance,
      settings: AppSettings()..automaticBackup = true..autoCloseWhenAllDone = false);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot({}));
    await flushHomeFixture(tester);
    expect(maintenance.commitAttempts.map((batch) => batch.length).toList(), [8, 8]);
    expect(maintenance.commits.single.length, 8);
    expect(maintenance.commits.single.every((w) => w.operation == 'set'), isTrue);
    expect(maintenance.directWrites.length, 2);
    final failed = maintenance.directWrites.last;
    expect(failed.path, maintenance.directWrites.first.path);
    expect(failed.data!['status'], 'failed');
    expect(failed.data!['documentCount'], 16); // Attempted count, only eight committed in this fixture.
    expect(failed.data!['error'], contains('synthetic second batch failure'));
    expect(failed.merge, isTrue);
    expect(maintenance.trace.contains('get:teams'), isFalse);
    expect(maintenance.trace.contains('set:meta/backupAutomation'), isFalse);
    expect(maintenance.directWrites.any((w) => w.operation == 'delete'), isFalse);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox()); expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retention commits 300-item batches before deleting each backup parent, including empty backups', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('notifications[before:createdAt]', List.generate(601, (i) =>
      MaintenanceDoc(maintenance, 'notifications/n$i', {})));
    maintenance.setQuery('backups[before:createdAt]', [
      MaintenanceDoc(maintenance, 'backups/full', {}), MaintenanceDoc(maintenance, 'backups/empty', {}),
    ]);
    maintenance.setQuery('backups/full/items', List.generate(301, (i) =>
      MaintenanceDoc(maintenance, 'backups/full/items/i$i', {})));
    maintenance.setQuery('backups/empty/items', []);
    await _mount(tester, sync, maintenance);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot({}));
    await flushHomeFixture(tester);
    expect(maintenance.commits.map((batch) => batch.length).toList(), [300, 300, 1, 300, 1]);
    expect(maintenance.commits.expand((batch) => batch).map((w) => w.path).toList(), [
      ...List.generate(601, (i) => 'notifications/n$i'),
      ...List.generate(301, (i) => 'backups/full/items/i$i'),
    ]);
    expect(maintenance.commits.expand((batch) => batch).every((w) => w.operation == 'delete'), isTrue);
    expect(maintenance.directWrites.map((w) => w.path).toList(), ['backups/full', 'backups/empty']);
    expect(maintenance.trace.lastIndexOf('commit:1'), lessThan(maintenance.trace.indexOf('delete:backups/full')));
    expect(maintenance.trace.indexOf('delete:backups/full'), lessThan(maintenance.trace.indexOf('get:backups/empty/items')));
    expect(maintenance.trace.contains('get:meta/backupAutomation'), isFalse);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox()); expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retention batch failure preserves parent and stops later backup reads without retry', (tester) async {
    final sync = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    maintenance.setQuery('notifications[before:createdAt]', []);
    maintenance.setQuery('backups[before:createdAt]', [
      MaintenanceDoc(maintenance, 'backups/full', {}), MaintenanceDoc(maintenance, 'backups/later', {}),
    ]);
    maintenance.setQuery('backups/full/items', List.generate(301, (i) =>
      MaintenanceDoc(maintenance, 'backups/full/items/i$i', {})));
    maintenance.beforeCommit = (_) async {
      if (maintenance.commitAttempts.length == 2) throw StateError('synthetic retention failure');
    };
    await _mount(tester, sync, maintenance);
    sync.document('meta/uiSettings').add(GateFixtureSnapshot({}));
    await flushHomeFixture(tester);
    expect(maintenance.commitAttempts.map((batch) => batch.length).toList(), [300, 1]);
    expect(maintenance.commits.single.length, 300);
    expect(maintenance.directWrites, isEmpty);
    expect(maintenance.trace.contains('get:backups/later/items'), isFalse);
    expect(maintenance.trace.contains('get:meta/backupAutomation'), isFalse);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox()); expect(sync.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

}
