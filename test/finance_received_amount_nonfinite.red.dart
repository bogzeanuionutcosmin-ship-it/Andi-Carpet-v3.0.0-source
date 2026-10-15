// KNOWN RED / TEST ONLY — no business logic or Firestore rules changes.
//
// Characterization of the *real* receipt dialog on the Vision/AuthGate baseline.
// A non-finite number must never be accepted as a received cash amount.
// The test deliberately remains RED until an authorized financial fix.
// It is not included in the ordinary test/*_test.dart discovery pattern.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

void main() {
  testWidgets('NaN received amount must not invoke settlement save', (tester) async {
    var saves = 0;
    final fixture = ExpenseDocumentFixture('synthetic OCR not used')
      ..saveSettlementOverride = (_) async { saves++; };
    await fixture.mount(tester);

    await tester.ensureVisible(find.text('Primit la plecare'));
    await tester.tap(find.text('Primit la plecare'));
    await tester.pumpAndSettle();

    // Pasting can bypass a numeric keyboard: test the final parser, not the IME.
    await fixture.enter(tester, 'Valoare', 'NaN');
    await fixture.enter(tester, 'De la cine', 'Synthetic payer');
    await tester.tap(find.widgetWithText(FilledButton, 'Adaugă'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    // The expected correct result is zero writes and the dialog still open.
    // On the current baseline double.tryParse('NaN') returns NaN, while
    // amount <= 0 is false. This distinct failure marker is required by CI.
    expect(saves, 0, reason: 'NON_FINITE_AMOUNT_ACCEPTED_NAN');
    expect(find.text('Adaugă sumă primită la plecare'), findsOneWidget);
  });
}
