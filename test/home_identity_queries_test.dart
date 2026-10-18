import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_sync_fixture.dart';

class _RecordingIdentityQueries implements HomeIdentityQueries {
  final HomeIdentityQueries delegate;
  final calls = <String>[];
  _RecordingIdentityQueries(HomeSyncFixture db) : delegate = HomeIdentityQueries.fromFirestore(db);
  @override
  DocumentReference<Map<String, dynamic>> ownProfile(String uid) {
    calls.add('own:$uid');
    return delegate.ownProfile(uid);
  }
  @override
  Query<Map<String, dynamic>> directory({required bool isAdmin}) {
    calls.add('directory:$isAdmin');
    return delegate.directory(isAdmin: isAdmin);
  }
}

void main() {
  test('identity query adapter preserves private document and role-based directory without listeners', () async {
    final db = HomeSyncFixture();
    final queries = HomeIdentityQueries.fromFirestore(db);
    expect(db.trace, isEmpty);
    queries.ownProfile('a').snapshots();
    queries.directory(isAdmin: false).snapshots();
    queries.directory(isAdmin: true).snapshots();
    expect(db.trace, ['snapshots:users/a', 'snapshots:memberDirectory', 'snapshots:users']);
    expect(db.activeCount, 0);
    expect(db.starts, isEmpty);
    await db.close();
  });

  test('identity adapter does not retain a prior UID and queries remain independently cancellable', () async {
    final db = HomeSyncFixture();
    final queries = HomeIdentityQueries.fromFirestore(db);
    final a = queries.ownProfile('a').snapshots().listen((_) {});
    final b = queries.ownProfile('b').snapshots().listen((_) {});
    expect(db.active['users/a'], 1);
    expect(db.active['users/b'], 1);
    await a.cancel();
    expect(db.active['users/a'], 0);
    expect(db.active['users/b'], 1);
    queries.ownProfile('a').snapshots();
    expect(db.trace.where((e) => e == 'snapshots:users/a').length, 2);
    expect(db.starts['users/a'], 1); // snapshots does not listen by itself.
    await b.cancel();
    expect(db.activeCount, 0);
    await db.close();
  });

  testWidgets('real Home uses injected identity queries once in original order', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final queries = _RecordingIdentityQueries(db);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db,
      identityQueries: queries)));
    expect(queries.calls, ['directory:false', 'own:a']);
    expect(db.activeCount, 14);
    expect(db.trace.where((e) => e.startsWith('listen:')).toList().sublist(3, 5),
        ['listen:memberDirectory', 'listen:users/a']);
    db.emit('memberDirectory', 'a', {'name': 'Alice', 'active': true});
    await flushHomeFixture(tester);
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    expect(state.me.name, 'Alice');
    expect(queries.calls, ['directory:false', 'own:a']);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
  });
}
