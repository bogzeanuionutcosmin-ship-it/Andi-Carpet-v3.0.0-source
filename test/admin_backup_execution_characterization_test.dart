import 'dart:async';
import 'dart:convert';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/admin_ui_fixture.dart';
import 'support/admin_backup_fixture.dart';
import 'support/home_maintenance_fixture.dart';
import 'support/home_sync_fixture.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'support/synthetic_backup_store.dart';

void main() {
  late FirebasePlatform original;
  late NoFirebaseAccess sdk;
  setUp(() { original = FirebasePlatform.instance; sdk = NoFirebaseAccess(); FirebasePlatform.instance = sdk; });
  tearDown(() { expect(sdk.attempts, isEmpty); FirebasePlatform.instance = original; });
  Future<void> openManual(WidgetTester t) async {
    final b = find.widgetWithText(OutlinedButton, 'Restaurează backup');
    await t.ensureVisible(b); await t.tap(b); await t.pumpAndSettle();
  }
  Future<void> openAutomatic(WidgetTester t) async {
    final b = find.widgetWithText(OutlinedButton, 'Restaurează');
    await t.ensureVisible(b); await t.tap(b); await t.pumpAndSettle();
  }
  Future<void> accept(WidgetTester t) async {
    await t.tap(find.widgetWithText(FilledButton, 'Restaurează').last); await t.pumpAndSettle();
  }
  Map<String, dynamic> manualPayload(Map<String, dynamic> documents) =>
      {'format': 'AndiCarpetaBackupV1', 'collections': {'expenses': documents}};
  void automaticItems(AdminBackupHarness h, int count, {Map<String, dynamic>? meta}) {
    h.db.setDocument('backups/snapshot', meta ?? {'status': 'complete'});
    h.db.setQuery('backups/snapshot/items', List.generate(count, (i) => MaintenanceDoc(h.db,
      'backups/snapshot/items/i$i', {'collection': 'expenses', 'documentId': 'restored$i', 'data': {'amount': 200 + i}})));
  }

  testWidgets('partial automatic snapshot replaces only its present allowlisted collection and preserves omitted data', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.seed('perDiems/old', {'amount': 50});
    store.seed('locations/room', {'name': 'Synthetic'}); store.seed('users/a', {'role': 'member'});
    store.allowRead('expenses'); automaticItems(h, 1);
    await h.mount(t, latest: {'status': 'complete'}); await openAutomatic(t); await accept(t);
    expect(h.db.trace.where((e) => e.startsWith('get:')), ['get:backups/snapshot', 'get:backups/snapshot/items', 'get:expenses']);
    expect(h.db.commits.map((b) => b.length), [1, 1]);
    expect(store.data['expenses/old'], isNull); expect(store.data['expenses/restored0'], {'amount': 200});
    store.expectUnchanged('perDiems/old', {'amount': 50}); store.expectUnchanged('locations/room', {'name': 'Synthetic'});
    store.expectUnchanged('users/a', {'role': 'member'});
    expect(h.db.directWrites.single.path, 'meta/backup');
    expect(h.db.directWrites.single.data!['restoredAutomaticBackup'], 'snapshot');
    expect(h.ui.logs, hasLength(1)); await h.finish(t);
  });

  testWidgets('automatic duplicate-ID preflight rejects all data before collection reads or deletes', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.allowRead('expenses');
    h.db.setDocument('backups/snapshot', {'status': 'complete'});
    final item = {'collection': 'expenses', 'documentId': 'duplicate', 'data': {'amount': 200}};
    final before = jsonEncode(item);
    h.db.setQuery('backups/snapshot/items', [MaintenanceDoc(h.db, 'backups/snapshot/items/a', item), MaintenanceDoc(h.db, 'backups/snapshot/items/b', item)]);
    await h.mount(t, latest: {'status': 'complete'}); await openAutomatic(t); await accept(t);
    expect(h.db.trace, ['get:backups/snapshot', 'get:backups/snapshot/items']);
    expect(find.textContaining('Backup automat invalid. Nu s-au modificat date:'), findsOneWidget);
    expect(h.db.commitAttempts, isEmpty); expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty);
    expect(jsonEncode(item), before); store.expectUnchanged('expenses/old', {'amount': 999}); await h.finish(t);
  });

  testWidgets('KNOWN DEFECT: accepted manual unknown-only groups still write a success marker without operational data', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.seed('users/a', {'role': 'member'});
    h.files.file({'format': 'AndiCarpetaBackupV1', 'collections': {'users': {'a': {'role': 'admin'}}, 'visionJournal': {}}});
    await h.mount(t); await openManual(t); await accept(t);
    expect(h.db.trace, ['set:meta/backup']); expect(h.db.commitAttempts, isEmpty);
    expect(h.db.directWrites.single.data!['restoredFile'], 'synthetic.json');
    expect(h.ui.logs.single, startsWith('Backup restaurat:'));
    store.expectUnchanged('expenses/old', {'amount': 999}); store.expectUnchanged('users/a', {'role': 'member'});
    await h.finish(t);
  });

  testWidgets('KNOWN DEFECT: manual write failure after deletion has no rollback; explicit retry restores 400+1 documents', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.seed('perDiems/keep', {'amount': 50}); store.allowRead('expenses');
    final documents = {for (var i = 0; i < 401; i++) 'e$i': {'amount': i + 1}};
    final originalDocuments = jsonEncode(documents); h.files.file(manualPayload(documents));
    store.gate = (_) async { if (h.db.commitAttempts.length == 2) throw StateError('synthetic manual restore rejected'); };
    final errors = <Object>[];
    await runZonedGuarded<Future<void>>(() async { await h.mount(t); await openManual(t); await accept(t); }, (e, s) { errors.add(e); });
    expect(errors, hasLength(1)); expect(errors.single, isA<StateError>());
    expect(errors.single.toString(), contains('synthetic manual restore rejected'));
    expect(h.db.commitAttempts.map((b) => b.length), [1, 400]); expect(h.db.commits.single.single.operation, 'delete');
    expect(store.data.keys.where((k) => k.startsWith('expenses/')), isEmpty);
    expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty); expect(h.files.picks, 1);
    await t.pump(const Duration(seconds: 1)); expect(h.db.commitAttempts, hasLength(2));
    store.gate = null; await openManual(t); await accept(t);
    expect(h.files.picks, 2); expect(h.files.reads, 2);
    expect(h.db.commitAttempts.map((b) => b.length), [1, 400, 400, 1]);
    expect(h.db.commits.map((b) => b.length), [1, 400, 1]);
    expect(store.data.keys.where((k) => k.startsWith('expenses/')), hasLength(401));
    expect(store.data['expenses/e400'], {'amount': 401}); store.expectUnchanged('perDiems/keep', {'amount': 50});
    expect(h.db.directWrites, hasLength(1)); expect(h.ui.logs, hasLength(1));
    expect(jsonEncode(documents), originalDocuments); await h.finish(t);
  });

  testWidgets('KNOWN DEFECT: malformed JSON escapes the manual preflight catch with no database command', (t) async {
    final h = AdminBackupHarness(); h.files.raw('{broken'); final errors = <Object>[];
    await runZonedGuarded<Future<void>>(() async { await h.mount(t); await openManual(t); }, (e, s) { errors.add(e); });
    expect(errors, hasLength(1)); expect(errors.single, isA<FormatException>());
    expect(h.files.reads, 1); expect(find.byType(AlertDialog), findsNothing);
    h.expectNoCommand(); await h.finish(t);
  });

  testWidgets('KNOWN DEFECT: automatic final insert batch fails after deletions and eight replacements, without rollback', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.seed('locations/keep', {'name': 'Synthetic'}); store.allowRead('expenses');
    automaticItems(h, 9);
    store.gate = (_) async { if (h.db.commitAttempts.length == 3) throw StateError('synthetic automatic last batch rejected'); };
    await h.mount(t, latest: {'status': 'complete'}); await openAutomatic(t); await accept(t);
    expect(h.db.commitAttempts.map((b) => b.length), [1, 8, 1]); expect(h.db.commits.map((b) => b.length), [1, 8]);
    expect(store.data['expenses/old'], isNull); expect(store.data.keys.where((k) => k.startsWith('expenses/')), hasLength(8));
    expect(store.data.containsKey('expenses/restored8'), isFalse);
    store.expectUnchanged('locations/keep', {'name': 'Synthetic'});
    expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty);
    expect(find.textContaining('Restaurarea backup-ului automat a eșuat:'), findsOneWidget);
    await t.pump(const Duration(seconds: 1)); expect(h.db.commitAttempts, hasLength(3)); await h.finish(t);
  });

  testWidgets('KNOWN DEFECT: two concurrent manual restore handlers both proceed and write two success markers', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.allowRead('expenses'); h.files.file(manualPayload({'new': {'amount': 200}}));
    final gate = Completer<void>(); store.gate = (writes) => writes.first.operation == 'delete' ? gate.future : Future<void>.value();
    await h.mount(t);
    final b = find.widgetWithText(OutlinedButton, 'Restaurează backup');
    await t.ensureVisible(b);
    final handler = t.widget<OutlinedButton>(b).onPressed!;
    handler(); handler(); await t.pumpAndSettle(); // same real widget handler, before a modal frame blocks taps
    await accept(t); await accept(t);
    expect(h.files.picks, 2); expect(h.files.reads, 2);
    expect(h.db.commitAttempts.map((b) => b.single.path), ['expenses/old', 'expenses/old']);
    expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty);
    gate.complete(); await t.pumpAndSettle();
    expect(h.db.commits, hasLength(4)); expect(h.db.directWrites, hasLength(2)); expect(h.ui.logs, hasLength(2));
    expect(store.data, {'expenses/new': {'amount': 200}});
    expect(h.db.commits.expand((b) => b).where((w) => w.operation == 'set' && w.path == 'expenses/new'), hasLength(2));
    await h.finish(t);
  });

  testWidgets('KNOWN DEFECT: automatic complete snapshot ignores unknown future version metadata before replacing data', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.allowRead('expenses');
    final meta = {'status': 'complete', 'schemaVersion': 99, 'format': 'FutureAutomaticBackupV99'};
    automaticItems(h, 1, meta: meta); final originalMeta = jsonEncode(meta);
    await h.mount(t, latest: {'status': 'complete'}); await openAutomatic(t); await accept(t);
    expect(h.db.commits.map((b) => b.length), [1, 1]); expect(h.db.directWrites, hasLength(1));
    expect(store.data, {'expenses/restored0': {'amount': 200}}); expect(jsonEncode(meta), originalMeta);
    await h.finish(t);
  });
  testWidgets('KNOWN DEFECT: automatic items timeout escapes before preflight with zero destructive command', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.allowRead('expenses');
    h.db.setDocument('backups/snapshot', {'status': 'complete'});
    h.db.queryReads['backups/snapshot/items'] = () => Future<QuerySnapshot<Map<String, dynamic>>>.error(TimeoutException('synthetic item read timeout'));
    final errors = <Object>[];
    await runZonedGuarded<Future<void>>(() async {
      await h.mount(t, latest: {'status': 'complete'}); await openAutomatic(t); await accept(t);
    }, (error, stack) { errors.add(error); });
    expect(errors, hasLength(1)); expect(errors.single, isA<TimeoutException>());
    expect(errors.single.toString(), contains('synthetic item read timeout'));
    expect(h.db.trace, ['get:backups/snapshot', 'get:backups/snapshot/items']);
    expect(h.db.commitAttempts, isEmpty); expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty);
    store.expectUnchanged('expenses/old', {'amount': 999}); await h.finish(t);
  });

  testWidgets('KNOWN DEFECT: automatic restore continues deletes writes and marker after Admin page disposal', (t) async {
    final h = AdminBackupHarness(); final store = SyntheticBackupStore(h.db);
    store.seed('expenses/old', {'amount': 999}); store.seed('perDiems/keep', {'amount': 50}); store.allowRead('expenses');
    h.db.setDocument('backups/snapshot', {'status': 'complete'});
    final items = Completer<QuerySnapshot<Map<String, dynamic>>>();
    h.db.queryReads['backups/snapshot/items'] = () => items.future;
    await h.mount(t, latest: {'status': 'complete'}); await openAutomatic(t); await accept(t);
    expect(h.db.commitAttempts, isEmpty); expect(h.db.trace, ['get:backups/snapshot', 'get:backups/snapshot/items']);
    await t.pumpWidget(const SizedBox()); expect(h.db.streams.activeCount, 0);
    items.complete(HomeFixtureSnapshot([MaintenanceDoc(h.db, 'backups/snapshot/items/e',
      {'collection': 'expenses', 'documentId': 'new', 'data': {'amount': 200}})]));
    await t.pumpAndSettle();
    expect(h.db.commits.map((b) => b.length), [1, 1]);
    expect(store.data['expenses/old'], isNull); expect(store.data['expenses/new'], {'amount': 200});
    store.expectUnchanged('perDiems/keep', {'amount': 50});
    expect(h.db.directWrites.single.path, 'meta/backup'); expect(h.ui.logs, hasLength(1));
    expect(find.text('Backup-ul automat a fost restaurat. Datele se resincronizează.'), findsNothing);
    await h.finish(t);
  });

}
