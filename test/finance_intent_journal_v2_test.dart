import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/journal_v2/history_v2_journal.dart';
import 'package:andi_carpeta/finance/history/history_xi.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'finance_intent_history_xi_test.dart' show xi, xiDb, repo;

// Coordinator contract fixture ONLY; cross-context storage is tested in Chromium.
class MemoryV2 implements HistoryV2Journal {
  @override String get ownerUid => 'a';
  @override String get teamId => 'team';
  final items = <String,HistoryXiIntent>{};
  bool failPrepare=false, failConfirm=false, closed=false;
  @override Future<List<HistoryXiIntent>> pending() async {
    if(closed) throw StateError('closed'); return items.values.toList();
  }
  @override Future<bool> prepare(HistoryXiIntent i) async {
    if(failPrepare || closed) throw StateError('storage');
    if(items.containsKey(i.receipt.operationId))return false;
    items[i.receipt.operationId]=HistoryXiIntent.decode(i.encode()); return true;
  }
  @override Future<bool> confirm(HistoryXiIntent i) async {
    if(failConfirm || closed)throw StateError('cleanup');
    return items.remove(i.receipt.operationId)!=null;
  }
  @override void dispose(){closed=true;}
}
void main(){
 test('V2 failed prepare never starts financial transaction',()async{
  final db=xiDb(),j=MemoryV2()..failPrepare=true,c=HistoryV2Coordinator(repository:repo(db),journal:j);
  expect((await c.executeExplicitly(xi(1))).result.status,FinanceIntentStatus.uncertain);
  expect(db.calls,0);
 });
 test('V2 lost ACK survives recreation and requires read-only same-intent reconcile',()async{
  final db=xiDb()..commitThenThrow=true,j=MemoryV2(),i=xi(1);
  final c=HistoryV2Coordinator(repository:repo(db),journal:j);
  expect((await c.executeExplicitly(i)).result.status,FinanceIntentStatus.uncertain);
  expect((await c.executeExplicitly(i)).result.status,FinanceIntentStatus.uncertain);
  expect(db.calls,1);expect(db.writes,2);expect(await j.pending(),hasLength(1));
  final again=HistoryV2Coordinator(repository:repo(db),journal:j);
  expect((await again.reconcileExplicitly(HistoryXiIntent.decode(i.encode()))).result.status,FinanceIntentStatus.confirmed);
  expect(await j.pending(),isEmpty);expect(db.calls,1);expect(db.serverReads,2);
 });
 test('V2 missing evidence, cached evidence and mismatched payload cannot clear pending',()async{
  final db=xiDb()..commitThenThrow=true,j=MemoryV2(),c=HistoryV2Coordinator(repository:repo(db),journal:j),i=xi(1);
  await c.executeExplicitly(i);
  expect((await c.reconcileExplicitly(xi(1,amount:201))).result.status,FinanceIntentStatus.uncertain);
  db.fromCache=true;expect((await c.reconcileExplicitly(i)).journalPending,true);
  expect(await j.pending(),hasLength(1));expect(db.writes,2);
 });
 test('V2 cleanup failure preserves confirmation and exact pending intent',()async{
  final db=xiDb(),j=MemoryV2()..failConfirm=true,c=HistoryV2Coordinator(repository:repo(db),journal:j);
  final result=await c.executeExplicitly(xi(1));
  expect(result.result.status,FinanceIntentStatus.confirmed);expect(result.journalPending,true);
  j.failConfirm=false;expect((await c.reconcileExplicitly(xi(1))).journalPending,false);
  expect(db.calls,1);expect(db.writes,2);
 });
 test('V2 logout never revives old journal and a foreign team cannot send',()async{
  final db=xiDb(),j=MemoryV2(),c=HistoryV2Coordinator(repository:repo(db),journal:j);
  expect((await c.executeExplicitly(xi(1,team:'foreign'))).result.status,FinanceIntentStatus.uncertain);
  j.dispose();expect((await c.executeExplicitly(xi(1))).result.status,FinanceIntentStatus.uncertain);
  expect(db.calls,0);
 });
 test('V2 certain refusal retains evidence; no implicit dismissal or retry',()async{
  final db=xiDb()..documents['settlements/trip']!['receivedDeparture']=2;
  final j=MemoryV2(),c=HistoryV2Coordinator(repository:repo(db),journal:j);
  expect((await c.executeExplicitly(xi(1))).result.status,FinanceIntentStatus.rejectedBeforeWrite);
  expect(await j.pending(),hasLength(1));
  await c.executeExplicitly(xi(1));expect(db.calls,1);expect(db.writes,0);
 });
}
