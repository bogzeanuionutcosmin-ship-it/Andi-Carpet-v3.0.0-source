import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../history/history_xi.dart';
import '../intents/finance_intent.dart';
import '../intents/finance_repository.dart';
import '../journal_v2/history_v2_journal.dart';
import '../session_xiii/session_fence_xiii.dart';
import 'sqlite_xiii.dart';

enum NativeXiiiStage { afterBegin, afterRead, afterValidate, afterWrite,
  beforeCommit, afterCommit, beforeReadback, afterReadback }

// Deployment factory remains closed: OS-private directory, packaged SQLite,
// encryption/key/backup and hardware proofs are not granted by a host probe.
HistoryV2Journal createNativeHistoryXiiiJournal() =>
  throw const FinanceRefusal('native_v2_platform_release_blocked');

class NativeSqliteHistoryXiiiJournal implements HistoryV2Journal {
  static const maxBytes=128*1024,maxPending=32;
  static const _applicationId=0x414E4432;
  static const _schema='CREATE TABLE journal (singleton INTEGER PRIMARY KEY CHECK(singleton=1), envelope TEXT NOT NULL)';
  static const _format='AndiNativeHistoryJournalV2';
  @override final String ownerUid;
  @override final String teamId;
  final FinanceSessionXiiiBinding binding;
  final bool Function() _owner;
  final Future<void> Function(NativeXiiiStage)? _probeStage;
  final String path;
  final int? probePageLimit;
  bool _alive=true,_busy=false;
  NativeSqliteHistoryXiiiJournal.syntheticHostProbe({required Directory directory,
    required this.binding,required bool Function() sessionIsCurrent,
    Future<void> Function(NativeXiiiStage)? probeStage,this.probePageLimit})
    :ownerUid=binding.ownerUid,teamId=binding.teamId,_owner=sessionIsCurrent,
     _probeStage=probeStage,path=_path(directory,binding);
  static String _hash(String s)=>sha256.convert(utf8.encode(s)).toString();
  static String _path(Directory root,FinanceSessionXiiiBinding binding){
    if(!root.isAbsolute || !root.existsSync() || FileSystemEntity.typeSync(root.path,followLinks:false)!=FileSystemEntityType.directory){
      throw const FinanceRefusal('native_v2_directory_unavailable');
    }
    final scope=canonicalFinanceJson({'protocol':2,'ownerUid':binding.ownerUid,'teamId':binding.teamId});
    return '${root.resolveSymbolicLinksSync()}${Platform.pathSeparator}history_v2_${_hash(scope)}.sqlite3';
  }
  @override void dispose(){_alive=false;}
  void _guard(){
    try{if(!_owner())_alive=false;}catch(_){_alive=false;}
    if(!_alive)throw const FinanceRefusal('native_v2_session_expired');
  }
  Future<void> _stage(NativeXiiiStage s)async{await _probeStage?.call(s);_guard();}
  void _fileGuard({bool initializing=false}){
    final type=FileSystemEntity.typeSync(path,followLinks:false);
    if(type==FileSystemEntityType.link || (type!=FileSystemEntityType.file && !(initializing&&type==FileSystemEntityType.notFound))){
      throw const FinanceRefusal('native_v2_storage_unavailable');
    }
  }
  String _encode(int revision,List<FinanceSessionXiiiIntent> items){
    final body={'format':_format,'protocol':2,'ownerUid':ownerUid,'teamId':teamId,
      'revision':revision,'intents':items.map((i)=>i.encode()).toList()};
    final raw=canonicalFinanceJson({...body,'checksum':_hash(canonicalFinanceJson(body))});
    if(items.length>maxPending || utf8.encode(raw).length>maxBytes)throw const FinanceRefusal('native_v2_full');
    return raw;
  }
  ({int revision,List<FinanceSessionXiiiIntent> items}) _decode(Object? value){
    try{
      if(value is! String || utf8.encode(value).length>maxBytes)throw const FormatException();
      final d=jsonDecode(value) as Map<String,dynamic>;
      if(d.length!=7 || d['format']!=_format || d['protocol']!=2 || d['ownerUid']!=ownerUid || d['teamId']!=teamId ||
        d['revision'] is! int || d['revision']<0 || d['revision']>9007199254740991 || d['intents'] is! List ||
        d['checksum']!=_hash(canonicalFinanceJson({for(final e in d.entries)if(e.key!='checksum')e.key:e.value})))throw const FormatException();
      final items=(d['intents'] as List).map((s)=>FinanceSessionXiiiIntent.decode(s as String)).toList();
      if(items.length>maxPending || items.any((i)=>i.binding.ownerUid!=ownerUid || i.binding.teamId!=teamId) ||
        items.map((i)=>i.history.receipt.operationId).toSet().length!=items.length ||
        items.map((i)=>i.history.receipt.targetPath).toSet().length!=items.length || _encode(d['revision'] as int,items)!=value)throw const FormatException();
      return (revision:d['revision'] as int,items:items);
    }catch(_){throw const FinanceRefusal('native_v2_corrupt');}
  }
  void _configure(SqliteXiii db){
    db.query('PRAGMA locking_mode=EXCLUSIVE');
    db.query('PRAGMA busy_timeout=0');
    db.query('PRAGMA synchronous=EXTRA');
    db.query('PRAGMA trusted_schema=OFF');
    if(db.scalar('PRAGMA synchronous')!=3 || db.scalar('PRAGMA trusted_schema')!=0 ||
      db.scalar('PRAGMA locking_mode')!='exclusive' || db.scalar('PRAGMA busy_timeout')!=0){
      throw const FinanceRefusal('native_v2_capability_blocked');
    }
    if(probePageLimit!=null){
      if(probePageLimit!<1)throw const FinanceRefusal('native_v2_invalid_page_limit');
      db.query('PRAGMA max_page_count=$probePageLimit');
    }
    if(Platform.isMacOS || Platform.isIOS){
      db.query('PRAGMA fullfsync=ON');db.query('PRAGMA checkpoint_fullfsync=ON');
      if(db.scalar('PRAGMA fullfsync')!=1 || db.scalar('PRAGMA checkpoint_fullfsync')!=1)throw const FinanceRefusal('native_v2_fullfsync_blocked');
    }
  }
  void _schemaGuard(SqliteXiii db){
    final schema=db.query("SELECT type,name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name");
    if(db.scalar('PRAGMA application_id')!=_applicationId || db.scalar('PRAGMA user_version')!=2 ||
      canonicalFinanceJson(schema)!=canonicalFinanceJson([['table','journal',_schema]]) ||
      db.scalar('PRAGMA journal_mode')!='delete' || db.scalar('PRAGMA quick_check')!='ok'){
      throw const FinanceRefusal('native_v2_incompatible_storage');
    }
  }
  // Explicit NEW synthetic DB bootstrap only. Normal calls never create/reset a
  // missing journal; disappearance after initialization is fail-closed.
  Future<void> initializeSyntheticDatabase()async{
    _guard();if(_busy)throw const FinanceRefusal('native_v2_busy');_busy=true;
    SqliteXiii? db;var transaction=false;
    try{
      _fileGuard(initializing:true);db=SqliteXiii(path);_configure(db);
      final app=db.scalar('PRAGMA application_id'),version=db.scalar('PRAGMA user_version');
      final tables=db.query("SELECT name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'");
      if(app==_applicationId && version==2){_schemaGuard(db);_decode(db.scalar('SELECT envelope FROM journal WHERE singleton=1'));return;}
      if(app!=0 || version!=0 || tables.isNotEmpty)throw const FinanceRefusal('native_v2_incompatible_storage');
      if(db.scalar('PRAGMA journal_mode=DELETE')!='delete')throw const FinanceRefusal('native_v2_rollback_journal_blocked');
      db.query('BEGIN IMMEDIATE');transaction=true;_guard();
      db.query(_schema);db.query('PRAGMA application_id=$_applicationId');db.query('PRAGMA user_version=2');
      db.query('INSERT INTO journal(singleton,envelope) VALUES(1,?)',[_encode(0,[])]);
      db.query('COMMIT');transaction=false;_schemaGuard(db);_decode(db.scalar('SELECT envelope FROM journal WHERE singleton=1'));_guard();
    }finally{
      if(transaction){try{db?.query('ROLLBACK');}catch(_){}}
      try{db?.close();}finally{_busy=false;}
    }
  }
  Future<T> _transaction<T>(Future<({T result,List<FinanceSessionXiiiIntent>? next})> Function(List<FinanceSessionXiiiIntent>) action)async{
    _guard();if(_busy)throw const FinanceRefusal('native_v2_busy');_busy=true;
    SqliteXiii? db;var active=false;
    try{
      _fileGuard();db=SqliteXiii(path);_configure(db);
      db.query('BEGIN IMMEDIATE');active=true;await _stage(NativeXiiiStage.afterBegin);
      _schemaGuard(db);final state=_decode(db.scalar('SELECT envelope FROM journal WHERE singleton=1'));
      await _stage(NativeXiiiStage.afterRead);
      final change=await action(state.items);await _stage(NativeXiiiStage.afterValidate);
      String? expected;
      if(change.next!=null){
        if(state.revision>=9007199254740991)throw const FinanceRefusal('native_v2_revision_exhausted');
        expected=_encode(state.revision+1,change.next!);_guard();
        db.query('UPDATE journal SET envelope=? WHERE singleton=1',[expected]);
        if(db.scalar('SELECT changes()')!=1 || db.scalar('SELECT envelope FROM journal WHERE singleton=1')!=expected)throw const FinanceRefusal('native_v2_write_failed');
        await _stage(NativeXiiiStage.afterWrite);
      }
      await _stage(NativeXiiiStage.beforeCommit);db.query('COMMIT');active=false;
      // SQLite EXCLUSIVE locking mode retains native database locks across
      // COMMIT until connection close, including this actual committed readback.
      await _stage(NativeXiiiStage.afterCommit);await _stage(NativeXiiiStage.beforeReadback);
      final actual=db.scalar('SELECT envelope FROM journal WHERE singleton=1');
      if(expected!=null && actual!=expected)throw const FinanceRefusal('native_v2_readback_failed');
      _decode(actual);await _stage(NativeXiiiStage.afterReadback);return change.result;
    }finally{
      if(active){try{db?.query('ROLLBACK');}catch(_){}}
      try{db?.close();}finally{_busy=false;}
    }
  }
  Future<List<FinanceSessionXiiiIntent>> pendingBound()=>_transaction((items)async=>(result:List<FinanceSessionXiiiIntent>.unmodifiable(items),next:null));
  @override Future<List<HistoryXiIntent>> pending()async=>List.unmodifiable((await pendingBound()).map((i)=>i.history));
  @override Future<bool> prepare(HistoryXiIntent intent)=>_transaction((items)async{
    if(intent.receipt.actorUid!=ownerUid || intent.receipt.teamId!=teamId)throw const FinanceRefusal('native_v2_wrong_scope');
    if(utf8.encode(intent.encode()).length>16384)throw const FinanceRefusal('native_v2_intent_too_large');
    for(final old in items){
      if(old.history.receipt.operationId==intent.receipt.operationId){
        if(old.history.encode()!=intent.encode())throw const FinanceRefusal('native_v2_identity_reuse');
        return (result:false,next:null); // Never rebind an old record to a new epoch.
      }
      if(old.history.receipt.targetPath==intent.receipt.targetPath)throw const FinanceRefusal('native_v2_unresolved_target');
    }
    return (result:true,next:[...items,FinanceSessionXiiiIntent(history:intent,binding:binding)]);
  });
  @override Future<bool> confirm(HistoryXiIntent intent)=>_transaction((items)async{
    if(intent.receipt.actorUid!=ownerUid || intent.receipt.teamId!=teamId)throw const FinanceRefusal('native_v2_wrong_scope');
    final found=items.where((i)=>i.history.receipt.operationId==intent.receipt.operationId).toList();
    if(found.isEmpty)return (result:false,next:null);
    if(found.single.history.encode()!=intent.encode())throw const FinanceRefusal('native_v2_identity_reuse');
    return (result:true,next:items.where((i)=>!identical(i,found.single)).toList());
  });
}
