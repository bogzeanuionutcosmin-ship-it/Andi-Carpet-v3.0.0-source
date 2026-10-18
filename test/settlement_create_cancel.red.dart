// STRICT RED lifecycle expectation. Cancel must perform no save.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

void main() {
  testWidgets('settlement create cancel must finish transition without disposed controller', (tester) async {
    var saves = 0;
    final fixture = ExpenseDocumentFixture('')..saveSettlementOverride = (_) async { saves++; };
    await fixture.mount(tester);
    await tester.ensureVisible(find.text('Nouă')); await tester.tap(find.text('Nouă'));
    await tester.pumpAndSettle();
    expect(find.text('Deplasare nouă'), findsOneWidget);
    await fixture.enter(tester, 'Denumire', 'Synthetic cancelled trip');
    await tester.tap(find.widgetWithText(TextButton, 'Anulează'));
    await tester.pumpAndSettle();
    expect(saves, 0); expect(fixture.logs, isEmpty);
    debugPrint('CREATE_CANCEL_PRECONDITIONS_PASS');
    expect(tester.takeException(), isNull, reason: 'CREATE_DIALOG_CANCEL_LIFECYCLE_BROKEN');
    await tester.pumpWidget(const SizedBox());
  });
}
