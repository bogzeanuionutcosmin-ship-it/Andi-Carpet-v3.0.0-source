import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/finance_coordinator.dart';
import 'support/finance_atomic_fixture.dart';
class PrivateStorage implements FinanceJournalStorage {
 final values=<String,String>{};bool fail=false;
 @override Future<String?> read(String key)async=>values[key];
 @override Future<void> write(String key,String value)async{if(fail)throw StateError('synthetic disk failure');values[key]=value;}
}
FinanceIntent makeIntent(int n,{String uid='A',int revision=0})=>FinanceIntent(operationId:n.toRadixString(16).padLeft(32,'0'),actorUid:uid,teamId:'team',collection:'settlements',documentId:'trip',baseRevision:revision,kind:FinanceIntentKind.receipt,changes:{'kind':'departure','amount':10,'method':'Cash','fromName':'Synthetic','date':DateTime.utc(2026)});
Map<String,Object?> seed()=>{'teamId':'team','closed':false,'receivedDeparture':0,'receivedDuring':0,'receivedEntries':[]};
FinanceIntentCoordinator scope(FinanceAtomicFixture db,PrivateStorage storage,{String uid='A',bool Function()? current}){
 final guard=current??()=>true;return FinanceIntentCoordinator(repository:FinanceRepository(port:db,ownerUid:uid,sessionIsCurrent:guard),journal:FinanceIntentJournal(storage:storage,ownerUid:uid,sessionIsCurrent:guard));
}
void main(){
 test('durable preparation completes before first transaction read',()async{final db=FinanceAtomicFixture()..seed('settlements/trip',seed());final storage=PrivateStorage();db.beforeCommit=()async{expect(storage.values.values.single,contains(makeIntent(1).operationId));};expect((await scope(db,storage).executeExplicitly(makeIntent(1))).result.status,FinanceIntentStatus.confirmed);expect(await scope(db,storage).journal.pending(),isEmpty);});
 test('storage failure never starts server operation',()async{final db=FinanceAtomicFixture();final storage=PrivateStorage()..fail=true;expect((await scope(db,storage).executeExplicitly(makeIntent(1))).result.status,FinanceIntentStatus.rejectedBeforeWrite);expect(db.calls,0);});
 test('lost acknowledgement survives restart without auto execution',()async{final db=FinanceAtomicFixture()..seed('settlements/trip',seed())..commitThenThrow=true;final storage=PrivateStorage();expect((await scope(db,storage).executeExplicitly(makeIntent(1))).result.status,FinanceIntentStatus.uncertain);final fresh=scope(db,storage);final pending=await fresh.journal.pending();expect(pending,hasLength(1));expect(db.calls,1);expect((await fresh.reconcileExplicitly(pending.single)).result.status,FinanceIntentStatus.confirmed);expect(db.calls,1);expect(db.writes,2);expect(await fresh.journal.pending(),isEmpty);});
 test('manual new ID after uncertain receipt is blocked without server call',()async{final db=FinanceAtomicFixture()..seed('settlements/trip',seed())..failBeforeCommit=true;final storage=PrivateStorage();final coordinator=scope(db,storage);await coordinator.executeExplicitly(makeIntent(1));expect((await coordinator.executeExplicitly(makeIntent(2))).result.code,'finance_unresolved_target');expect(db.calls,1);});
 test('manual exact replay after timeout commits once',()async{final db=FinanceAtomicFixture()..seed('settlements/trip',seed())..commitThenThrow=true;final storage=PrivateStorage();final coordinator=scope(db,storage);await coordinator.executeExplicitly(makeIntent(1));db.commitThenThrow=false;final pending=(await coordinator.journal.pending()).single;expect((await coordinator.executeExplicitly(pending)).result.replayed,true);expect(db.writes,2);});
 test('missing server marker retains exact intent and never retries',()async{final db=FinanceAtomicFixture()..seed('settlements/trip',seed())..failBeforeCommit=true;final storage=PrivateStorage();final coordinator=scope(db,storage);await coordinator.executeExplicitly(makeIntent(1));expect((await coordinator.reconcileExplicitly(makeIntent(1))).result.status,FinanceIntentStatus.uncertain);expect(db.calls,1);expect(await coordinator.journal.pending(),hasLength(1));});
 test('A to B to A2 late commit cannot complete the successor session',()async{final db=FinanceAtomicFixture()..seed('settlements/trip',seed());final storage=PrivateStorage();var generation=1;final entered=Completer<void>(),release=Completer<void>();db.beforeCommit=()async{entered.complete();await release.future;};final old=scope(db,storage,current:()=>generation==1);final saving=old.executeExplicitly(makeIntent(1));await entered.future;generation=2;final b=scope(db,storage,uid:'B',current:()=>generation==2);expect(await b.journal.pending(),isEmpty);generation=3;final a2=scope(db,storage,current:()=>generation==3);expect(await a2.journal.pending(),hasLength(1));release.complete();expect((await saving).result.status,FinanceIntentStatus.uncertain);expect(db.writes,2);expect((await a2.reconcileExplicitly(makeIntent(1))).result.status,FinanceIntentStatus.confirmed);expect(db.calls,1);});
 test('confirmed server outcome is preserved if local cleanup fails',()async{final db=FinanceAtomicFixture()..seed('settlements/trip',seed());final storage=PrivateStorage();db.beforeCommit=()async{storage.fail=true;};final r=await scope(db,storage).executeExplicitly(makeIntent(1));expect(r.result.status,FinanceIntentStatus.confirmed);expect(r.journalPending,true);expect(db.writes,2);storage.fail=false;expect(await scope(db,storage).journal.pending(),hasLength(1));});
 test('cross-owner coordinator construction is refused',(){final db=FinanceAtomicFixture();final storage=PrivateStorage();expect(()=>FinanceIntentCoordinator(repository:FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>true),journal:FinanceIntentJournal(storage:storage,ownerUid:'B',sessionIsCurrent:()=>true)),throwsArgumentError);});
 test('local rejection during manual resume cannot erase an earlier uncertain attempt',()async{
  final db=FinanceAtomicFixture()..seed('settlements/trip',seed())..failBeforeCommit=true;
  final storage=PrivateStorage();final coordinator=scope(db,storage);final i=makeIntent(1);
  expect((await coordinator.executeExplicitly(i)).result.status,FinanceIntentStatus.uncertain);
  db.failBeforeCommit=false;db.seed('settlements/trip',seed()..['closed']=true);
  final result=await coordinator.executeExplicitly(FinanceIntent.decode(i.encode()));
  expect(result.result.status,FinanceIntentStatus.uncertain);expect(result.result.code,'finance_prior_attempt_unresolved');
  expect(result.journalPending,true);expect(await coordinator.journal.pending(),hasLength(1));expect(db.writes,0);
 });

}
