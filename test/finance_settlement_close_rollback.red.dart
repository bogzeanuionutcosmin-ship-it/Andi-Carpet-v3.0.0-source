// Historical #44 RED witness: unchanged assertions now require GREEN for an explicit before-write rejection.
// This intentionally proves that a failed settlement close leaves endDate
// mutated while closed is rolled back. Synthetic data only; no Firebase calls.
// Kept outside *_test.dart so regular flutter test test/ stays green.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';
import 'support/expense_document_fixture.dart';

void main() {
  testWidgets('failed close must not keep an endDate', (tester) async {
    final fixture = ExpenseDocumentFixture('SYNTHETIC DOCUMENT');
    TravelSettlement? attempted;
    var writes = 0;
    fixture.saveSettlementOverride = (settlement) async {
      writes++;
      attempted = settlement;
      throw FinanceSaveRejected('synthetic rejected before persistence');
    };

    await fixture.mount(tester);
    final closeAction = find.text('Închide decontul');
    await tester.ensureVisible(closeAction);
    await tester.tap(closeAction);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Închide'));
    await tester.pumpAndSettle();

    expect(writes, 1, reason: 'One user action must attempt exactly one save');
    expect(attempted, isNotNull);
    // Already rolled back by current catch block.
    expect(attempted!.closed, isFalse);
    // KNOWN RED: _toggleSettlementClosed sets endDate before save and the
    // catch block restores closed only, leaving an unsaved endDate in memory.
    expect(attempted!.endDate, isNull, reason: 'END_DATE_ROLLBACK_MISSING');
  });
}
