import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';

void main() {
  for (final save in [true, false]) {
    testWidgets('correction dialog ${save ? "saves" : "cancels"} without disposing active fields', (tester) async {
      final original = CentralizerRecord(
        id: 'record', teamId: 'craiova', locationId: 'room',
        type: LocationType.magic, locationNameSnapshot: 'Sala test',
        addressSnapshot: 'Craiova', startedAt: DateTime(2026, 10, 16, 10),
        finishedAt: DateTime(2026, 10, 16, 11), status: WorkAttemptStatus.completed,
      );
      CentralizerRecord? corrected;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CentralizerPage(
        currentUser: AppUser(id: 'admin', name: 'Admin', role: UserRole.director),
        teams: [Team(id: 'craiova', name: 'Craiova', members: ['admin'])],
        locations: [], categories: [], schedules: [], records: [original],
        isAdmin: true, canEditTeam: (_) => true, canEditCentralizer: true,
        onChanged: () {}, log: (_, __) {}, saveRecord: (_) async { fail('correction must not add a record'); },
        correctRecord: (before, after) async {
          expect(identical(before, original), isTrue);
          corrected = after;
        },
      ))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sala test'));
      await tester.tap(find.text('Sala test'));
      await tester.pumpAndSettle();
      final edit = find.byTooltip('Corectează data, orele și fațada');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Corectează intervenția'), findsOneWidget);
      final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '09:15');
      await tester.enterText(fields.at(1), '10:45');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(save ? 'Salvează' : 'Anulează'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      if (save) {
        expect(corrected, isNotNull);
        expect(corrected!.id, original.id);
        expect(corrected!.teamId, original.teamId);
        expect(corrected!.locationId, original.locationId);
        expect(corrected!.startedAt, DateTime(2026, 10, 16, 9, 15));
        expect(corrected!.finishedAt, DateTime(2026, 10, 16, 10, 45));
        expect(corrected!.facadeDone, isTrue);
      } else {
        expect(corrected, isNull);
      }
    });
  }
}
