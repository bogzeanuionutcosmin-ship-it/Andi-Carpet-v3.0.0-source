import 'dart:async';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';

// Optimistic, versioned, atomic fake. No SDK or server billing is simulated.
class FinanceAtomicFixture implements FinanceAtomicPort {
  final documents = <String,Map<String,Object?>>{};
  final versions = <String,int>{};
  int calls=0, reads=0, writes=0, callbacks=0, serverReads=0;
  bool commitThenThrow=false, failBeforeCommit=false, fromCache=false, pending=false;
  Future<void> Function()? beforeCommit;
  Future<void> Function(String)? beforeRead;
  Future<void> Function()? beforeServerReturn;
  void seed(String path,Map<String,Object?> data){documents[path]=data;versions[path]=(versions[path]??0)+1;}
  @override Future<T> atomic<T>(Future<T> Function(FinanceTransaction) action) async {
    calls++;
    for(var attempt=0;attempt<3;attempt++){
      callbacks++;final tx=_Tx(this);final result=await action(tx);
      await beforeCommit?.call();
      if(tx.seen.entries.any((e)=>(versions[e.key]??0)!=e.value))continue;
      if(failBeforeCommit)throw TimeoutException('synthetic before commit');
      for(final entry in tx.pending.entries){seed(entry.key,entry.value);writes++;}
      if(commitThenThrow)throw TimeoutException('synthetic lost ack');
      return result;
    }
    throw StateError('synthetic transaction contention exhausted');
  }
  @override Future<FinanceServerObservation> readServer(String path) async {
    serverReads++;final value=documents[path];await beforeServerReturn?.call();
    return FinanceServerObservation(value,fromCache:fromCache,pendingWrites:pending);
  }
}
class _Tx implements FinanceTransaction {
  final FinanceAtomicFixture db;
  final seen=<String,int>{};final pending=<String,Map<String,Object?>>{};
  _Tx(this.db);
  @override Future<Map<String,Object?>?> read(String path) async {
    if(pending.isNotEmpty)throw StateError('read after write');
    await db.beforeRead?.call(path);db.reads++;seen[path]=db.versions[path]??0;
    final value=db.documents[path];return value==null?null:Map<String,Object?>.from(freezeFinanceValue(value) as Map);
  }
  @override void write(String path,Map<String,Object?> value){pending[path]=Map<String,Object?>.from(freezeFinanceValue(value) as Map);}
}
