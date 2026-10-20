part of '../main.dart';

enum ExpenseDuplicateDecisionKind { allow, block, confirm }

class ExpenseDuplicateDecision<T> {
  final ExpenseDuplicateDecisionKind kind;
  final T? duplicate;

  const ExpenseDuplicateDecision._(this.kind, this.duplicate);
}

/// Keeps the existing conflict-learning modes independent from dialog effects.
ExpenseDuplicateDecision<T> decideExpenseDuplicate<T>({
  required bool conflictsEnabled,
  required bool automatic,
  required T? Function() findDuplicate,
}) {
  if (!conflictsEnabled) {
    return ExpenseDuplicateDecision<T>._(
      ExpenseDuplicateDecisionKind.allow,
      null,
    );
  }

  final duplicate = findDuplicate();
  if (duplicate == null) {
    return ExpenseDuplicateDecision<T>._(
      ExpenseDuplicateDecisionKind.allow,
      null,
    );
  }

  return ExpenseDuplicateDecision<T>._(
    automatic
        ? ExpenseDuplicateDecisionKind.block
        : ExpenseDuplicateDecisionKind.confirm,
    duplicate,
  );
}
