import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/finance/intents/finance_home_candidate.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'expense_document_fixture.dart';

// Real ExpensePage with only the model installation boundary supplied here.
// AtomicPort and deviceStorage are chosen by each test: fake or genuine SDK.
class HomeCandidateFixture {
  final ExpenseDocumentFixture page;
  late final FinanceHomeCandidate candidate;
  bool current = true;
  int refreshes = 0;
  HomeCandidateFixture({required String uid, required String teamId,
    required FinanceAtomicPort port, required FinanceJournalStorage deviceStorage,
    bool Function()? owner}) : page = ExpenseDocumentFixture('', userId: uid, teamId: teamId) {
    candidate = FinanceHomeCandidate.singleWriterCandidate(ownerUid: uid, teamId: teamId,
      sessionIsCurrent: () => current && (owner?.call() ?? true),
      port: port, deviceStorage: deviceStorage,
      readAcceptedModel: (_) => page.settlementOverride,
      acceptServerSnapshot: (path, data) async {
        page.settlementOverride = TravelSettlement(id: path.split('/').last,
          teamId: data['teamId'] as String, name: data['name'] as String,
          startDate: data['startDate'] as DateTime, createdAt: data['createdAt'] as DateTime,
          endDate: data['endDate'] as DateTime?, managerId: data['managerId'] as String?,
          perDiemRate: (data['perDiemRate'] as num).toDouble(), closed: data['closed'] as bool,
          revision: data['revision'] as int, lastOperationId: data['lastOperationId'] as String,
          receivedDeparture: (data['receivedDeparture'] as num).toDouble(),
          receivedDuring: (data['receivedDuring'] as num).toDouble(),
          receivedOpeningDeparture: (data['receivedOpeningDeparture'] as num).toDouble(),
          receivedOpeningDuring: (data['receivedOpeningDuring'] as num).toDouble(),
          receivedEntries: (data['receivedEntries'] as List).map((raw) {
            final e = raw as Map;
            return ReceivedMoneyEntry(id: e['id'] as String, kind: e['kind'] as String,
              amount: (e['amount'] as num).toDouble(), method: e['method'] as String,
              fromName: e['fromName'] as String, date: e['date'] as DateTime);
          }).toList());
        refreshes++;
        page.rebuild(() {});
      });
    page.saveSettlementOverride = candidate.saveSettlement;
    page.saveFinanceOverride = candidate.saveFinance;
    page.diagnosticSessionIsCurrent = candidate.sessionIsCurrent;
  }
}
