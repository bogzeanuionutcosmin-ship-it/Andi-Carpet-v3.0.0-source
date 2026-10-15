// STRICT RED expectation, executed separately by the characterization workflow.
// No runtime fix or policy for uncertain Firestore commits is authorized here.
import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/settlement_edit_probe.dart';

void main() {
  testWidgets('settlement edit failed save must restore original local fields', (tester) async {
    final gate = Completer<void>(); final attempts = <TravelSettlement>[];
    final fixture = ExpenseDocumentFixture('')..saveSettlementOverride = (s) async {
      attempts.add(s); await gate.future; throw StateError('synthetic rejected save');
    };
    await fixture.mount(tester);
    final original = currentSettlement(tester)..endDate = DateTime(2026, 10, 9);
    final before = settlementFields(original);
    await submitSyntheticEdit(tester, fixture);
    expect(attempts, hasLength(1)); expect(identical(attempts.single, original), isTrue);
    expect(tester.takeException(), isNull);
    gate.complete(); await tester.pumpAndSettle();
    expect(fixture.logs, isEmpty); expect(attempts, hasLength(1));
    expect(find.textContaining('Nu s-a putut salva:'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); expect(attempts, hasLength(1));
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
    // A failure signal is not proof of server absence. This is solely the
    // fake-rejection characterization of local state; it prescribes no retry.
    debugPrint('EDIT_FAILURE_PRECONDITIONS_PASS');
    expect(settlementFields(original), before, reason: 'SETTLEMENT_EDIT_LOCAL_STATE_NOT_RESTORED');
  });
}
