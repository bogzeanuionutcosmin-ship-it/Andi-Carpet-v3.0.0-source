import 'finance_intent.dart';
import 'finance_journal.dart';
import 'finance_repository.dart';

class FinanceCoordinatedResult {
  final FinanceIntentResult result;
  final bool journalPending;
  const FinanceCoordinatedResult(this.result,{this.journalPending=false});
}
// Every invocation is explicit. Loading a journal or recreating an account
// scope never executes a pending operation. No timers or completion callbacks.
class FinanceIntentCoordinator {
  final FinanceRepository repository;
  final FinanceIntentJournal journal;
  FinanceIntentCoordinator({required this.repository,required this.journal}) {
    if(repository.ownerUid!=journal.ownerUid)throw ArgumentError('finance_scope_mismatch');
  }
  Future<FinanceCoordinatedResult> executeExplicitly(FinanceIntent intent) async {
    try {await journal.prepare(intent);}
    on FinanceRefusal catch(e){return FinanceCoordinatedResult(FinanceIntentResult(FinanceIntentStatus.rejectedBeforeWrite,e.code),journalPending:true);}
    catch(_){return const FinanceCoordinatedResult(FinanceIntentResult(FinanceIntentStatus.rejectedBeforeWrite,'finance_storage_unavailable'),journalPending:true);}
    final result=await repository.execute(intent);
    return _record(intent,result);
  }
  Future<FinanceCoordinatedResult> reconcileExplicitly(FinanceIntent intent) async {
    try {
      final pending=await journal.pending();
      if(!pending.any((old)=>old.operationId==intent.operationId && old.digest==intent.digest)) {
        return const FinanceCoordinatedResult(FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_missing_local_evidence'),journalPending:true);
      }
    }catch(_){return const FinanceCoordinatedResult(FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_storage_unavailable'),journalPending:true);}
    return _record(intent,await repository.reconcile(intent));
  }
  Future<FinanceCoordinatedResult> _record(FinanceIntent intent,FinanceIntentResult result) async {
    try {await journal.recordResult(intent,result);}
    catch(_){return FinanceCoordinatedResult(result,journalPending:true);}
    return FinanceCoordinatedResult(result,journalPending:
      result.status!=FinanceIntentStatus.confirmed && result.status!=FinanceIntentStatus.rejectedBeforeWrite);
  }
}
