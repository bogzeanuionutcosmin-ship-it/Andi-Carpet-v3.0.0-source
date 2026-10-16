import '../history/history_xi.dart';
import '../intents/finance_intent.dart';
import '../intents/finance_repository.dart';
import '../journal_v2/history_v2_journal.dart';
import '../session_xiii/session_fence_xiii.dart';
import 'native_journal_xiii.dart';

// Use this factory boundary, not the raw XII coordinator: the persisted epoch
// envelope is the SAME immutable value used to authorize every server attempt.
class NativeSessionXiiiCoordinator {
  final NativeSqliteHistoryXiiiJournal journal;
  final FinanceAtomicPort server;
  final bool Function() sessionIsCurrent;
  NativeSessionXiiiCoordinator({required this.journal,required this.server,required this.sessionIsCurrent});
  Future<FinanceSessionXiiiIntent> _stored(HistoryXiIntent i)async{
    final records=await journal.pendingBound();
    return records.singleWhere((r)=>r.history.encode()==i.encode());
  }
  FinanceHistoryXiRepository _repository(FinanceSessionXiiiIntent record)=>FinanceHistoryXiRepository(
    ownerUid:journal.ownerUid,sessionIsCurrent:sessionIsCurrent,
    port:FinanceSessionXiiiPort(inner:server,intent:record,sessionIsCurrent:sessionIsCurrent));
  Future<HistoryV2Outcome> executeExplicitly(HistoryXiIntent i)async{
    try{
      if(!await journal.prepare(i))return const HistoryV2Outcome(FinanceIntentResult(FinanceIntentStatus.uncertain,'native_v2_reconcile_required'),journalPending:true);
      final record=await _stored(i);
      if(!sameFinanceValue(record.binding.toMap(),journal.binding.toMap()))throw const FinanceRefusal('native_v2_binding_mismatch');
      return await _finish(i,await _repository(record).executeExplicitly(i));
    }catch(_){return const HistoryV2Outcome(FinanceIntentResult(FinanceIntentStatus.uncertain,'native_v2_execution_unproven'),journalPending:true);}
  }
  Future<HistoryV2Outcome> reconcileExplicitly(HistoryXiIntent i)async{
    try{
      final record=await _stored(i); // Historic epoch is retained; NEVER rebound.
      return await _finish(i,await _repository(record).reconcileExplicitly(i));
    }catch(_){return const HistoryV2Outcome(FinanceIntentResult(FinanceIntentStatus.uncertain,'native_v2_reconcile_unproven'),journalPending:true);}
  }
  Future<HistoryV2Outcome> _finish(HistoryXiIntent i,FinanceIntentResult result)async{
    if(result.status!=FinanceIntentStatus.confirmed)return HistoryV2Outcome(result,journalPending:true);
    try{await journal.confirm(i);return HistoryV2Outcome(result,journalPending:false);}
    catch(_){return HistoryV2Outcome(result,journalPending:true);}
  }
}
