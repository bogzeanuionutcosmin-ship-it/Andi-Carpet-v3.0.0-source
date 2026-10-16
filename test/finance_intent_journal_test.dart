import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
class MemoryPrivateStorage implements FinanceJournalStorage {
 final values=<String,String>{};int writes=0;bool fail=false;
 @override Future<String?> read(String key)async=>values[key];
 @override Future<void> write(String key,String value)async{writes++;if(fail)throw StateError('synthetic storage failure');values[key]=value;}
}
FinanceIntent intent(int id,{String owner='A',String target='trip',double amount=10})=>FinanceIntent(operationId:id.toRadixString(16).padLeft(32,'0'),actorUid:owner,teamId:'team',collection:'settlements',documentId:target,baseRevision:0,kind:FinanceIntentKind.receipt,changes:{'kind':'departure','amount':amount,'method':'Cash','fromName':'Synthetic','date':DateTime.utc(2026)});
FinanceIntentJournal journal(MemoryPrivateStorage s,{String owner='A',bool Function()? current})=>FinanceIntentJournal(storage:s,ownerUid:owner,sessionIsCurrent:current??()=>true);
void main(){
 test('exact identity survives journal reconstruction',()async{final s=MemoryPrivateStorage();await journal(s).prepare(intent(1));expect((await journal(s).pending()).single.digest,intent(1).digest);});
 test('same request preparation is idempotent',()async{final s=MemoryPrivateStorage();await Future.wait(List.generate(20,(_)=>journal(s).prepare(intent(1))));expect(s.writes,1);expect(await journal(s).pending(),hasLength(1));});
 test('same identity with changed payload refused without overwrite',()async{final s=MemoryPrivateStorage();await journal(s).prepare(intent(1));await expectLater(journal(s).prepare(intent(1,amount:11)),throwsA(isA<FinanceRefusal>()));expect((await journal(s).pending()).single.changes['amount'],10);});
 test('new ID on unresolved target is blocked across journal instances',()async{final s=MemoryPrivateStorage();final results=await Future.wait([journal(s).prepare(intent(1)).then((_)=>true,onError:(_)=>false),journal(s).prepare(intent(2)).then((_)=>true,onError:(_)=>false)]);expect(results.where((v)=>v),hasLength(1));expect(await journal(s).pending(),hasLength(1));});
 for(final status in [FinanceIntentStatus.uncertain,FinanceIntentStatus.conflict]){test('$status never erases durable intent',()async{final s=MemoryPrivateStorage();final j=journal(s);await j.prepare(intent(1));await j.recordResult(intent(1),FinanceIntentResult(status,'synthetic'));expect(await j.pending(),hasLength(1));});}
 for(final status in [FinanceIntentStatus.confirmed,FinanceIntentStatus.rejectedBeforeWrite]){test('$status releases target for a new legitimate equal receipt',()async{final s=MemoryPrivateStorage();final j=journal(s);await j.prepare(intent(1));await j.recordResult(intent(1),FinanceIntentResult(status,'synthetic'));await j.prepare(intent(2));expect((await j.pending()).single.operationId,intent(2).operationId);});}
 test('A to B to A2 never shares pending requests',()async{final s=MemoryPrivateStorage();var a=true;final old=journal(s,current:()=>a);await old.prepare(intent(1));a=false;await journal(s,owner:'B').prepare(intent(2,owner:'B'));await expectLater(old.pending(),throwsA(isA<FinanceRefusal>()));expect((await journal(s).pending()).single.actorUid,'A');expect((await journal(s,owner:'B').pending()).single.actorUid,'B');});
 test('wrong owner cannot create or clear another owner intent',()async{final s=MemoryPrivateStorage();await expectLater(journal(s).prepare(intent(1,owner:'B')),throwsA(isA<FinanceRefusal>()));expect(s.writes,0);});
 test('corrupt storage is preserved, never silently replaced',()async{final s=MemoryPrivateStorage()..values['finance_intents_v1_A']='corrupt';await expectLater(journal(s).prepare(intent(1)),throwsA(isA<FinanceRefusal>()));expect(s.writes,0);});
 test('capacity preserves all unresolved evidence without eviction',()async{final s=MemoryPrivateStorage();final j=journal(s);for(var n=1;n<=32;n++){await j.prepare(intent(n,target:'trip$n'));}await expectLater(j.prepare(intent(33,target:'trip33')),throwsA(isA<FinanceRefusal>()));expect(await j.pending(),hasLength(32));});
 test('storage failure surfaces and queue remains usable',()async{final s=MemoryPrivateStorage()..fail=true;await expectLater(journal(s).prepare(intent(1)),throwsStateError);s.fail=false;await journal(s).prepare(intent(1));expect(await journal(s).pending(),hasLength(1));});
}
