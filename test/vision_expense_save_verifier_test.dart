import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_expense_save_verifier.dart';

void main() {
  VisionExpenseSaveCheck evaluate({
    int expected = 123456,
    bool confirmed = true,
    bool exists = true,
    int? observed = 123456,
  }) => VisionExpenseSaveVerifier.evaluate(
        expectedBani: expected,
        serverConfirmed: confirmed,
        documentExists: exists,
        savedBani: observed,
      );

  test('matching integer bani require authoritative server evidence', () {
    final result = evaluate();
    expect(result.status, VisionExpenseSaveStatus.verified);
    expect(result.isVerified, isTrue);
    expect(result.diagnosticCode, isNull);
  });

  test('offline and cached reads can never report a missing save', () {
    for (final exists in [true, false]) {
      for (final observed in <int?>[null, 100, 123456]) {
        final result = evaluate(
          confirmed: false, exists: exists, observed: observed);
        expect(result.status,
          VisionExpenseSaveStatus.awaitingServerEvidence);
        expect(result.diagnosticCode, isNull);
        expect(result.isVerified, isFalse);
      }
    }
  });

  test('confirmed absence returns only a fixed safe code', () {
    final result = evaluate(exists: false, observed: null);
    expect(result.status, VisionExpenseSaveStatus.documentMissing);
    expect(result.diagnosticCode, 'saved_document_missing');
    expect(result.isVerified, isFalse);
  });

  test('confirmed mismatch compares cents precisely, not floats', () {
    final result = evaluate(observed: 123455);
    expect(result.status, VisionExpenseSaveStatus.amountMismatch);
    expect(result.diagnosticCode, 'saved_amount_mismatch');
  });

  test('negative, zero and missing saved amounts are treated conservatively', () {
    expect(evaluate(observed: -100).status,
      VisionExpenseSaveStatus.amountMismatch);
    expect(evaluate(observed: 0).status,
      VisionExpenseSaveStatus.amountMismatch);
    expect(evaluate(observed: null).status,
      VisionExpenseSaveStatus.inconsistentServerEvidence);
    expect(evaluate(observed: null).diagnosticCode, isNull);
  });

  test('contradictory server evidence never emits a false alert', () {
    final result = evaluate(exists: false, observed: 123456);
    expect(result.status,
      VisionExpenseSaveStatus.inconsistentServerEvidence);
    expect(result.diagnosticCode, isNull);
  });

  test('invalid expected amount does not trigger telemetry candidates', () {
    for (final amount in [0, -1, -100000]) {
      final result = evaluate(expected: amount, observed: null);
      expect(result.status, VisionExpenseSaveStatus.invalidExpectedAmount);
      expect(result.diagnosticCode, isNull);
    }
  });

  test('does not round 1000.01 lei to 1000.00 lei', () {
    expect(evaluate(expected: 100001, observed: 100000).status,
      VisionExpenseSaveStatus.amountMismatch);
    expect(evaluate(expected: 100001, observed: 100001).isVerified,
      isTrue);
  });

  test('diagnostics reveal neither expected nor saved amount', () {
    final cases = [
      evaluate(exists: false, observed: null),
      evaluate(observed: 100000),
      evaluate(confirmed: false, observed: 100000),
    ];
    for (final result in cases) {
      final text = '${result.status.name}|${result.diagnosticCode}';
      expect(text, isNot(contains('123456')));
      expect(text, isNot(contains('100000')));
      expect(text, isNot(contains('@')));
    }
  });
}
