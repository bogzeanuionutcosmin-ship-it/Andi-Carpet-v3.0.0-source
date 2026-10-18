import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/history/history_xi_observation.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'finance_intent_history_xi_test.dart' show xi,xiDb,repo;
void main(){
 test('XI uncertain observation cannot confirm money, serialize IDs/amounts or resubmit',()async{
  final db=xiDb()..commitThenThrow=true;final result=await repo(db).executeExplicitly(xi(1));
  final signals=<HistoryXiObservation>[];
  expect(identical(observeHistoryXiResult(result,signals.add),result),true);
  expect(result.status,FinanceIntentStatus.uncertain);
  expect(signals,[HistoryXiObservation.operationUncertain]);
  expect(db.calls,1);expect(db.writes,2);
  expect(identical(observeHistoryXiResult(result,(_)=>throw StateError('private synthetic error')),result),true);
  expect(db.calls,1);expect(result.status,FinanceIntentStatus.uncertain);
 });
 test('XI arbitrary result codes never become diagnostic payload or permission claims',(){
  final signals=<HistoryXiObservation>[];
  for(final status in FinanceIntentStatus.values){
   final r=FinanceIntentResult(status,'synthetic UID amount token must not be forwarded');
   expect(identical(observeHistoryXiResult(r,signals.add),r),true);
  }
  expect(signals,[HistoryXiObservation.operationUncertain,HistoryXiObservation.revisionConflict]);
 });
}
