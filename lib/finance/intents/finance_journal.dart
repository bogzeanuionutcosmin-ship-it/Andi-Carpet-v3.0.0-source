import 'dart:async';
import 'dart:convert';
import 'finance_intent.dart';
import 'finance_repository.dart';

// Implementations must use private durable storage. A completed write must mean
// the exact value is durable; a failed write never authorizes server execution.
abstract interface class FinanceJournalStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
class FinanceIntentJournal {
  final FinanceJournalStorage storage;
  final String ownerUid;
  final bool Function() sessionIsCurrent;
  static final _queues = <String, Future<void>>{};
  static const maxPending = 32, maxBytes = 128 * 1024;
  FinanceIntentJournal({required this.storage,required this.ownerUid,required this.sessionIsCurrent}) {
    if(ownerUid.isEmpty || ownerUid.contains('/') || ownerUid.length>128) throw ArgumentError('finance_invalid_owner');
  }
  String get _key => 'finance_intents_v1_$ownerUid';
  void _guard(){if(!sessionIsCurrent())throw const FinanceRefusal('finance_session_expired');}
  Future<T> _locked<T>(Future<T> Function() action) {
    final result=Completer<T>();
    final previous=_queues[_key]??Future<void>.value();
    final next=previous.then((_) async {
      try {result.complete(await action());}catch(error,stack){result.completeError(error,stack);}
    });
    _queues[_key]=next;
    next.then((_){if(identical(_queues[_key],next))_queues.remove(_key);});
    return result.future;
  }
  Future<List<FinanceIntent>> _read() async {
    _guard();final raw=await storage.read(_key);_guard();
    if(raw==null)return [];
    if(utf8.encode(raw).length>maxBytes)throw const FinanceRefusal('finance_journal_corrupt');
    try {
      final map=jsonDecode(raw) as Map;
      if(map['version']!=1 || map['ownerUid']!=ownerUid || map.length!=3)throw const FormatException();
      final items=(map['intents'] as List).map((item)=>FinanceIntent.decode(item as String)).toList();
      if(items.length>maxPending || items.any((i)=>i.actorUid!=ownerUid) ||
        items.map((i)=>i.operationId).toSet().length!=items.length ||
        items.map((i)=>i.targetPath).toSet().length!=items.length)throw const FormatException();
      return items;
    }catch(_){throw const FinanceRefusal('finance_journal_corrupt');}
  }
  Future<void> _write(List<FinanceIntent> items) async {
    _guard();final raw=jsonEncode({'version':1,'ownerUid':ownerUid,'intents':items.map((i)=>i.encode()).toList()});
    if(items.length>maxPending || utf8.encode(raw).length>maxBytes)throw const FinanceRefusal('finance_journal_full');
    await storage.write(_key,raw);_guard();
  }
  Future<List<FinanceIntent>> pending() => _locked(() async=>List.unmodifiable(await _read()));
  Future<void> prepare(FinanceIntent intent) => _locked(() async {
    _guard();if(intent.actorUid!=ownerUid)throw const FinanceRefusal('finance_wrong_owner');
    final items=await _read();
    for(final old in items){
      if(old.operationId==intent.operationId){
        if(old.digest!=intent.digest)throw const FinanceRefusal('finance_identity_reuse');
        return;
      }
      if(old.targetPath==intent.targetPath)throw const FinanceRefusal('finance_unresolved_target');
    }
    await _write([...items,intent]);
  });
  Future<void> recordResult(FinanceIntent intent,FinanceIntentResult result) => _locked(() async {
    _guard();if(intent.actorUid!=ownerUid)throw const FinanceRefusal('finance_wrong_owner');
    // Uncertainty and revision conflicts retain the exact request for review.
    if(result.status!=FinanceIntentStatus.confirmed && result.status!=FinanceIntentStatus.rejectedBeforeWrite)return;
    final items=await _read();
    final existing=items.where((i)=>i.operationId==intent.operationId);
    if(existing.isEmpty)return;
    if(existing.single.digest!=intent.digest)throw const FinanceRefusal('finance_identity_reuse');
    await _write(items.where((i)=>i.operationId!=intent.operationId).toList());
  });
}
