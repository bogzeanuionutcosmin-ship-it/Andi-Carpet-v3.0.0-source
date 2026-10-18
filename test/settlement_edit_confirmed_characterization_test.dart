import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/settlement_edit_probe.dart';

void main() {
  testWidgets('settlement edit confirmed save retains changes once after dialog transition', (tester) async {
    final gate = Completer<void>(); final attempts = <TravelSettlement>[];
    final fixture = ExpenseDocumentFixture('')..saveSettlementOverride = (s) async {
      attempts.add(s); await gate.future;
    };
    await fixture.mount(tester);
    final original = currentSettlement(tester)..endDate = DateTime(2026, 10, 9);
    final before = settlementFields(original);
    await submitSyntheticEdit(tester, fixture);
    expect(attempts, hasLength(1)); expect(identical(attempts.single, original), isTrue);
    expect(original.name, 'Synthetic revised trip'); expect(original.endDate, isNull);
    expect(original.startDate, before['startDate']); expect(fixture.logs, isEmpty);
    expect(tester.takeException(), isNull);
    gate.complete(); await tester.pumpAndSettle();
    expect(fixture.logs.where((s) => s.startsWith('Deplasare modificată:')), hasLength(1));
    expect(original.name, 'Synthetic revised trip'); expect(original.endDate, isNull);
    await tester.pump(const Duration(seconds: 1)); expect(attempts, hasLength(1));
    await tester.pumpWidget(const SizedBox()); expect(tester.takeException(), isNull);
  });
}
