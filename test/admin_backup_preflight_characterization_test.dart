import 'dart:convert';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/admin_ui_fixture.dart';
import 'support/admin_backup_fixture.dart';

void main() {
  late FirebasePlatform original;
  late NoFirebaseAccess sdk;
  setUp(() { original = FirebasePlatform.instance; sdk = NoFirebaseAccess(); FirebasePlatform.instance = sdk; });
  tearDown(() { expect(sdk.attempts, isEmpty); FirebasePlatform.instance = original; });
  Future<void> manual(WidgetTester tester) async {
    final b = find.widgetWithText(OutlinedButton, 'Restaurează backup');
    await tester.ensureVisible(b); await tester.tap(b); await tester.pumpAndSettle();
  }
  Future<void> automatic(WidgetTester tester) async {
    final b = find.widgetWithText(OutlinedButton, 'Restaurează');
    await tester.ensureVisible(b); await tester.tap(b); await tester.pumpAndSettle();
  }

  testWidgets('manual picker cancel leaves panel subscriptions unchanged and performs zero reads or writes', (tester) async {
    final h = AdminBackupHarness(); await h.mount(tester);
    final starts = Map<String, int>.from(h.db.streams.starts);
    await manual(tester);
    expect(h.files.picks, 1); expect(h.files.reads, 0);
    expect(h.db.streams.starts, starts); expect(h.db.streams.activeCount, 2);
    expect(find.byType(AlertDialog), findsNothing); h.expectNoCommand(); await h.finish(tester);
  });

  testWidgets('future manual format is rejected before confirmation or database commands', (tester) async {
    final h = AdminBackupHarness();
    h.files.file({'format': 'AndiCarpetaBackupV2', 'collections': {'expenses': {'e': {'amount': 200}}}});
    await h.mount(tester); await manual(tester);
    expect(h.files.picks, 1); expect(h.files.reads, 1);
    expect(find.text('Fișierul nu este un backup Andi Carpetă valid.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing); h.expectNoCommand(); await h.finish(tester);
  });

  testWidgets('valid financial and room preflight then confirmation cancel does not read or delete live collections', (tester) async {
    final h = AdminBackupHarness();
    final payload = {'format': 'AndiCarpetaBackupV1', 'collections': {
      'expenses': {'e': {'amount': 200}}, 'perDiems': {'d': {'amount': 50}}, 'locations': {'l': {'name': 'Synthetic Room'}},
    }, 'uiSettings': {'defaultPerDiem': 50}};
    final originalPayload = jsonEncode(payload); h.files.file(payload);
    await h.mount(tester); await manual(tester);
    expect(find.text('Restaurare backup'), findsOneWidget);
    expect(h.files.reads, 1); h.expectNoCommand();
    await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
    expect(jsonEncode(payload), originalPayload); h.expectNoCommand(); await h.finish(tester);
  });

  testWidgets('unknown manual groups are ignored in preflight and cancel cannot mutate users or journal', (tester) async {
    final h = AdminBackupHarness(); h.files.file({'format': 'AndiCarpetaBackupV1', 'collections': {'users': {'a': {'role': 'admin'}}, 'visionJournal': {}}});
    await h.mount(tester); await manual(tester);
    expect(find.text('Restaurare backup'), findsOneWidget);
    await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
    h.expectNoCommand(); await h.finish(tester);
  });

  testWidgets('invalid document ID rejects entire manual preflight before any confirmation or command', (tester) async {
    final h = AdminBackupHarness(); h.files.file({'format': 'AndiCarpetaBackupV1', 'collections': {
      'expenses': {'valid': {'amount': 200}}, 'locations': {'invalid/id': {'name': 'Synthetic'}},
    }});
    await h.mount(tester); await manual(tester);
    expect(find.textContaining('Backup invalid. Nu s-au modificat date:'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing); h.expectNoCommand(); await h.finish(tester);
  });

  testWidgets('automatic confirmation cancel happens before snapshot get or item reads', (tester) async {
    final h = AdminBackupHarness(); await h.mount(tester, latest: {'status': 'complete', 'documentCount': 3});
    await automatic(tester);
    expect(find.text('Restaurează backup-ul automat?'), findsOneWidget); h.expectNoCommand();
    await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
    expect(h.files.picks, 0); h.expectNoCommand(); await h.finish(tester);
  });

  testWidgets('stale complete panel cannot bypass authoritative failed snapshot status', (tester) async {
    final h = AdminBackupHarness(); h.db.setDocument('backups/snapshot', {'status': 'failed'});
    await h.mount(tester, latest: {'status': 'complete'}); await automatic(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Restaurează')); await tester.pumpAndSettle();
    expect(h.db.trace, ['get:backups/snapshot']);
    expect(find.text('Backup-ul selectat nu este complet.'), findsOneWidget);
    expect(h.db.commitAttempts, isEmpty); expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty);
    await h.finish(tester);
  });

  testWidgets('export file cancel performs ordered reads but no export success marker', (tester) async {
    final h = AdminBackupHarness(); h.db.setDocument('meta/uiSettings', {'theme': 'light'});
    const names = ['teams','cars','locations','locationCategories','functions','schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit','learningEvents','backgrounds'];
    for (final name in names) { h.db.setQuery(name, []); }
    await h.mount(tester);
    final b = find.widgetWithText(FilledButton, 'Exportă backup');
    await tester.ensureVisible(b); await tester.tap(b); await tester.pumpAndSettle();
    expect(h.db.trace, ['get:meta/uiSettings', ...names.map((n) => 'get:$n')]);
    expect(h.files.exports.length, 1); expect(h.files.picks, 0);
    final data = jsonDecode(utf8.decode(h.files.exports.single.bytes)) as Map;
    expect(data['format'], 'AndiCarpetaBackupV1'); expect((data['collections'] as Map).keys.toList(), names);
    expect(h.db.commitAttempts, isEmpty); expect(h.db.directWrites, isEmpty); expect(h.ui.logs, isEmpty);
    await h.finish(tester);
  });
}
