import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  final date = DateTime(2026, 10, 21);

  test('preserves financial summary team filters and totals without deduplication', () {
    final team = app.Team(id: 'team-a', name: 'A', members: <String>[]);
    final finance = app.TeamFinance(
      teamId: team.id,
      receivedDeparture: 10,
      receivedDuring: 5,
      receivedEntries: <app.ReceivedMoneyEntry>[
        app.ReceivedMoneyEntry(
          id: 'transfer-1',
          kind: 'departure',
          amount: 10,
          method: 'Cash',
          fromName: 'Manager',
          date: date,
        ),
        app.ReceivedMoneyEntry(
          id: 'transfer-1',
          kind: 'during',
          amount: 2,
          method: 'Transfer',
          fromName: 'Manager',
          date: date,
        ),
      ],
    );
    final settlement = app.TravelSettlement(
      id: 'trip-1',
      teamId: team.id,
      name: 'Trip',
      startDate: date,
      receivedDeparture: 7,
      receivedDuring: 3,
    );
    final otherTeamSettlement = app.TravelSettlement(
      id: 'trip-other',
      teamId: 'team-b',
      name: 'Other',
      startDate: date,
      receivedDeparture: 500,
    );
    final expenses = <app.Expense>[
      app.Expense(
        id: 'same-expense',
        teamId: team.id,
        category: 'Fuel',
        description: 'First',
        amount: 30,
        date: date,
        confirmed: true,
      ),
      app.Expense(
        id: 'same-expense',
        teamId: team.id,
        category: 'Fuel',
        description: 'Second duplicate snapshot',
        amount: 5,
        date: date,
        confirmed: true,
      ),
      app.Expense(
        id: 'unconfirmed',
        teamId: team.id,
        category: 'Fuel',
        description: 'Unconfirmed',
        amount: 100,
        date: date,
        confirmed: false,
      ),
      app.Expense(
        id: 'other-team',
        teamId: 'team-b',
        category: 'Fuel',
        description: 'Other team',
        amount: 200,
        date: date,
        confirmed: true,
      ),
    ];
    final perDiems = <app.PerDiemEntry>[
      app.PerDiemEntry(
        id: 'paid',
        teamId: team.id,
        memberId: 'member-a',
        date: date,
        amount: 999,
        status: app.PerDiemStatus.confirmed,
        received: true,
        actualReceivedAmount: 20,
      ),
      app.PerDiemEntry(
        id: 'not-received',
        teamId: team.id,
        memberId: 'member-a',
        date: date,
        amount: 999,
        status: app.PerDiemStatus.confirmed,
        received: false,
        actualReceivedAmount: 40,
      ),
      app.PerDiemEntry(
        id: 'pending',
        teamId: team.id,
        memberId: 'member-a',
        date: date,
        amount: 999,
        status: app.PerDiemStatus.notGranted,
        received: true,
        actualReceivedAmount: 60,
      ),
      app.PerDiemEntry(
        id: 'other-team-payment',
        teamId: 'team-b',
        memberId: 'member-b',
        date: date,
        amount: 999,
        status: app.PerDiemStatus.confirmed,
        received: true,
        actualReceivedAmount: 80,
      ),
      app.PerDiemEntry(
        id: 'missing-actual',
        teamId: team.id,
        memberId: 'member-a',
        date: date,
        amount: 999,
        status: app.PerDiemStatus.confirmed,
        received: true,
      ),
    ];

    final projection = app.projectFinancialSummaryRow(
      team: team,
      expenses: expenses,
      perDiems: perDiems,
      finances: <app.TeamFinance>[finance],
      settlements: <app.TravelSettlement>[settlement, otherTeamSettlement],
    );

    // TeamFinance and TravelSettlement totals retain their existing aggregate
    // semantics, while the summary expense fold does not deduplicate IDs.
    expect(projection.totalReceived, 22);
    expect(projection.expenseTotal, 35);
    expect(projection.perDiemTotal, 20);
    expect(projection.balance, -33);
    expect(projection.settlementCount, 1);
  });

  test('keeps the empty-finance fallback and existing actual-payment filter', () {
    final team = app.Team(id: 'team-empty', name: 'Empty', members: <String>[]);
    final projection = app.projectFinancialSummaryRow(
      team: team,
      expenses: <app.Expense>[],
      perDiems: <app.PerDiemEntry>[
        app.PerDiemEntry(
          id: 'nan-payment',
          teamId: team.id,
          memberId: 'member-a',
          date: date,
          amount: 1,
          status: app.PerDiemStatus.confirmed,
          received: true,
          actualReceivedAmount: double.nan,
        ),
      ],
      finances: <app.TeamFinance>[],
      settlements: <app.TravelSettlement>[],
    );

    expect(projection.totalReceived, 0);
    expect(projection.expenseTotal, 0);
    // Existing summary logic sums every non-null confirmed actual payment
    // without the stricter finite/nonnegative decont-PDF filter.
    expect(projection.perDiemTotal.isNaN, isTrue);
    expect(projection.balance.isNaN, isTrue);
    expect(projection.settlementCount, 0);
  });
}
