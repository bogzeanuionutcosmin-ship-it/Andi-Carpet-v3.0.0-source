part of '../main.dart';

/// Values already shown for one team in the general financial summary PDF.
class FinancialSummaryRowProjection {
  const FinancialSummaryRowProjection({
    required this.totalReceived,
    required this.expenseTotal,
    required this.perDiemTotal,
    required this.balance,
    required this.settlementCount,
  });

  final double totalReceived;
  final double expenseTotal;
  final double perDiemTotal;
  final double balance;
  final int settlementCount;
}

/// Preserves the existing general-summary aggregation and filtering rules.
FinancialSummaryRowProjection projectFinancialSummaryRow({
  required Team team,
  required List<Expense> expenses,
  required List<PerDiemEntry> perDiems,
  required List<TeamFinance> finances,
  required List<TravelSettlement> settlements,
}) {
  // Snapshot/list inputs can contain the same persisted row more than once.
  // Count the first valid instance for each immutable ID and fail closed on
  // malformed monetary values so one corrupt legacy value cannot poison every
  // row and the balance with NaN/Infinity.
  final seenExpenseIds = <String>{};
  final expenseTotal = expenses.fold<double>(0, (total, expense) {
    if (expense.teamId != team.id ||
        !expense.confirmed ||
        !expense.amount.isFinite ||
        expense.amount < 0 ||
        !seenExpenseIds.add(expense.id)) {
      return total;
    }
    return total + expense.amount;
  });
  final seenPerDiemIds = <String>{};
  final perDiemTotal = perDiems.fold<double>(0, (total, entry) {
    final amount = entry.actualReceivedAmount;
    if (entry.teamId != team.id ||
        entry.status != PerDiemStatus.confirmed ||
        entry.received != true ||
        amount == null ||
        !amount.isFinite ||
        amount < 0 ||
        !seenPerDiemIds.add(entry.id)) {
      return total;
    }
    return total + amount;
  });
  final finance = finances.firstWhere(
    (entry) => entry.teamId == team.id,
    orElse: () => TeamFinance(teamId: team.id),
  );
  double legacyTotal(double departure, double during) =>
      (departure.isFinite && departure >= 0 ? departure : 0) +
      (during.isFinite && during >= 0 ? during : 0);
  double uniqueReceiptTotal(Iterable<ReceivedMoneyEntry> entries) {
    final seen = <String>{};
    return entries.fold<double>(0, (total, entry) {
      if ((entry.kind != 'departure' && entry.kind != 'during') ||
          !entry.amount.isFinite ||
          entry.amount < 0 ||
          !seen.add(entry.id)) {
        return total;
      }
      return total + entry.amount;
    });
  }

  final financeReceived = finance.receivedEntries.isEmpty
      ? legacyTotal(finance.receivedDeparture, finance.receivedDuring)
      : uniqueReceiptTotal(finance.receivedEntries);
  final seenSettlementIds = <String>{};
  final tripReceived = settlements.fold<double>(0, (total, settlement) {
    if (settlement.teamId != team.id ||
        !seenSettlementIds.add(settlement.id)) {
      return total;
    }
    final amount = settlement.receivedEntries.isEmpty
        ? legacyTotal(settlement.receivedDeparture, settlement.receivedDuring)
        : uniqueReceiptTotal(settlement.receivedEntries);
    return total + amount;
  });
  final totalReceived = financeReceived + tripReceived;
  final teamSettlements = <TravelSettlement>[];
  final settlementIds = <String>{};
  for (final settlement in settlements) {
    if (settlement.teamId == team.id && settlementIds.add(settlement.id)) {
      teamSettlements.add(settlement);
    }
  }

  return FinancialSummaryRowProjection(
    totalReceived: totalReceived,
    expenseTotal: expenseTotal,
    perDiemTotal: perDiemTotal,
    balance: totalReceived - expenseTotal - perDiemTotal,
    settlementCount: teamSettlements.length,
  );
}
