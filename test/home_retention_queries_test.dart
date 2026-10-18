import 'package:andi_carpeta/home/home_retention_queries.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_maintenance_fixture.dart';

void main() {
  test('retention query construction is lazy and preserves exact caller timestamp and strict createdAt filter', () {
    final db = HomeMaintenanceFixture();
    final queries = HomeRetentionQueries.fromFirestore(db);
    expect(db.trace, isEmpty); expect(db.cutoffs, isEmpty);
    final notificationCutoff = Timestamp(123, 456);
    final backupCutoff = Timestamp(789, 123);
    queries.notificationsBefore(notificationCutoff);
    queries.backupsBefore(backupCutoff);
    expect(identical(db.cutoffs['notifications'], notificationCutoff), isTrue);
    expect(identical(db.cutoffs['backups'], backupCutoff), isTrue);
    expect(db.trace, isEmpty); expect(db.commits, isEmpty);
    expect(db.directWrites, isEmpty); expect(db.unexpected, isEmpty);
  });

  test('retention sources remain independent and caller reads return original documents without cache', () async {
    final a = HomeMaintenanceFixture(); final b = HomeMaintenanceFixture();
    final queriesA = HomeRetentionQueries.fromFirestore(a);
    final queriesB = HomeRetentionQueries.fromFirestore(b);
    final notification = MaintenanceDoc(a, 'notifications/a', {'value': 'synthetic A'});
    final backup = MaintenanceDoc(b, 'backups/b', {'value': 'synthetic B'});
    a.setQuery('notifications[before:createdAt]', [notification]);
    b.setQuery('backups[before:createdAt]', [backup]);
    final first = await queriesA.notificationsBefore(Timestamp(10, 0)).get();
    final second = await queriesB.backupsBefore(Timestamp(20, 0)).get();
    expect(identical(first.docs.single, notification), isTrue);
    expect(identical(second.docs.single, backup), isTrue);
    expect(a.trace, ['get:notifications[before:createdAt]']);
    expect(b.trace, ['get:backups[before:createdAt]']);
    a.setQuery('notifications[before:createdAt]', []);
    expect((await queriesA.notificationsBefore(Timestamp(30, 0)).get()).docs, isEmpty);
    expect(a.cutoffs['notifications'], Timestamp(30, 0));
    expect(b.cutoffs['backups'], Timestamp(20, 0));
    expect(a.trace.length, 2); expect(b.trace.length, 1);
    expect(a.directWrites, isEmpty); expect(b.directWrites, isEmpty);
    expect(a.unexpected, isEmpty); expect(b.unexpected, isEmpty);
  });

  test('retention read failure propagates unchanged with no retry or writes', () async {
    final db = HomeMaintenanceFixture();
    final error = StateError('synthetic denied retention');
    db.queryReads['backups[before:createdAt]'] = () =>
        Future<QuerySnapshot<Map<String, dynamic>>>.error(error);
    final query = HomeRetentionQueries.fromFirestore(db).backupsBefore(Timestamp(100, 0));
    expect(db.trace, isEmpty);
    await expectLater(query.get(), throwsA(same(error)));
    expect(db.trace, ['get:backups[before:createdAt]']);
    expect(db.commits, isEmpty); expect(db.directWrites, isEmpty);
    expect(db.unexpected, isEmpty);
  });
}
