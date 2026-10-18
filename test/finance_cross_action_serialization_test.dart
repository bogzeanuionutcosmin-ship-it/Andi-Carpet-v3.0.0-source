import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/ui/money_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/settlement_edit_probe.dart';

void main() {
  for (final primary in ['edit', 'close', 'receipt']) {
    for (final rejected in [false, true]) {
      testWidgets('$primary pending rejected=$rejected excludes other settlement writers', (tester) async {
        var saves = 0; final gate = Completer<void>();
        final fixture = ExpenseDocumentFixture('');
        fixture.saveSettlementOverride = (_) async { saves++; await gate.future; if (rejected) throw FinanceSaveRejected('before write'); };
        await fixture.mount(tester);
        final original = currentSettlement(tester); final before = settlementFields(original);
        final edit = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Editează deplasarea')).onPressed!;
        final close = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Închide decontul')).onPressed!;
        final receipt = tester.widget<MoneyCard>(find.widgetWithText(MoneyCard, 'Primit la plecare')).onTap!;
        if (primary == 'edit') {
          edit(); await tester.pumpAndSettle(); await fixture.enter(tester, 'Denumire', 'Synthetic edit');
          await tester.tap(find.text('Salvează'));
        } else if (primary == 'close') {
          close(); await tester.pumpAndSettle(); await tester.tap(find.widgetWithText(FilledButton, 'Închide'));
        } else {
          receipt(); await tester.pumpAndSettle();
          await fixture.enter(tester, 'Valoare', '200'); await fixture.enter(tester, 'De la cine', 'Synthetic payer');
          await tester.tap(find.text('Adaugă'));
        }
        await tester.pumpAndSettle(); expect(saves, 1); final attempted = settlementFields(original);
        // Captured real callbacks deliberately bypass hit testing/disabled cards.
        edit(); close(); receipt(); await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing); expect(saves, 1);
        expect(settlementFields(original), attempted); expect(fixture.logs, isEmpty);
        gate.complete(); await tester.pumpAndSettle();
        expect(settlementFields(original), rejected ? before : attempted);
        expect(fixture.logs.length, rejected ? 0 : 1); expect(saves, 1);
        // A separate later action must be possible: the key was released.
        edit(); await tester.pumpAndSettle(); expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
        expect(saves, 1); expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('duplicate create entrypoint cannot open two dialogs or create twice', (tester) async {
    var saves = 0; final gate = Completer<void>();
    final fixture = ExpenseDocumentFixture(''); fixture.saveSettlementOverride = (_) async { saves++; await gate.future; };
    await fixture.mount(tester);
    await tester.ensureVisible(find.text('Nouă'));
    final create = tester.widget<FilledButton>(find.ancestor(of: find.text('Nouă'), matching: find.byWidgetPredicate((w) => w is FilledButton)).first).onPressed!;
    create(); create(); await tester.pumpAndSettle(); expect(find.byType(AlertDialog), findsOneWidget);
    await fixture.enter(tester, 'Denumire', 'Synthetic creation');
    final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Creează'));
    confirm.onPressed!(); confirm.onPressed!(); await tester.pumpAndSettle();
    create(); await tester.pumpAndSettle(); expect(find.byType(AlertDialog), findsNothing); expect(saves, 1);
    gate.complete(); await tester.pumpAndSettle(); expect(saves, 1); expect(fixture.logs, hasLength(1));
    create(); await tester.pumpAndSettle(); expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Anulează')); await tester.pumpAndSettle();
    expect(saves, 1); expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });
}
