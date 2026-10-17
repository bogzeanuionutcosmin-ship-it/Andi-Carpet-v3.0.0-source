import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/history/history_xi.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'support/finance_atomic_fixture.dart';

HistoryXiIntent xi(int id,{int revision=0,String team='team',String target='trip',String uid='a',num amount=200})=>
 HistoryXiIntent(FinanceIntent(operationId:id.toRadixString(16).padLeft(32,'0'),actorUid:uid,
 teamId:team,collection:'settlements',documentId:target,baseRevision:revision,kind:FinanceIntentKind.receipt,
 changes:{'kind':'departure','amount':amount,'method':'Cash','fromName':'Synthetic','date':DateTime.utc(2026,10,16)}));
FinanceAtomicFixture xiDb()=>FinanceAtomicFixture()..seed('settlements/trip',{'teamId':'team','receivedDeparture':0,'receivedDuring':0,'receivedEntries':<Object?>[]});
FinanceHistoryXiRepository repo(FinanceAtomicFixture db,{bool Function()? owner})=>FinanceHistoryXiRepository(port:db,ownerUid:'a',sessionIsCurrent:owner??()=>true);
void main(){
 test('XI version envelope distinguishes v1 and retains exact intent across recreation',(){
  final i=xi(1),again=HistoryXiIntent.decode(xi(1).encode());
  expect(again.digest,i.digest);expect(i.digest,isNot(i.receipt.digest));
  expect(()=>HistoryXiIntent.decode(i.receipt.encode()),throwsFormatException);
  expect(i.toString(),'HistoryXiIntent');
 });
 test('XI recovery rejects noncanonical envelope bytes without reinterpreting intent',(){
  final canonical=xi(1).encode();
  expect(HistoryXiIntent.decode(canonical).encode(),canonical);
  final spaced=canonical.replaceFirst('"protocol":2','"protocol": 2');
  expect(spaced,isNot(canonical));
  expect(()=>HistoryXiIntent.decode(spaced),throwsFormatException);
  final trailing=' $canonical';
  expect(()=>HistoryXiIntent.decode(trailing),throwsFormatException);
 });
 test('XI summary and immutable receipt marker have one atomic effect and replay no extra writes',()async{
  final db=xiDb(),r=repo(db),i=xi(1);
  expect((await r.executeExplicitly(i)).status,FinanceIntentStatus.confirmed);
  expect(db.calls,1);expect(db.reads,3);expect(db.writes,2);
  expect((await r.executeExplicitly(i)).replayed,true);expect(db.writes,2);
  expect(db.documents[i.summaryPath]!['receivedEntries'],isNull);
  expect(db.documents[i.summaryPath]!['receivedDeparture'],200);
  expect(db.documents[i.rowPath]!['digest'],i.digest);
  expect(db.documents['settlements/trip']!['receivedDeparture'],0);
 });
 test('XI distinct equal receipts add twice and old marker remains reconcilable',()async{
  final db=xiDb(),r=repo(db),first=xi(1);
  await r.executeExplicitly(first);await r.executeExplicitly(xi(2,revision:1));
  expect(db.documents[first.summaryPath]!['receivedDeparture'],400);
  expect((await r.reconcileExplicitly(first)).status,FinanceIntentStatus.confirmed);
  expect(db.calls,2);expect(db.writes,4);expect(db.serverReads,2);
 });
 test('XI two same-revision devices serialize on summary and never lose an accepted row',()async{
  final db=xiDb(),a=repo(db),b=repo(db);var entrants=0;final both=Completer<void>();
  db.beforeCommit=()async{if(++entrants==2)both.complete();await both.future;};
  final results=await Future.wait([a.executeExplicitly(xi(1)),b.executeExplicitly(xi(2))]);
  expect(results.where((r)=>r.status==FinanceIntentStatus.confirmed),hasLength(1));
  expect(results.where((r)=>r.status==FinanceIntentStatus.uncertain),hasLength(1),
    reason:'The losing client scheduled writes in an earlier callback: public outcome cannot certify rejection');
  expect(db.writes,2);expect(db.documents[xi(1).summaryPath]!['receivedDeparture'],200);
 });
 test('XI lost ack and failed server read keep uncertainty without auto send; recreated same intent reconciles',()async{
  final db=xiDb()..commitThenThrow=true;final r=repo(db),i=xi(1);
  expect((await r.executeExplicitly(i)).status,FinanceIntentStatus.uncertain);
  db.fromCache=true;expect((await r.reconcileExplicitly(i)).status,FinanceIntentStatus.uncertain);
  db.fromCache=false;db.pending=true;expect((await r.reconcileExplicitly(i)).status,FinanceIntentStatus.uncertain);
  db.pending=false;final recreated=repo(db);
  expect((await recreated.reconcileExplicitly(HistoryXiIntent.decode(i.encode()))).status,FinanceIntentStatus.confirmed);
  expect(db.calls,1);expect(db.writes,2);
 });
 test('XI nonempty legacy or wrong team cannot bootstrap by forgetting existing money',()async{
  for(final change in <String,Object?>{'receivedDeparture':1,'receivedEntries':[{'id':'old'}],'teamId':'foreign','closed':true,'revision':1}.entries){
   final db=xiDb();db.documents['settlements/trip']![change.key]=change.value;
   expect((await repo(db).executeExplicitly(xi(1))).status,FinanceIntentStatus.rejectedBeforeWrite);
   expect(db.writes,0);
  }
 });
 test('XI missing or conflicting marker is never reconciled from a matching amount',()async{
  final db=xiDb(),r=repo(db),i=xi(1);await r.executeExplicitly(i);
  db.documents.remove(i.rowPath);
  expect((await r.reconcileExplicitly(i)).status,FinanceIntentStatus.uncertain);
  expect((await r.executeExplicitly(xi(2))).status,FinanceIntentStatus.conflict);
  db.documents[i.rowPath]={...i.row(),'digest':'b'*64};
  expect((await r.reconcileExplicitly(i)).status,FinanceIntentStatus.conflict);
  expect(db.writes,2);
 });
 test('XI revoked or throwing scope is monotonic and cannot send after A to B to A2',()async{
  final db=xiDb();var current=true;final r=repo(db,owner:()=>current);
  current=false;expect((await r.executeExplicitly(xi(1))).status,FinanceIntentStatus.rejectedBeforeWrite);
  current=true;expect((await r.executeExplicitly(xi(1))).status,FinanceIntentStatus.rejectedBeforeWrite);
  expect(db.calls,0);
  expect((await repo(db,owner:()=>throw StateError('synthetic')).executeExplicitly(xi(1))).status,FinanceIntentStatus.rejectedBeforeWrite);
 });
 test('XI consistency is incomplete until all pinned pages and totals are proven',()async{
  final db=xiDb(),r=repo(db);
  for(var n=1;n<=43;n++){await r.executeExplicitly(xi(n,revision:n-1));}
  final audit=HistoryXiConsistency(xi(43,revision:42),db.documents[xi(1).summaryPath]!);
  final rows=[for(var n=43;n>=1;n--)db.documents[xi(n,revision:n-1).rowPath]!];
  audit.consume(rows.take(20).toList());expect(audit.complete,false);
  await r.executeExplicitly(xi(44,revision:43));
  audit.consume(rows.skip(20).take(20).toList());expect(audit.complete,false);
  audit.consume(rows.skip(40).toList());expect(audit.complete,true);
 });
 test('XI gap, reorder, cached rows, wrong total and orphan revisions fail closed',()async{
  final db=xiDb(),r=repo(db);await r.executeExplicitly(xi(1));await r.executeExplicitly(xi(2,revision:1));
  final rows=[db.documents[xi(2,revision:1).rowPath]!,db.documents[xi(1).rowPath]!];
  for(final mode in ['gap','reverse','cache','total','orphan']){
   final summary={...db.documents[xi(1).summaryPath]!,if(mode=='total')'receivedDeparture':999};
   final a=HistoryXiConsistency(xi(2,revision:1),summary);
   expect(()=>a.consume(mode=='gap'?[rows.last]:mode=='reverse'?rows.reversed.toList():
    mode=='orphan'?[{...rows.first,'revision':3},rows.last]:rows,fromCache:mode=='cache'),throwsA(isA<FinanceRefusal>()));
   expect(a.complete,false);
  }
 });
 test('XI receipt payload retains nanoseconds and canonicalizes equivalent date representations',(){
  FinanceIntent base(Object date)=>FinanceIntent(operationId:'f'*32,actorUid:'a',teamId:'team',
   collection:'settlements',documentId:'trip',baseRevision:0,kind:FinanceIntentKind.receipt,
   changes:{'kind':'departure','amount':200,'method':'Cash','fromName':'Synthetic','date':date});
  final exact=HistoryXiIntent(base(FinanceTimestamp(1790812800,123456789)));
  expect((exact.row()['date'] as Map)['nanoseconds'],123456789);
  expect(HistoryXiIntent.decode(exact.encode()).digest,exact.digest);
  final date=DateTime.fromMicrosecondsSinceEpoch(-1,isUtc:true);
  final a=HistoryXiIntent(base(date)),b=HistoryXiIntent(base(FinanceTimestamp(-1,999999000)));
  expect(a.digest,b.digest);expect(a.row()['date'],{'seconds':-1,'nanoseconds':999999000});
 });

 test('XI replay completion after owner revocation cannot report a certain rejection of committed money',()async{
  final db=xiDb();var current=true;final r=repo(db,owner:()=>current),i=xi(1);
  expect((await r.executeExplicitly(i)).status,FinanceIntentStatus.confirmed);
  db.beforeCommit=()async{current=false;};
  expect((await r.executeExplicitly(i)).status,FinanceIntentStatus.uncertain);
  expect(db.calls,2);expect(db.writes,2);
  expect(db.documents[i.summaryPath]!['receivedDeparture'],200);
 });
 test('XI reverse floating sum cannot silently certify a different total or round money',()async{
  final db=xiDb(),r=repo(db);
  for(final pair in [(1,0.1),(2,0.2),(3,0.3)])await r.executeExplicitly(xi(pair.$1,revision:pair.$1-1,amount:pair.$2));
  final summary=db.documents[xi(1).summaryPath]!;
  expect(summary['receivedDeparture'],0.1+0.2+0.3);
  final a=HistoryXiConsistency(xi(3,revision:2),summary);
  expect(()=>a.consume([for(var n=3;n>=1;n--)db.documents[xi(n,revision:n-1).rowPath]!]),throwsA(isA<FinanceRefusal>()));
  expect(a.complete,false);expect(db.writes,6);
 });

}
