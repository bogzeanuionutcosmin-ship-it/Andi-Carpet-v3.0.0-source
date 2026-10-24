import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('disabled conflict learning allows save without searching for duplicates', () {
    var searched = false;

    final decision = app.decideExpenseDuplicate<String>(
      conflictsEnabled: false,
      automatic: true,
      findDuplicate: () {
        searched = true;
        return 'existing';
      },
    );

    expect(decision.kind, app.ExpenseDuplicateDecisionKind.allow);
    expect(decision.duplicate, isNull);
    expect(searched, isFalse);
  });

  test('enabled conflict learning allows when no duplicate matches', () {
    final decision = app.decideExpenseDuplicate<String>(
      conflictsEnabled: true,
      automatic: false,
      findDuplicate: () => null,
    );

    expect(decision.kind, app.ExpenseDuplicateDecisionKind.allow);
    expect(decision.duplicate, isNull);
  });

  test('automatic duplicate is blocked and retains the matched expense', () {
    final decision = app.decideExpenseDuplicate<String>(
      conflictsEnabled: true,
      automatic: true,
      findDuplicate: () => 'same receipt',
    );

    expect(decision.kind, app.ExpenseDuplicateDecisionKind.block);
    expect(decision.duplicate, 'same receipt');
  });

  test('manual duplicate requires user confirmation and retains the match', () {
    final decision = app.decideExpenseDuplicate<String>(
      conflictsEnabled: true,
      automatic: false,
      findDuplicate: () => 'same invoice',
    );

    expect(decision.kind, app.ExpenseDuplicateDecisionKind.confirm);
    expect(decision.duplicate, 'same invoice');
  });
}
