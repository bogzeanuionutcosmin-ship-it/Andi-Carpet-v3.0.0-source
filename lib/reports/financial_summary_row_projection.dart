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
  final expenseTotal = expenses
      .where((expense) => expense.teamId == team.id && expense.confirmed)
      .fold<double>(0, (total, expense) => total + expense.amount);
  final perDiemTotal = perDiems
      .where((entry) =>
          entry.teamId == team.id &&
          entry.status == PerDiemStatus.confirmed &&
          entry.received == true &&
          entry.actualReceivedAmount != null)
      .fold<double>(
        0,
        (total, entry) => total + entry.actualReceivedAmount!,
      );
  final finance = finances.firstWhere(
    (entry) => entry.teamId == team.id,
    orElse: () => TeamFinance(teamId: team.id),
  );
  final teamSettlements =
      settlements.where((entry) => entry.teamId == team.id).toList();
  final tripReceived = teamSettlements.fold<double>(
    0,
    (total, settlement) => total + settlement.totalReceived,
  );
  final totalReceived = finance.totalReceived + tripReceived;

  return FinancialSummaryRowProjection(
    totalReceived: totalReceived,
    expenseTotal: expenseTotal,
    perDiemTotal: perDiemTotal,
    balance: totalReceived - expenseTotal - perDiemTotal,
    settlementCount: teamSettlements.length,
  );
}
