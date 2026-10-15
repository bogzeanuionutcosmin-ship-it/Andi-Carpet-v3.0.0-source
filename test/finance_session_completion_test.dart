import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/settlement_edit_probe.dart';

void main() {
  for (final kind in ['create', 'edit', 'money', 'legacy-money', 'close']) {
    for (final reject in [false, true]) {
      for (final returnToA in [false, true]) {
        testWidgets('$kind delayed reject=$reject A-B-A2=$returnToA cannot affect successor', (tester) async {
          var saves = 0;
          final gate = Completer<void>();
          Future<void> save() async {
            saves++; await gate.future;
            if (reject) throw StateError('PRIVATE_OLD_A_FAILURE');
          }
          final first = ExpenseDocumentFixture('', userId: 'A')
            ..legacyFinance = kind == 'legacy-money'
            ..saveSettlementOverride = (_) => save()
            ..saveFinanceOverride = (_) => save();
          await first.mount(tester);
          final originalState = tester.state(find.byType(ExpensePage));
          final label = kind == 'create' ? 'Nouă' : kind == 'edit' ? 'Editează deplasarea' : kind == 'close' ? 'Închide decontul' : 'Primit la plecare';
          await tester.ensureVisible(find.text(label)); await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          if (kind.endsWith('money')) {
            await first.enter(tester, 'Valoare', '321.09'); await first.enter(tester, 'De la cine', 'PRIVATE_OLD_A_PAYER');
          } else if (kind != 'close') {
            await first.enter(tester, 'Denumire', 'PRIVATE_OLD_A_TRIP');
          }
          final action = kind == 'create' ? 'Creează' : kind == 'edit' ? 'Salvează' : kind == 'close' ? 'Închide' : 'Adaugă';
          await tester.tap(find.text(action)); await tester.pumpAndSettle();
          expect(saves, 1); expect(first.logs, isEmpty);
          final second = ExpenseDocumentFixture('', userId: 'B');
          await second.mount(tester);
          final third = ExpenseDocumentFixture('', userId: 'A');
          if (returnToA) await third.mount(tester);
          expect(identical(tester.state(find.byType(ExpensePage)), originalState), isTrue,
            reason: 'Exercise State reuse and A-B-A epoch, not only disposal');
          final successor = tester.widget<ExpensePage>(find.byType(ExpensePage)).settlements.single;
          final before = settlementFields(successor);
          gate.complete(); await tester.pumpAndSettle();
          expect(saves, 1); expect(first.logs, isEmpty); expect(second.logs, isEmpty); expect(third.logs, isEmpty);
          expect(settlementFields(successor), before);
          expect(find.textContaining('PRIVATE_OLD_A'), findsNothing);
          expect(find.text('Suma primită a fost adăugată.'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
