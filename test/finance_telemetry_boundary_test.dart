import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_error_telemetry.dart';
import 'support/expense_document_fixture.dart';

int count() => VisionErrorTelemetry.log.entries.where((e) => e.area == 'finance' && e.code == 'received_amount_save_failed').fold(0, (n, e) => n + e.count);
void main() {
  for (final outcome in ['success', 'failure', 'revoked-failure']) {
    testWidgets('received amount $outcome has bounded payload-free telemetry', (tester) async {
      var active = true;
      var attempts = 0;
      final gate = Completer<void>();
      final before = count();
      final fixture = ExpenseDocumentFixture('');
      fixture.diagnosticSessionIsCurrent = () => active;
      fixture.saveSettlementOverride = (_) async {
          attempts++; await gate.future;
          if (outcome != 'success') throw StateError('PRIVATE_SENTINEL 321.09 token uid OCR');
        };
      await fixture.mount(tester);
      await tester.ensureVisible(find.text('Primit la plecare')); await tester.tap(find.text('Primit la plecare'));
      await tester.pumpAndSettle();
      await fixture.enter(tester, 'Valoare', '321.09'); await fixture.enter(tester, 'De la cine', 'PRIVATE_SENTINEL');
      await tester.tap(find.text('Adaugă')); await tester.pumpAndSettle();
      expect(attempts, 1); expect(count(), before); expect(fixture.logs, isEmpty);
      if (outcome == 'revoked-failure') active = false;
      gate.complete(); await tester.pumpAndSettle();
      expect(count(), before + (outcome == 'failure' ? 1 : 0));
      expect(VisionErrorTelemetry.log.encode(), isNot(contains('PRIVATE_SENTINEL')));
      expect(VisionErrorTelemetry.log.encode(), isNot(contains('321.09')));
      expect(attempts, 1); expect(fixture.logs.length, outcome == 'success' ? 1 : 0);
      expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
    });
  }
}
