/// Returns the existing Home finance subscription scope for the current member.
String? homeFinancialSyncScope({
  required bool isAdmin,
  required bool canViewOtherDeconts,
  required String? teamId,
}) =>
    isAdmin || canViewOtherDeconts ? '*' : teamId;

/// Financial subscriptions restart only when the exact scope value changes.
bool shouldRestartHomeFinancialSync(String? currentScope, String? nextScope) =>
    currentScope != nextScope;
