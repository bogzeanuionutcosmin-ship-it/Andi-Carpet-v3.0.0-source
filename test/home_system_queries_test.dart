import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';
import 'support/home_sync_fixture.dart';
import 'support/home_maintenance_fixture.dart';

class _RecordingSystemQueries implements HomeSystemQueries {
  final HomeSystemQueries delegate;
  final calls = <String>[];
  _RecordingSystemQueries(HomeSyncFixture db) : delegate = HomeSystemQueries.fromFirestore(db);
  @override
  DocumentReference<Map<String, dynamic>> uiSettings() { calls.add('settings'); return delegate.uiSettings(); }
  @override
  Query<Map<String, dynamic>> audit() { calls.add('audit'); return delegate.audit(); }
}

void main() {
  test('system adapter keeps exact paths, audit ordering/limit and no subscription ownership', () async {
    final db = HomeSyncFixture(); final queries = HomeSystemQueries.fromFirestore(db);
    queries.uiSettings(); queries.audit();
    expect(db.trace, isEmpty);
    queries.uiSettings().snapshots(); queries.audit().snapshots();
    expect(db.trace, ['snapshots:meta/uiSettings', 'snapshots:audit[order:at:desc][limit:500]']);
    expect(db.starts, isEmpty);
    expect(db.activeCount, 0);
    await db.close();
  });

  test('system adapters keep separate databases and callers independently cancel', () async {
    final a = HomeSyncFixture(); final b = HomeSyncFixture();
    final qa = HomeSystemQueries.fromFirestore(a); final qb = HomeSystemQueries.fromFirestore(b);
    var eventsA = 0; var eventsB = 0;
    final sa = qa.uiSettings().snapshots().listen((_) { eventsA++; });
    final sb = qb.uiSettings().snapshots().listen((_) { eventsB++; });
    a.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 81}));
    await Future<void>.delayed(Duration.zero);
    expect(eventsA, 1); expect(eventsB, 0);
    await sa.cancel();
    a.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 999}));
    b.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 82}));
    await Future<void>.delayed(Duration.zero);
    expect(eventsA, 1); expect(eventsB, 1);
    expect(a.activeCount, 0); expect(b.activeCount, 1);
    await sb.cancel(); await a.close(); await b.close();
  });

  testWidgets('member injected settings selection never invokes audit and preserves reconnect/cancel', (tester) async {
    final db = HomeSyncFixture(); final queries = _RecordingSystemQueries(db);
    addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db, systemQueries: queries)));
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    expect(queries.calls, ['settings']);
    final starts = Map<String, int>.from(db.starts);
    db.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 83}));
    db.document('meta/uiSettings').addError('settings offline');
    await flushHomeFixture(tester);
    expect(state.settings.defaultPerDiem, 83);
    expect(state.coreSyncError, isNull);
    db.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 84}));
    await flushHomeFixture(tester);
    expect(state.settings.defaultPerDiem, 84);
    expect(queries.calls, ['settings']); expect(db.starts, starts);
    await tester.pumpWidget(const SizedBox());
    db.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 999}));
    await flushHomeFixture(tester);
    expect(state.settings.defaultPerDiem, 84);
    expect(db.activeCount, 0);
  });

  testWidgets('admin injected settings/audit preserves guard, order, maintenance effects and error policy', (tester) async {
    final db = HomeSyncFixture(); final maintenance = HomeMaintenanceFixture()..primeExisting();
    final queries = _RecordingSystemQueries(db);
    addTearDown(db.close);
    maintenance.setQuery('notifications[before:createdAt]', []);
    maintenance.setQuery('backups[before:createdAt]', []);
    final admin = FirebaseUserProfile(uid: 'admin', name: 'Synthetic', email: 'admin@example.test',
      role: 'admin', active: true, status: 'approved', function: UserFunction.director, functionIds: const ['admin']);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(key: const ValueKey('admin'),
      profile: admin, fixture: db, maintenanceFirestore: maintenance, systemQueries: queries,
      settings: AppSettings()..automaticBackup = false..autoCloseWhenAllDone = false)));
    await flushHomeFixture(tester);
    expect(queries.calls, ['settings', 'audit']);
    expect(db.activeCount, 18);
    final starts = Map<String, int>.from(db.starts);
    db.document('meta/uiSettings').add(GateFixtureSnapshot({'defaultPerDiem': 85}));
    db.emit('audit[order:at:desc][limit:500]', 'audit', {'action': 'Synthetic action'});
    await flushHomeFixture(tester);
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    expect(state.settings.defaultPerDiem, 85);
    expect(state.audit.single.id, 'audit');
    expect(maintenance.trace, contains('get:notifications[before:createdAt]'));
    expect(maintenance.trace, contains('get:backups[before:createdAt]'));
    db.document('meta/uiSettings').addError('offline');
    await flushHomeFixture(tester);
    expect(state.coreSyncError, 'Setări UI: offline');
    expect(state.audit.single.id, 'audit');
    expect(db.starts, starts); expect(queries.calls, ['settings', 'audit']);
    expect(maintenance.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
  });
}
