import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'support/finance_atomic_fixture.dart';
FinanceIntent intent()=>FinanceIntent(operationId:'a'*32,actorUid:'A',teamId:'team',collection:'settlements',documentId:'trip',baseRevision:0,kind:FinanceIntentKind.receipt,changes:{'kind':'departure','amount':10,'method':'Cash','fromName':'Synthetic','date':DateTime.utc(2026)});
Map<String,Object?> history()=>{'teamId':'team','closed':false,'receivedDeparture':0,'receivedDuring':0,'receivedEntries':[]};
void main(){
 test('delayed server evidence cannot certify old A when A2 has same UID',()async{
  final db=FinanceAtomicFixture()..seed('settlements/trip',history());var epoch=1;
  final old=FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>epoch==1);
  await old.execute(intent());final entered=Completer<void>(),release=Completer<void>();
  db.beforeServerReturn=()async{entered.complete();await release.future;};final checking=old.reconcile(intent());await entered.future;epoch=3;release.complete();
  expect((await checking).status,FinanceIntentStatus.uncertain);expect(db.writes,2);expect(db.serverReads,1);
 });
 for(final after in ['marker','target']){test('delayed $after read after revocation never schedules write',()async{
  final db=FinanceAtomicFixture()..seed('settlements/trip',history());var epoch=1;var once=false;
  db.beforeRead=(path)async{if(!once && (after=='marker'?path.contains('financialIntents'):!path.contains('financialIntents'))){once=true;epoch=2;}};
  final old=FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>epoch==1);
  expect((await old.execute(intent())).status,FinanceIntentStatus.rejectedBeforeWrite);expect(db.writes,0);expect(db.reads,after=='marker'?1:2);
 });}
 test('offline transaction failure never schedules another attempt on reconnect',()async{
  final db=FinanceAtomicFixture()..seed('settlements/trip',history())..failBeforeCommit=true;
  final repo=FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>true);
  expect((await repo.execute(intent())).status,FinanceIntentStatus.uncertain);db.failBeforeCommit=false;
  await Future<void>.value();expect(db.calls,1);expect(db.writes,0);
  expect((await repo.reconcile(intent())).status,FinanceIntentStatus.uncertain);expect(db.calls,1);expect(db.writes,0);
 });
 test('read-only marker mismatch never performs a repair write',()async{
  final db=FinanceAtomicFixture()..seed('settlements/trip',history());final repo=FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>true);
  await repo.execute(intent());db.documents[intent().markerPath]!['actorUid']='B';
  expect((await repo.reconcile(intent())).status,FinanceIntentStatus.conflict);expect(db.writes,2);
 });
 test('owner revocation at transaction contention callback prevents stale replay',()async{
  final db=FinanceAtomicFixture()..seed('settlements/trip',history());var active=true;var first=true;
  db.beforeCommit=()async{if(first){first=false;db.seed('settlements/trip',history());active=false;}};
  final repo=FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>active);
  expect((await repo.execute(intent())).code,'finance_session_expired');expect(db.writes,0);expect(db.callbacks,2);
 });
}
