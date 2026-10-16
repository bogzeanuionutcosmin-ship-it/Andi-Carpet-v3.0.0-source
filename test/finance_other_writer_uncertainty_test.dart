import 'dart:async';
import 'dart:convert';
import 'package:andi_carpeta/main.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/admin_backup_fixture.dart';
import 'support/admin_ui_fixture.dart';
import 'support/expense_document_fixture.dart';
import 'support/finance_uncertain_store.dart';
import 'support/home_maintenance_fixture.dart';
import 'support/synthetic_backup_store.dart';

Future<void> submitReceipt(WidgetTester t, ExpenseDocumentFixture fixture) async {
  await t.ensureVisible(find.text('Primit la plecare')); await t.tap(find.text('Primit la plecare'));
  await t.pumpAndSettle(); await fixture.enter(t, 'Valoare', '200');
  await fixture.enter(t, 'De la cine', 'Synthetic payer');
  await t.tap(find.widgetWithText(FilledButton, 'Adaugă')); await t.pumpAndSettle();
}
Map<String, dynamic> jsonEvidence(Map<String, Object?> value) => Map<String, dynamic>.from(
  jsonDecode(jsonEncode(value, toEncodable: (v) => (v as DateTime).toIso8601String())) as Map);

void main() {
  late FirebasePlatform original; late NoFirebaseAccess sdk;
  final unexpectedHttp = <String>[];
  var clientCreations = 0;
  final noNetwork = MockClient((request) async {
    unexpectedHttp.add(request.url.toString());
    throw StateError('Unexpected HTTP in synthetic finance fixture');
  });
  tearDownAll(() {
    expect(clientCreations, 1, reason: 'Real Admin dashboard initialized its Mapbox client');
    expect(unexpectedHttp, isEmpty, reason: 'No HTTP or paid service boundary may be reached');
    noNetwork.close();
  });
  setUp(() { original = FirebasePlatform.instance; sdk = NoFirebaseAccess(); FirebasePlatform.instance = sdk; });
  tearDown(() { expect(sdk.attempts, isEmpty); FirebasePlatform.instance = original; });
  for (final legacy in [false, true]) {
    for (final receiptLast in [false, true]) {
      testWidgets('REGRESSION financial Admin restore is blocked versus pending receipt legacy=$legacy receiptLast=$receiptLast', (t) => http.runWithClient(() async {
        final pending = FinanceUncertainStore(); final fixture = ExpenseDocumentFixture('');
        fixture.legacyFinance = legacy;
        fixture.saveSettlementOverride = (s) => pending.save(s);
        fixture.saveFinanceOverride = (f) => pending.save(f);
        await fixture.mount(t); await submitReceipt(t, fixture);
        expect(pending.writes, hasLength(1)); final write = pending.writes.single;
        final collection = legacy ? 'finance' : 'settlements';
        expect(write.documentKey, legacy ? 'finance/team' : 'settlements/settlement');
        final payload = jsonEvidence(write.payload);
        await t.pumpWidget(const SizedBox());
        final h = AdminBackupHarness(); final durable = SyntheticBackupStore(h.db);
        final snapshot = <String, dynamic>{'departure': 75, 'during': 0, 'entries': <dynamic>[], 'name': 'Historical snapshot'};
        durable.seed(write.documentKey, {'departure': 0}); durable.allowRead(collection);
        h.db.setDocument('backups/snapshot', {'status': 'complete'});
        h.db.setQuery('backups/snapshot/items', [MaintenanceDoc(h.db, 'backups/snapshot/items/one', {
          'collection': collection, 'documentId': write.documentKey.split('/').last, 'data': snapshot,
        })]);
        if (!receiptLast) durable.seed(write.documentKey, payload);
        await h.mount(t, latest: {'status': 'complete'});
        final restore = find.widgetWithText(OutlinedButton, 'Restaurează');
        await t.ensureVisible(restore); await t.tap(restore); await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, 'Restaurează').last); await t.pumpAndSettle();
        // Previously this exact handler committed delete+set and could erase
        // the receipt. The fail-closed gate now refuses the ENTIRE snapshot.
        expect(find.textContaining('Backup-ul financiar necesită un manifest'), findsOneWidget);
        expect(h.db.commitAttempts, isEmpty); expect(h.db.commits, isEmpty);
        expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty);
        expect(durable.data[write.documentKey], receiptLast ? {'departure': 0} : payload);
        if (receiptLast) durable.seed(write.documentKey, payload);
        pending.acknowledge(0, error: TimeoutException('synthetic lost acknowledgement'));
        await t.pumpAndSettle();
        expect(durable.data[write.documentKey], payload);
        expect(fixture.logs, isEmpty); expect(pending.writes, hasLength(1));
        // Actual Admin refusal and actual ExpensePage submission; receipt
        // completion remains synthetic. No full restore/SDK certification.
        await h.finish(t);
      }, () { clientCreations++; return noNetwork; }));
    }
    testWidgets('late commit after receipt timeout legacy=$legacy does not trigger an automatic second call', (t) async {
      final store = FinanceUncertainStore(); final fixture = ExpenseDocumentFixture('');
      fixture.legacyFinance = legacy;
      fixture.saveSettlementOverride = (s) => store.save(s); fixture.saveFinanceOverride = (f) => store.save(f);
      await fixture.mount(t); await submitReceipt(t, fixture);
      store.acknowledge(0, error: TimeoutException('synthetic unknown outcome'));
      await t.pumpAndSettle(); expect(store.durable, isNull); expect(fixture.logs, isEmpty);
      store.commit(0); await t.pump(const Duration(seconds: 30));
      expect(store.durable, store.writes.single.payload); expect(store.writes, hasLength(1));
      expect(fixture.logs, isEmpty); expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
    });
  }
  for (final committed in [false, true]) {
    testWidgets('edit timeout committed=$committed preserves unknown result without retry', (t) async {
      final store = FinanceUncertainStore(); final fixture = ExpenseDocumentFixture('');
      fixture.saveSettlementOverride = (s) => store.save(s); await fixture.mount(t);
      final model = t.widget<ExpensePage>(find.byType(ExpensePage)).settlements.single;
      final before = financeEvidence(model); store.durable = before;
      await t.ensureVisible(find.text('Editează deplasarea')); await t.tap(find.text('Editează deplasarea'));
      await t.pumpAndSettle(); await fixture.enter(t, 'Denumire', 'Synthetic uncertain edit');
      await t.tap(find.text('Salvează')); await t.pumpAndSettle(); final attempted = financeEvidence(model);
      if (committed) store.commit(0);
      store.acknowledge(0, error: TimeoutException('synthetic unknown edit'));
      await t.pumpAndSettle(); expect(financeEvidence(model), attempted);
      expect(store.durable, committed ? attempted : before); expect(fixture.logs, isEmpty);
      expect(store.writes, hasLength(1)); expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets('KNOWN UNSAFE manual recreation after unknown create uses a different document ID', (t) async {
    final store = FinanceUncertainStore(); final fixture = ExpenseDocumentFixture('');
    fixture.saveSettlementOverride = (s) => store.save(s); await fixture.mount(t);
    for (var i = 0; i < 2; i++) {
      await t.ensureVisible(find.text('Nouă')); await t.tap(find.text('Nouă')); await t.pumpAndSettle();
      await fixture.enter(t, 'Denumire', 'Same synthetic trip intent');
      await t.tap(find.text('Creează')); await t.pumpAndSettle();
      expect(store.writes, hasLength(i + 1));
      store.commit(i); store.acknowledge(i, error: TimeoutException('synthetic unknown create'));
      await t.pumpAndSettle(); expect(fixture.logs, isEmpty);
    }
    expect(store.writes.first.documentKey, isNot(store.writes.last.documentKey));
    expect(store.writes.first.payload['name'], store.writes.last.payload['name']);
    expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
  });
}
