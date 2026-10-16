import '../intents/finance_intent.dart';

// Closed, anonymous observations only. Bind to a current session sink at the
// future integration boundary. No import of another branch's Vision source.
enum HistoryXiObservation { operationUncertain, revisionConflict }
FinanceIntentResult observeHistoryXiResult(FinanceIntentResult result,
    void Function(HistoryXiObservation) emit) {
  final signal=switch(result.status){
    FinanceIntentStatus.uncertain=>HistoryXiObservation.operationUncertain,
    FinanceIntentStatus.conflict=>HistoryXiObservation.revisionConflict,
    _=>null,
  };
  if(signal!=null){try{emit(signal);}catch(_){/* Diagnostic failure cannot affect money. */}}
  // Never manufactures a confirmed result, infers permission, mutates a
  // journal, or owns a financial retry. The original object is returned.
  return result;
}
