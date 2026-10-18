import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';
import 'support/home_maintenance_fixture.dart';
import 'support/home_sync_fixture.dart';

void main() {
  testWidgets('KNOWN DEFECT: two admin Homes with stale legacy metadata both execute the destructive migration', (tester) async {
    final a = HomeSyncFixture(); final b = HomeSyncFixture();
    final db = HomeMaintenanceFixture()..primeExisting(migrated: false);
    final metadata = Completer<DocumentSnapshot<Map<String, dynamic>>>();
    final commit = Completer<void>();
    db.documentReads['meta/uiSettings'] = () => metadata.future;
    final member = {'role': 'member', 'functionIds': ['custom'], 'effectivePermissions': ['viewMap']};
    db.setQuery('users', [MaintenanceDoc(db, 'users/member', member)]);
    db.setQuery('functions', [MaintenanceDoc(db, 'functions/custom', {'active': true})]);
    db.beforeCommit = (_) => commit.future;
    FixtureHomePage page(String uid, HomeSyncFixture sync) => FixtureHomePage(
      key: ValueKey(uid), fixture: sync, maintenanceFirestore: db,
      profile: FirebaseUserProfile(uid: uid, name: 'Synthetic $uid', email: '$uid@example.test',
        role: 'admin', active: true, status: 'approved', function: UserFunction.director, functionIds: const ['admin']),
      settings: AppSettings()..automaticBackup = false..autoCloseWhenAllDone = false,
    );
    await tester.pumpWidget(MaterialApp(home: Column(children: [page('a', a), page('b', b)])));
    await flushHomeFixture(tester);
    expect(db.trace.where((e) => e == 'get:meta/uiSettings'), hasLength(2)); expect(db.commitAttempts, isEmpty);
    metadata.complete(GateFixtureSnapshot({'functionSystemVersion': 'legacy'})); await flushHomeFixture(tester);
    expect(db.commitAttempts, hasLength(2)); expect(db.commits, isEmpty);
    for (final writes in db.commitAttempts) {
      expect(writes.map((w) => '${w.operation}:${w.path}'), ['delete:functions/custom', 'set:functions/admin', 'set:users/member', 'set:meta/uiSettings']);
      expect(writes[2].data!['functionIds'], isEmpty); expect(writes[2].data!['effectivePermissions'], isEmpty);
      expect(writes.last.data!['functionSystemVersion'], 'badge_v2');
    }
    commit.complete(); await flushHomeFixture(tester);
    expect(db.commits, hasLength(2)); expect(db.directWrites, isEmpty); expect(db.unexpected, isEmpty);
    expect(member, {'role': 'member', 'functionIds': ['custom'], 'effectivePermissions': ['viewMap']});
    expect(db.commits.expand((w) => w).where((w) => w.operation == 'delete'), hasLength(2));
    await tester.pumpWidget(const SizedBox()); expect(a.activeCount, 0); expect(b.activeCount, 0);
    await a.close(); await b.close(); expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
