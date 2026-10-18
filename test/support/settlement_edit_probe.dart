import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'expense_document_fixture.dart';

// Uses the real ExpensePage and its original mutable settlement. No copy of the
// save orchestration or automatic rollback is implemented by this test helper.
TravelSettlement currentSettlement(WidgetTester tester) =>
    tester.widget<ExpensePage>(find.byType(ExpensePage)).settlements.single;

Map<String, Object?> settlementFields(TravelSettlement s) => {
  'name': s.name, 'startDate': s.startDate, 'endDate': s.endDate,
  'closed': s.closed, 'managerId': s.managerId,
  'receivedDeparture': s.receivedDeparture, 'receivedDuring': s.receivedDuring,
  'receivedCount': s.receivedEntries.length,
};

Future<void> submitSyntheticEdit(WidgetTester tester, ExpenseDocumentFixture fixture) async {
  await tester.ensureVisible(find.text('Editează deplasarea'));
  await tester.tap(find.text('Editează deplasarea'));
  await tester.pumpAndSettle();
  await fixture.enter(tester, 'Denumire', 'Synthetic revised trip');
  final clearEnd = find.descendant(of: find.byType(AlertDialog), matching: find.byIcon(Icons.clear));
  expect(clearEnd, findsOneWidget);
  await tester.tap(clearEnd); await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Salvează'));
  // save is deliberately held pending by the caller until the closing route
  // finishes. This separates model state from the controller transition hazard.
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
}
