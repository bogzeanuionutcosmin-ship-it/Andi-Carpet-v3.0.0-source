import 'finance_intent.dart';
import 'finance_journal.dart';
import 'finance_repository.dart';

class FinanceCoordinatedResult {
  final FinanceIntentResult result;
  final bool journalPending;
  // This newly requested ID was never stored or sent: another durable intent
  // already owns its target. This does not dismiss or resolve that old intent.
  final bool blockedByPendingIntent;
  const FinanceCoordinatedResult(this.result,{this.journalPending=false,
    this.blockedByPendingIntent=false});
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
    late final bool fresh;
    try {fresh=await journal.prepare(intent);}
    on FinanceRefusal catch(e){return FinanceCoordinatedResult(FinanceIntentResult(FinanceIntentStatus.rejectedBeforeWrite,e.code),journalPending:true,
      blockedByPendingIntent:e.code=='finance_unresolved_target');}
    catch(_){return const FinanceCoordinatedResult(FinanceIntentResult(FinanceIntentStatus.rejectedBeforeWrite,'finance_storage_unavailable'),journalPending:true);}
    final result=await repository.execute(intent);
    if(!fresh && result.status==FinanceIntentStatus.rejectedBeforeWrite){
      // This invocation scheduled no write, but an earlier invocation of the
      // SAME durable intent may still have committed. Preserve its evidence.
      return const FinanceCoordinatedResult(FinanceIntentResult(
        FinanceIntentStatus.uncertain,'finance_prior_attempt_unresolved'),journalPending:true);
    }
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
