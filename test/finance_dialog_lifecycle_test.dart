import 'package:andi_carpeta/expenses/finance_dialog_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';

void main() {
  testWidgets('controller survives reverse animation and is disposed with subtree', (tester) async {
    late TextEditingController controller;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () => showDialog<void>(context: context, builder: (_) => FinanceDialogFields(
        initialTexts: const ['synthetic'],
        builder: (context, fields, setState) {
          controller = fields.single;
          return AlertDialog(content: TextField(controller: controller), actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ]);
        },
      )), child: const Text('Open'),
    ))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'edited');
    await tester.tap(find.text('Close')); await tester.pump();
    expect(controller.text, 'edited');
    // addListener asserts after dispose: prove it is still alive during transition.
    void listener() {}
    controller.addListener(listener); controller.removeListener(listener);
    await tester.pumpAndSettle();
    expect(() => controller.addListener(listener), throwsFlutterError);
    expect(tester.takeException(), isNull);
  });

  for (final kind in ['create', 'edit', 'money']) {
    for (final exit in ['cancel', 'back', 'barrier', 'confirm', 'double-confirm', 'rotate', 'unmount']) {
      testWidgets('$kind focused dialog $exit has no controller lifecycle errors', (tester) async {
        var saves = 0;
        final fixture = ExpenseDocumentFixture('')
          ..saveSettlementOverride = (_) async { saves++; };
        await fixture.mount(tester);
        final label = kind == 'create' ? 'Nouă' : kind == 'edit' ? 'Editează deplasarea' : 'Primit la plecare';
        await tester.ensureVisible(find.text(label)); await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        if (kind == 'money') {
          await fixture.enter(tester, 'Valoare', '200,00');
          await fixture.enter(tester, 'De la cine', 'Synthetic payer');
        } else {
          await fixture.enter(tester, 'Denumire', 'Synthetic edit');
        }
        if (exit == 'rotate') {
          await tester.binding.setSurfaceSize(const Size(1000, 700));
          await tester.pump();
          await tester.tap(find.text('Anulează'));
        } else if (exit == 'unmount') {
          await tester.pumpWidget(const SizedBox());
        } else if (exit == 'back') {
          await tester.binding.handlePopRoute();
        } else if (exit == 'barrier') {
          await tester.tapAt(const Offset(5, 5));
        } else {
          final action = exit == 'cancel' ? 'Anulează' : kind == 'create' ? 'Creează' : kind == 'edit' ? 'Salvează' : 'Adaugă';
          await tester.tap(find.text(action));
          if (exit == 'double-confirm') await tester.tap(find.text(action));
        }
        await tester.pumpAndSettle();
        expect(saves, (exit == 'confirm' || exit == 'double-confirm') ? 1 : 0);
        expect(fixture.logs.length, (exit == 'confirm' || exit == 'double-confirm') ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        await tester.binding.setSurfaceSize(null);
      });
    }
  }
}
