import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_sync_fixture.dart';

class _RecordingOperationalQueries implements HomeOperationalQueries {
  final HomeOperationalQueries delegate;
  final calls = <String>[];
  _RecordingOperationalQueries(HomeSyncFixture db) : delegate = HomeOperationalQueries.fromFirestore(db);
  @override
  Query<Map<String, dynamic>> teams() { calls.add('teams'); return delegate.teams(); }
  @override
  Query<Map<String, dynamic>> cars() { calls.add('cars'); return delegate.cars(); }
  @override
  Query<Map<String, dynamic>> locations() { calls.add('locations'); return delegate.locations(); }
  @override
  Query<Map<String, dynamic>> schedules() { calls.add('schedules'); return delegate.schedules(); }
  @override
  Query<Map<String, dynamic>> records() { calls.add('records'); return delegate.records(); }
}

void main() {
  test('operational adapter preserves all five global paths without subscriptions or filters', () async {
    final db = HomeSyncFixture();
    final q = HomeOperationalQueries.fromFirestore(db);
    expect(db.trace, isEmpty);
    q.teams().snapshots(); q.cars().snapshots(); q.locations().snapshots();
    q.schedules().snapshots(); q.records().snapshots();
    expect(db.trace, ['snapshots:teams', 'snapshots:cars', 'snapshots:locations',
      'snapshots:schedules', 'snapshots:records']);
    expect(db.starts, isEmpty);
    expect(db.activeCount, 0);
    await db.close();
  });

  test('operational adapters keep separate databases and no listener ownership', () async {
    final a = HomeSyncFixture();
    final b = HomeSyncFixture();
    final qa = HomeOperationalQueries.fromFirestore(a);
    final qb = HomeOperationalQueries.fromFirestore(b);
    var eventsA = 0;
    var eventsB = 0;
    final sa = qa.cars().snapshots().listen((_) { eventsA++; });
    final sb = qb.cars().snapshots().listen((_) { eventsB++; });
    a.emit('cars', 'a', {'plate': 'A'});
    await Future<void>.delayed(Duration.zero);
    expect(eventsA, 1);
    expect(eventsB, 0);
    await sa.cancel();
    a.emit('cars', 'late', {'plate': 'LATE'});
    b.emit('cars', 'b', {'plate': 'B'});
    await Future<void>.delayed(Duration.zero);
    expect(eventsA, 1);
    expect(eventsB, 1);
    expect(a.activeCount, 0);
    expect(b.activeCount, 1);
    await sb.cancel();
    await a.close(); await b.close();
  });

  testWidgets('injected operational queries retain order, data on errors and reconnect with no duplicate listeners', (tester) async {
    final db = HomeSyncFixture();
    addTearDown(db.close);
    final q = _RecordingOperationalQueries(db);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db,
      operationalQueries: q)));
    const paths = ['teams', 'cars', 'locations', 'schedules', 'records'];
    expect(q.calls, paths);
    expect(db.trace.where((e) => e.startsWith('listen:')).toList().sublist(5, 10),
      paths.map((p) => 'listen:$p').toList());
    db.emit('teams', 'other', {'name': 'Other', 'members': ['b']});
    db.emit('cars', 'car', {'plate': 'SYNTHETIC'});
    db.emit('locations', 'room', {'name': 'Synthetic room'});
    db.emit('schedules', 'schedule', {'teamId': 'other', 'items': []});
    db.emit('records', 'record', {'teamId': 'other', 'locationId': 'room'});
    await flushHomeFixture(tester);
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    final starts = Map<String, int>.from(db.starts);
    const labels = ['Echipe', 'Mașini', 'Locații', 'Grafice de lucru', 'Execuții'];
    for (var i = 0; i < paths.length; i++) {
      db.query(paths[i]).addError('offline ${paths[i]}');
      await flushHomeFixture(tester);
      expect(state.coreSyncError, '${labels[i]}: offline ${paths[i]}');
    }
    expect(state.teams.single.id, 'other');
    expect(state.canEditTeam('other'), isFalse);
    expect(state.me.teamId, isNull);
    expect(state.cars.single.plate, 'SYNTHETIC');
    expect(state.locations.single.id, 'room');
    expect(state.schedules.single.id, 'schedule');
    expect(state.records.single.id, 'record');
    db.emit('cars', 'car', {'plate': 'RECONNECTED'});
    await flushHomeFixture(tester);
    expect(state.cars.single.plate, 'RECONNECTED');
    expect(db.starts, starts);
    expect(q.calls, paths);
    expect(db.activeCount, 14);
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0);
    db.emit('cars', 'late', {'plate': 'LATE'});
    await flushHomeFixture(tester);
    expect(state.cars.single.plate, 'RECONNECTED');
    expect(tester.takeException(), isNull);
  });
}
