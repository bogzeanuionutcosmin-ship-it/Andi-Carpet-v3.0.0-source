import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

void main() {
  testWidgets('director read-only permission does not expose settlement mutations', (tester) async {
    var saves = 0;
    final fixture = ExpenseDocumentFixture('')
      ..readOnlyDirector = true
      ..saveSettlementOverride = (_) async { saves++; }
      ..saveFinanceOverride = (_) async { saves++; };
    await fixture.mount(tester);
    expect(find.text('Nouă'), findsNothing);
    expect(find.text('Editează deplasarea'), findsNothing);
    expect(find.text('Închide decontul'), findsNothing);
    for (final label in ['Primit la plecare', 'Primit în timpul deplasării']) {
      await tester.ensureVisible(find.text(label)); await tester.tap(find.text(label));
      await tester.pumpAndSettle(); expect(find.byType(AlertDialog), findsNothing);
    }
    expect(saves, 0); expect(fixture.logs, isEmpty); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
