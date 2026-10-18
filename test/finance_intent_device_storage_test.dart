import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/finance_checked_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_coordinator.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'support/finance_atomic_fixture.dart';

class DeviceFixture implements FinanceJournalStorage {
  final values=<String,String>{};
  bool dropWrite=false, commitThenThrow=false, corrupt=false;
  int writes=0,reads=0;
  void Function()? afterRead,afterWrite;
  @override Future<String?> read(String key) async {
    reads++; final value=values[key];afterRead?.call();return value;
  }
  @override Future<void> write(String key,String value) async {
    writes++;
    if(!dropWrite)values[key]=corrupt?'partial':value;
    afterWrite?.call();
    if(commitThenThrow)throw StateError('synthetic_local_ack_loss');
  }
}
FinanceIntent request(int id,{String uid='A',String target='trip'})=>FinanceIntent(
  operationId:id.toRadixString(16).padLeft(32,'0'),actorUid:uid,teamId:'team',
  collection:'settlements',documentId:target,baseRevision:0,kind:FinanceIntentKind.receipt,
  changes:{'kind':'departure','amount':200,'method':'Cash','fromName':'Synthetic',
    'date':DateTime.utc(2026,10,16)});
FinanceCheckedJournalStorage checked(DeviceFixture d,{String uid='A',bool Function()? current})=>
  FinanceCheckedJournalStorage.singleWriterCandidate(storage:d,ownerUid:uid,
    sessionIsCurrent:current??()=>true);
FinanceIntentJournal journal(FinanceJournalStorage s,{String uid='A'})=>
  FinanceIntentJournal(storage:s,ownerUid:uid,sessionIsCurrent:()=>true);
FinanceAtomicFixture database()=>FinanceAtomicFixture()..seed('settlements/trip',{
  'teamId':'team','closed':false,'receivedDeparture':0,'receivedDuring':0,'receivedEntries':<Object?>[]});
FinanceIntentCoordinator coordinator(FinanceAtomicFixture db,FinanceJournalStorage storage)=>
  FinanceIntentCoordinator(repository:FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>true),journal:journal(storage));
void main(){
  test('new adapter instance recovers exact intent without a financial call',()async{
    final d=DeviceFixture(),first=checked(d);await journal(first).prepare(request(1));first.dispose();
    final recovered=await journal(checked(d)).pending();
    expect(recovered.single.encode(),request(1).encode());expect(d.writes,1);
    expect(jsonDecode(d.values.values.single)['format'],FinanceCheckedJournalStorage.format);
  });
  test('dropped or torn local write schedules zero server work and preserves bytes',()async{
    for(final torn in [false,true]){
      final d=DeviceFixture();d.dropWrite=!torn;d.corrupt=torn;
      final db=database();final result=await coordinator(db,checked(d)).executeExplicitly(request(1));
      expect(result.result.status,FinanceIntentStatus.rejectedBeforeWrite);
      expect(db.calls,0);expect(db.writes,0);
      if(torn){expect(d.values.values.single,'partial');
        await expectLater(journal(checked(d)).pending(),throwsA(isA<FinanceRefusal>()));}
    }
  });
  test('local write applied then error never sends; new instance retains same ID',()async{
    final d=DeviceFixture()..commitThenThrow=true;final db=database();
    expect((await coordinator(db,checked(d)).executeExplicitly(request(1))).result.status,FinanceIntentStatus.rejectedBeforeWrite);
    expect(db.calls,0);d.commitThenThrow=false;
    expect((await journal(checked(d)).pending()).single.digest,request(1).digest);
  });
  test('server commit with lost acknowledgement survives object recreation and only reconciles',()async{
    final d=DeviceFixture(),db=database()..commitThenThrow=true;
    final first=checked(d);final result=await coordinator(db,first).executeExplicitly(request(1));
    expect(result.result.status,FinanceIntentStatus.uncertain);first.dispose();
    final second=coordinator(db,checked(d)),old=(await second.journal.pending()).single;
    expect(old.operationId,request(1).operationId);expect(db.calls,1);
    final recovered=await second.reconcileExplicitly(old);
    expect(recovered.result.status,FinanceIntentStatus.confirmed);expect(db.calls,1);
    expect(db.documents['settlements/trip']!['receivedEntries'],hasLength(1));
    expect(await second.journal.pending(),isEmpty);
  });
  test('checksum corruption foreign owner and unknown schema fail closed without overwrite',()async{
    for(final change in <Map<String,Object?>>[
      {'digest':'bad'},{'ownerUid':'B'},{'format':'future'},{'payload':'changed'},
    ]){
      final d=DeviceFixture();await journal(checked(d)).prepare(request(1));
      final envelope=jsonDecode(d.values.values.single) as Map<String,dynamic>;
      d.values['finance_intents_v1_A']=jsonEncode({...envelope,...change});
      final preserved=d.values.values.single;
      await expectLater(journal(checked(d)).prepare(request(2)),throwsA(isA<FinanceRefusal>()));
      expect(d.writes,1);expect(d.values.values.single,preserved);
    }
  });
  test('legacy raw journal requires explicit upgrade and is never silently reset',()async{
    final d=DeviceFixture();await journal(d).prepare(request(1));final before=d.values.values.single;
    await expectLater(journal(checked(d)).pending(),throwsA(isA<FinanceRefusal>().having(
      (e)=>e.code,'code','finance_device_journal_upgrade_required')));
    expect(d.values.values.single,before);expect(d.writes,1);
  });
  test('A to B to A2 isolates keys and a revoked or throwing owner never revives',()async{
    final d=DeviceFixture();var active=true;final a=checked(d,current:()=>active);
    await journal(a).prepare(request(1));active=false;
    await expectLater(journal(a).pending(),throwsA(isA<FinanceRefusal>()));active=true;
    await expectLater(journal(a).pending(),throwsA(isA<FinanceRefusal>()));
    expect(await journal(checked(d,uid:'B'),uid:'B').pending(),isEmpty);
    expect((await journal(checked(d)).pending()).single.actorUid,'A');
    await expectLater(checked(d,uid:'B').read('finance_intents_v1_A'),throwsA(isA<FinanceRefusal>()));
    final throwing=checked(d,current:()=>throw StateError('synthetic'));
    await expectLater(throwing.read('finance_intents_v1_A'),throwsA(isA<FinanceRefusal>()));
  });
  test('revocation during readback cannot release persistence barrier',()async{
    final d=DeviceFixture();var current=true;
    d.afterWrite=()=>current=false;final db=database();
    final result=await coordinator(db,checked(d,current:()=>current)).executeExplicitly(request(1));
    expect(result.result.status,FinanceIntentStatus.rejectedBeforeWrite);expect(db.calls,0);
    expect((await journal(checked(d)).pending()).single.digest,request(1).digest);
  });
  test('cleanup failure preserves financial confirmation and never resubmits',()async{
    final d=DeviceFixture(),db=database();final c=coordinator(db,checked(d));
    await c.journal.prepare(request(1));d.afterWrite=(){d.commitThenThrow=true;};
    // prepare of the same ID does not rewrite; financial commit is then real.
    final result=await c.executeExplicitly(request(1));
    expect(result.result.status,FinanceIntentStatus.confirmed);expect(result.journalPending,true);
    expect(db.calls,1);expect(db.documents['settlements/trip']!['receivedEntries'],hasLength(1));
    d.commitThenThrow=false;d.afterWrite=null;
    expect(await journal(checked(d)).pending(),isEmpty);
  });
}
