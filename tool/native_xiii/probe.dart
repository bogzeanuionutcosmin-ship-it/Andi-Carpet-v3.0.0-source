// Synthetic executable IPC probe; never invoked by production application.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:andi_carpeta/finance/native_xiii/native_journal_xiii.dart';
import 'package:andi_carpeta/finance/native_xiii/sqlite_xiii.dart';
import 'package:andi_carpeta/finance/native_xiii/native_coordinator_xiii.dart';
import '../../test/support/finance_atomic_fixture.dart';
import 'package:andi_carpeta/finance/session_xiii/session_fence_xiii.dart';
import 'package:andi_carpeta/finance/history/history_xi.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';

Future<void> main()async{
 stdout.encoding=utf8;
 final input=StreamIterator<String>(stdin.transform(utf8.decoder).transform(const LineSplitter()));
 try{
  if(!await input.moveNext())throw const FormatException();
  final c=jsonDecode(input.current) as Map<String,dynamic>;var current=true;
  final b=FinanceSessionXiiiBinding(ownerUid:c['uid'] as String? ?? 'synthetic',teamId:c['team'] as String? ?? 'team',epoch:c['epoch'] as int? ?? 1);
  final j=NativeSqliteHistoryXiiiJournal.syntheticHostProbe(directory:Directory(c['directory'] as String),binding:b,
   sessionIsCurrent:()=>current,probePageLimit:c['pageLimit'] as int?,probeStage:(s)async{
    if(s.name==c['revokeStage'])current=false;
    if(s.name==c['failStage'])throw const FinanceRefusal('synthetic_stage_failure');
    if(s.name==c['holdStage']){
     stdout.writeln(jsonEncode({'stage':s.name,'pid':pid}));await stdout.flush();
     if(!await input.moveNext() || input.current!='release')throw const FinanceRefusal('synthetic_release_missing');
    }
   });
  Object? result;
  switch(c['action']){
   case 'init':await j.initializeSyntheticDatabase();result=true;
   case 'pending':result=(await j.pendingBound()).map((i)=>i.encode()).toList();
   case 'prepare':
    final id=c['id'] as int? ?? 1;
    final i=c['raw'] is String ? HistoryXiIntent.decode(c['raw'] as String) : HistoryXiIntent(FinanceIntent(
     operationId:id.toRadixString(16).padLeft(32,'0'),actorUid:c['intentUid'] as String? ?? b.ownerUid,
     teamId:c['intentTeam'] as String? ?? b.teamId,collection:'settlements',documentId:c['target'] as String? ?? 'trip-$id',
     baseRevision:0,kind:FinanceIntentKind.receipt,changes:{'kind':'departure','amount':c['amount'] as num? ?? 200,
      'method':'Cash','fromName':c['payer'] as String? ?? 'Synthetic XIII','date':FinanceTimestamp(1790812800,123456789)}));
    result=await j.prepare(i);
   case 'confirm':
    final lookup=NativeSqliteHistoryXiiiJournal.syntheticHostProbe(directory:Directory(c['directory'] as String),binding:b,sessionIsCurrent:()=>current);
    final items=await lookup.pendingBound();final item=items.singleWhere((i)=>i.history.receipt.operationId==(c['id'] as int).toRadixString(16).padLeft(32,'0'));
    result=await j.confirm(item.history);
   case 'model-flow':
    final i=HistoryXiIntent(FinanceIntent(operationId:'f'*32,actorUid:b.ownerUid,teamId:b.teamId,
     collection:'settlements',documentId:'model-trip',baseRevision:0,kind:FinanceIntentKind.receipt,
     changes:{'kind':'departure','amount':200,'method':'Cash','fromName':'Synthetic','date':FinanceTimestamp(1,123456789)}));
    final server=FinanceAtomicFixture()..seed(i.receipt.targetPath,{'teamId':b.teamId,'receivedDeparture':0,'receivedDuring':0})
     ..seed(b.fencePath,{...b.toMap(),'enabled':true})..commitThenThrow=true;
    final coord=NativeSessionXiiiCoordinator(journal:j,server:server,sessionIsCurrent:()=>true);
    final first=await coord.executeExplicitly(i),again=await coord.executeExplicitly(i);
    final bound=(await j.pendingBound()).single;
    final newer=NativeSqliteHistoryXiiiJournal.syntheticHostProbe(directory:Directory(c['directory'] as String),
     binding:FinanceSessionXiiiBinding(ownerUid:b.ownerUid,teamId:b.teamId,epoch:b.epoch+1),sessionIsCurrent:()=>true);
    final recovered=NativeSessionXiiiCoordinator(journal:newer,server:server,sessionIsCurrent:()=>true);
    final last=await recovered.reconcileExplicitly(i);
    result={'first':first.result.status.name,'repeat':again.result.status.name,'reconciled':last.result.status.name,
     'storedEpoch':bound.binding.epoch,'transactions':server.calls,'writes':server.writes,'serverReads':server.serverReads,
     'pending':(await newer.pendingBound()).length};
   case 'inspect':
    final db=SqliteXiii(j.path);
    try{result={'sqliteVersion':db.version,'journalMode':db.scalar('PRAGMA journal_mode'),
      'applicationId':db.scalar('PRAGMA application_id'),'userVersion':db.scalar('PRAGMA user_version'),
      'envelope':db.scalar('SELECT envelope FROM journal WHERE singleton=1')};}finally{db.close();}
   case 'inject':
    final db=SqliteXiii(j.path);
    try{
     if(c['fault']=='corrupt'){db.query('UPDATE journal SET envelope=? WHERE singleton=1',['corrupt retained evidence']);}
     else if(c['fault']=='wal'){db.query('PRAGMA journal_mode=WAL');}
     else if(c['fault']=='version'){db.query('PRAGMA user_version=999');}
     else{throw const FinanceRefusal('synthetic_fault_invalid');}
     result=true;
    }finally{db.close();}
   default:throw const FinanceRefusal('synthetic_action_invalid');
  }
  stdout.writeln(jsonEncode({'ok':true,'result':result,'pid':pid}));await stdout.flush();
 }catch(e){stdout.writeln(jsonEncode({'ok':false,'code':e is FinanceRefusal?e.code:'native_probe_failed','pid':pid}));await stdout.flush();}
 finally{await input.cancel();}
}
