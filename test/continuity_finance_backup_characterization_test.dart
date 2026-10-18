import 'dart:async';
import 'package:andi_carpeta/admin/backup_codec.dart';
import 'package:andi_carpeta/finance/per_diem_money.dart';
import 'package:andi_carpeta/finance/per_diem_payment_plan.dart';
import 'package:andi_carpeta/home/home_retention_queries.dart';
import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_maintenance_fixture.dart';
import 'support/home_sync_fixture.dart';

void main() {
  testWidgets('same UID and key rebuilds retain Home state and do not restart SDK effects or listeners', (tester) async {
    final db = HomeSyncFixture(); addTearDown(db.close);
    final settings = AppSettings()..autoCloseWhenAllDone = false;
    Future<void> mount() => tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db,
      settings: settings)));
    await mount();
    final dynamic old = tester.state(find.byType(FixtureHomePage)); old.tab = 3;
    db.emit('memberDirectory', 'a', {'name': 'Same UID synthetic', 'active': true});
    db.emit('cars', 'car', {'plate': 'RETAINED'});
    await flushHomeFixture(tester);
    final starts = Map<String, int>.from(db.starts);
    for (var i = 0; i < 12; i++) { await mount(); }
    final dynamic next = tester.state(find.byType(FixtureHomePage));
    expect(identical(next, old), isTrue); expect(next.tab, 3);
    expect(next.me.name, 'Same UID synthetic'); expect(next.cars.single.plate, 'RETAINED');
    expect(db.starts, starts);
    expect(db.trace.where((s) => s == 'effect:location').length, 1);
    expect(db.trace.where((s) => s == 'effect:push').length, 1);
    db.emit('cars', 'car', {'plate': 'UPDATED'}); await flushHomeFixture(tester);
    expect(next.cars.single.plate, 'UPDATED');
    await tester.pumpWidget(const SizedBox());
    expect(db.activeCount, 0); expect(tester.takeException(), isNull);
  });

  testWidgets('loss of own team clears all financial lists and cancels four scoped subscriptions', (tester) async {
    final db = HomeSyncFixture(); addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: FixtureHomePage(
      key: const ValueKey('a'), profile: fixtureHomeProfile('a'), fixture: db)));
    final dynamic state = tester.state(find.byType(FixtureHomePage));
    db.emit('teams', 't', {'members': ['a'], 'name': 'Synthetic'});
    await flushHomeFixture(tester);
    for (final collection in ['expenses', 'perDiems', 'finance', 'settlements']) {
      db.emit('$collection[where:teamId=t]', 'one', {'teamId': 't', 'amount': 200});
    }
    await flushHomeFixture(tester);
    expect(state.expenses.length, 1); expect(state.perDiems.length, 1);
    expect(state.finances.length, 1); expect(state.settlements.length, 1);
    db.query('teams').add(HomeFixtureSnapshot([])); await flushHomeFixture(tester);
    expect(state.me.teamId, isNull);
    expect(state.expenses, isEmpty); expect(state.perDiems, isEmpty);
    expect(state.finances, isEmpty); expect(state.settlements, isEmpty);
    for (final collection in ['expenses', 'perDiems', 'finance', 'settlements']) {
      expect(db.active['$collection[where:teamId=t]'], 0);
      db.emit('$collection[where:teamId=t]', 'late', {'teamId': 't', 'amount': 999});
    }
    await flushHomeFixture(tester);
    expect(state.expenses, isEmpty); expect(state.perDiems, isEmpty);
    expect(state.finances, isEmpty); expect(state.settlements, isEmpty);
    await tester.pumpWidget(const SizedBox()); expect(db.activeCount, 0);
    expect(tester.takeException(), isNull);
    // Normal broadcast cancellation only; not adversarial epochs or server authorization.
  });

  test('existing monetary parser accepts 200 variants and explicitly rejects thousands grouping', () {
    for (final input in ['200', '200.00', '200,00', ' 200,0 ']) {
      expect(parseLeiToBani(input), 20000);
    }
    for (final input in ['1.234,56', '1,234.56', '1 234,56', '200.001', 'NaN', '2e2']) {
      expect(() => parseLeiToBani(input), throwsFormatException);
    }
    expect(formatBani(20000), '200,00 lei');
    // This is the existing v2 helper contract, not OCR or the private expense dialog.
  });

  test('one ban remains exact and a proposed payment may create an advance without counting pending money', () {
    expect(parseLeiToBani('200.01') - parseLeiToBani('200,00'), 1);
    final plan = PerDiemPaymentPlan(dueBani: 20000, confirmedPaidBani: 0,
      pendingBani: 99999, newEntitlementBani: 0, proposedPaymentBani: 30001);
    expect(plan.currentOutstandingBani, 20000); expect(plan.currentAdvanceBani, 0);
    expect(plan.recommendedPaymentBani, 20000);
    expect(plan.expectedOutstandingBani, 0); expect(plan.expectedAdvanceBani, 10001);
  });

  test('backup decoding preserves unknown schema markers and builds independent nested containers', () {
    final raw = <String, dynamic>{'__type': 'future-schema',
      'nested': <dynamic>[<String, dynamic>{'amount': 200, 'nullable': null}]};
    final decoded = decodeBackupValue(raw) as Map;
    expect(decoded, raw); expect(identical(decoded, raw), isFalse);
    final nested = decoded['nested'] as List;
    (nested.single as Map)['amount'] = 201;
    expect(((raw['nested'] as List).single as Map)['amount'], 200);
    expect(decoded['__type'], 'future-schema');
    // Unknown markers are preserved, not a validated restore schema.
  });

  test('malformed recognized backup markers fail instead of silently inventing usable data', () {
    expect(() => decodeBackupValue({'__type': 'timestamp', 'value': 'not-a-date'}), throwsFormatException);
    expect(() => decodeBackupValue({'__type': 'geopoint', 'lat': 'not-numeric', 'lng': 0}), throwsA(isA<TypeError>()));
    expect(() => decodeBackupValue({'nested': [{'__type': 'timestamp', 'value': 'invalid'}]}), throwsFormatException);
  });

  test('overlapping retention reads finish independently in reverse order without caching or writes', () async {
    final db = HomeMaintenanceFixture();
    final first = Completer<QuerySnapshot<Map<String, dynamic>>>();
    final second = Completer<QuerySnapshot<Map<String, dynamic>>>(); var reads = 0;
    db.queryReads['notifications[before:createdAt]'] = () => ++reads == 1 ? first.future : second.future;
    final queries = HomeRetentionQueries.fromFirestore(db);
    final a = queries.notificationsBefore(Timestamp(10, 0)).get();
    final b = queries.notificationsBefore(Timestamp(20, 0)).get();
    final newer = MaintenanceDoc(db, 'notifications/newer', {});
    second.complete(HomeFixtureSnapshot([newer]));
    expect(identical((await b).docs.single, newer), isTrue);
    final older = MaintenanceDoc(db, 'notifications/older', {});
    first.complete(HomeFixtureSnapshot([older]));
    expect(identical((await a).docs.single, older), isTrue);
    expect(reads, 2); expect(db.trace, ['get:notifications[before:createdAt]', 'get:notifications[before:createdAt]']);
    expect(db.directWrites, isEmpty); expect(db.commits, isEmpty); expect(db.unexpected, isEmpty);
  });
}
