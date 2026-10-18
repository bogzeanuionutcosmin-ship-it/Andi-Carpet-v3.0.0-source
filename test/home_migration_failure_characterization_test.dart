import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_sync_fixture.dart';
import 'support/home_maintenance_fixture.dart';

Future<void> mountMigration(WidgetTester tester, HomeSyncFixture sync, HomeMaintenanceFixture db) async {
  await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
    key: const ValueKey('migration-admin'), fixture: sync, maintenanceFirestore: db,
    profile: FirebaseUserProfile(uid: 'admin', name: 'Synthetic Admin', email: 'admin@example.test',
      role: 'admin', active: true, status: 'approved', function: UserFunction.director, functionIds: const ['admin']),
    settings: AppSettings()..automaticBackup = false..autoCloseWhenAllDone = false,
  )));
  await flushHomeFixture(tester);
}

void main() {
  testWidgets('KNOWN DEFECT: second migration batch rejection leaves committed deletions and no version marker or retry', (tester) async {
    final sync = HomeSyncFixture(); final db = HomeMaintenanceFixture()..primeExisting(migrated: false);
    addTearDown(sync.close);
    final source = <String, dynamic>{'role': 'member', 'functionIds': ['legacy0'], 'effectivePermissions': ['viewMap']};
    db.setQuery('functions', List.generate(350, (i) => MaintenanceDoc(db, 'functions/legacy$i', {'active': true})));
    db.setQuery('users', [MaintenanceDoc(db, 'users/member', source)]);
    db.beforeCommit = (_) async {
      if (db.commitAttempts.length == 2) throw StateError('synthetic migration second batch failure');
    };
    final uncaught = <Object>[];
    // Observe the existing unawaited startup error; do not add runtime catch,
    // rollback/retry or ignore unrelated failures.
    await runZonedGuarded<Future<void>>(() async {
      await mountMigration(tester, sync, db);
      await flushHomeFixture(tester);
    }, (error, stack) { uncaught.add(error); });
    expect(uncaught, hasLength(1));
    expect(uncaught.single, isA<StateError>());
    expect(uncaught.single.toString(), contains('synthetic migration second batch failure'));
    expect(db.commitAttempts.map((batch) => batch.length), [350, 3]);
    expect(db.commits, hasLength(1));
    expect(db.commits.single.every((w) => w.operation == 'delete' && w.path.startsWith('functions/legacy')), isTrue);
    expect(db.commits.expand((batch) => batch).any((w) => w.path == 'meta/uiSettings'), isFalse);
    expect(db.commitAttempts.last.map((w) => w.path), ['functions/admin', 'users/member', 'meta/uiSettings']);
    expect(source, {'role': 'member', 'functionIds': ['legacy0'], 'effectivePermissions': ['viewMap']});
    await flushHomeFixture(tester); expect(db.commitAttempts, hasLength(2));
    expect(db.directWrites, isEmpty); expect(db.unexpected, isEmpty);
    expect(db.commits.expand((batch) => batch).any((w) => w.path.startsWith('expenses/') || w.path.startsWith('perDiems/') || w.path.startsWith('locations/')), isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0); expect(tester.takeException(), isNull);
    // Fake rejection is before commit; network ambiguity after server commit
    // and durable restore/rollback are outside this characterization.
  });

  testWidgets('KNOWN DEFECT: unknown future badge version also enters destructive legacy migration', (tester) async {
    final sync = HomeSyncFixture(); final db = HomeMaintenanceFixture()..primeExisting();
    addTearDown(sync.close);
    final meta = <String, dynamic>{'functionSystemVersion': 'badge_v3', 'futureSchema': {'rights': ['preserve']}};
    final member = <String, dynamic>{'role': 'member', 'functionIds': ['future'], 'effectivePermissions': ['viewMap']};
    db.setDocument('meta/uiSettings', meta);
    db.setQuery('functions', [MaintenanceDoc(db, 'functions/future', {'active': true, 'permissions': ['viewMap']})]);
    db.setQuery('users', [MaintenanceDoc(db, 'users/member', member)]);
    await mountMigration(tester, sync, db);
    final writes = db.commits.single;
    expect(writes.map((w) => '${w.operation}:${w.path}'), ['delete:functions/future', 'set:functions/admin', 'set:users/member', 'set:meta/uiSettings']);
    expect(writes[2].data!['functionIds'], isEmpty);
    expect(writes[2].data!['effectivePermissions'], isEmpty);
    expect(writes.last.data!['functionSystemVersion'], 'badge_v2');
    expect(writes.last.merge, isTrue);
    expect(writes.last.data!.containsKey('futureSchema'), isFalse);
    expect(meta, {'functionSystemVersion': 'badge_v3', 'futureSchema': {'rights': ['preserve']}});
    expect(member['functionIds'], ['future']); expect(member['effectivePermissions'], ['viewMap']);
    expect(db.directWrites, isEmpty); expect(db.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(sync.activeCount, 0); expect(tester.takeException(), isNull);
    // Original scripted snapshots stay unmutated. That is not a claim that
    // the resulting database preserves function assignments; it does not.
  });
}
