import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/reports/decont_financial_input_selection.dart';

class _Expense {
  const _Expense({
    required this.id,
    required this.teamId,
    required this.settlementId,
    required this.confirmed,
    required this.amount,
    required this.date,
  });
  final String id;
  final String teamId;
  final String? settlementId;
  final bool confirmed;
  final double amount;
  final DateTime date;
}

class _PerDiem {
  const _PerDiem({
    required this.id,
    required this.teamId,
    required this.settlementId,
    required this.confirmed,
    required this.received,
    required this.amount,
    required this.date,
  });
  final String id;
  final String teamId;
  final String? settlementId;
  final bool confirmed;
  final bool received;
  final double? amount;
  final DateTime date;
}

class _Receipt {
  const _Receipt(this.id, this.amount);
  final String id;
  final double amount;
}

void main() {
  group('decont PDF financial input selection', () {
    test('filters selected-settlement expenses, keeps first ID, then orders by date', () {
      final expenses = <_Expense>[
        _Expense(
          id: 'duplicate',
          teamId: 'team-1',
          settlementId: 'settlement-1',
          confirmed: true,
          amount: 40,
          date: DateTime(2026, 10, 23),
        ),
        _Expense(
          id: 'early',
          teamId: 'team-1',
          settlementId: 'settlement-1',
          confirmed: true,
          amount: 15,
          date: DateTime(2026, 10, 21),
        ),
        _Expense(
          id: 'duplicate',
          teamId: 'team-1',
          settlementId: 'settlement-1',
          confirmed: true,
          amount: 99,
          date: DateTime(2026, 10, 20),
        ),
        _Expense(
          id: 'other-team',
          teamId: 'team-2',
          settlementId: 'settlement-1',
          confirmed: true,
          amount: 1,
          date: DateTime(2026, 10, 20),
        ),
        _Expense(
          id: 'unconfirmed',
          teamId: 'team-1',
          settlementId: 'settlement-1',
          confirmed: false,
          amount: 1,
          date: DateTime(2026, 10, 20),
        ),
        _Expense(
          id: 'negative',
          teamId: 'team-1',
          settlementId: 'settlement-1',
          confirmed: true,
          amount: -1,
          date: DateTime(2026, 10, 20),
        ),
        _Expense(
          id: 'non-finite',
          teamId: 'team-1',
          settlementId: 'settlement-1',
          confirmed: true,
          amount: double.infinity,
          date: DateTime(2026, 10, 20),
        ),
        _Expense(
          id: 'other-settlement',
          teamId: 'team-1',
          settlementId: 'settlement-2',
          confirmed: true,
          amount: 1,
          date: DateTime(2026, 10, 20),
        ),
      ];

      final selected = selectDecontPdfExpenses<_Expense>(
        expenses: expenses,
        teamId: 'team-1',
        selectedSettlementId: 'settlement-1',
        teamIdOf: (expense) => expense.teamId,
        confirmedOf: (expense) => expense.confirmed,
        amountOf: (expense) => expense.amount,
        settlementIdOf: (expense) => expense.settlementId,
        idOf: (expense) => expense.id,
        dateOf: (expense) => expense.date,
      );

      expect(selected.map((expense) => expense.id), <String>['early', 'duplicate']);
      expect(selected.last.amount, 40);
      expect(expenses.length, 8);
    });

    test('legacy-only export selects null and empty settlement IDs', () {
      final expenses = <_Expense>[
        _Expense(id: 'null', teamId: 'team-1', settlementId: null, confirmed: true, amount: 2, date: DateTime(2026, 10, 20)),
        _Expense(id: 'empty', teamId: 'team-1', settlementId: '', confirmed: true, amount: 3, date: DateTime(2026, 10, 21)),
        _Expense(id: 'linked', teamId: 'team-1', settlementId: 'settlement-1', confirmed: true, amount: 4, date: DateTime(2026, 10, 22)),
      ];

      final selected = selectDecontPdfExpenses<_Expense>(
        expenses: expenses,
        teamId: 'team-1',
        legacyOnly: true,
        teamIdOf: (expense) => expense.teamId,
        confirmedOf: (expense) => expense.confirmed,
        amountOf: (expense) => expense.amount,
        settlementIdOf: (expense) => expense.settlementId,
        idOf: (expense) => expense.id,
        dateOf: (expense) => expense.date,
      );

      expect(selected.map((expense) => expense.id), <String>['null', 'empty']);
    });

    test('filters and deduplicates confirmed received per-diems before sorting', () {
      final entries = <_PerDiem>[
        _PerDiem(id: 'payment-1', teamId: 'team-1', settlementId: 's1', confirmed: true, received: true, amount: 40, date: DateTime(2026, 10, 23)),
        _PerDiem(id: 'payment-2', teamId: 'team-1', settlementId: 's1', confirmed: true, received: true, amount: 30, date: DateTime(2026, 10, 21)),
        _PerDiem(id: 'payment-1', teamId: 'team-1', settlementId: 's1', confirmed: true, received: true, amount: 99, date: DateTime(2026, 10, 20)),
        _PerDiem(id: 'pending', teamId: 'team-1', settlementId: 's1', confirmed: false, received: true, amount: 1, date: DateTime(2026, 10, 20)),
        _PerDiem(id: 'not-received', teamId: 'team-1', settlementId: 's1', confirmed: true, received: false, amount: 1, date: DateTime(2026, 10, 20)),
        _PerDiem(id: 'missing', teamId: 'team-1', settlementId: 's1', confirmed: true, received: true, amount: null, date: DateTime(2026, 10, 20)),
        _PerDiem(id: 'negative', teamId: 'team-1', settlementId: 's1', confirmed: true, received: true, amount: -1, date: DateTime(2026, 10, 20)),
        _PerDiem(id: 'wrong-team', teamId: 'team-2', settlementId: 's1', confirmed: true, received: true, amount: 1, date: DateTime(2026, 10, 20)),
        _PerDiem(id: 'wrong-settlement', teamId: 'team-1', settlementId: 's2', confirmed: true, received: true, amount: 1, date: DateTime(2026, 10, 20)),
      ];

      final selected = selectDecontPdfPerDiems<_PerDiem>(
        entries: entries,
        teamId: 'team-1',
        selectedSettlementId: 's1',
        teamIdOf: (entry) => entry.teamId,
        confirmedOf: (entry) => entry.confirmed,
        receivedOf: (entry) => entry.received,
        actualAmountOf: (entry) => entry.amount,
        settlementIdOf: (entry) => entry.settlementId,
        idOf: (entry) => entry.id,
        dateOf: (entry) => entry.date,
      );

      expect(selected.map((entry) => entry.id), <String>['payment-2', 'payment-1']);
      expect(selected.last.amount, 40);
    });

    test('deduplicates received entries by ID, filters invalid amounts, and keeps source order', () {
      const entries = <_Receipt>[
        _Receipt('receipt-1', 20),
        _Receipt('receipt-2', 30),
        _Receipt('receipt-1', 99),
        _Receipt('negative', -1),
        _Receipt('infinite', double.infinity),
      ];

      final selected = selectDecontPdfReceivedEntries<_Receipt>(
        entries: entries,
        amountOf: (entry) => entry.amount,
        idOf: (entry) => entry.id,
      );

      expect(selected.map((entry) => entry.id), <String>['receipt-1', 'receipt-2']);
      expect(selected.first.amount, 20);
    });
  });
}
