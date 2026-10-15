// Issue #42: positive control for the existing successful close flow.
// No production data, Firebase calls, code changes or reinterpretation of money.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';
import 'support/expense_document_fixture.dart';

void main() {
  testWidgets('successful settlement close writes closed and endDate once', (tester) async {
    final fixture = ExpenseDocumentFixture('SYNTHETIC DOCUMENT');
    TravelSettlement? saved;
    var writes = 0;
    fixture.saveSettlementOverride = (settlement) async {
      writes++;
      saved = settlement;
    };

    await fixture.mount(tester);
    final closeAction = find.text('Închide decontul');
    await tester.ensureVisible(closeAction);
    await tester.tap(closeAction);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Închide'));
    await tester.pumpAndSettle();

    expect(writes, 1);
    expect(saved, isNotNull);
    expect(saved!.closed, isTrue);
    expect(saved!.endDate, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
