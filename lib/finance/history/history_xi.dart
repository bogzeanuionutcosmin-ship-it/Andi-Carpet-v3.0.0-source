import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../intents/finance_intent.dart';
import '../intents/finance_repository.dart';

// Isolated protocol candidate. Receipt document IS the immutable operation
// marker; summary + receipt are one commit. No arrays, migration or activation.
// Never feed a v1 pending journal into this protocol. V2 recovery requires this
// explicit versioned envelope, not merely an equal amount/operation ID.
class HistoryXiIntent {
  final FinanceIntent receipt;
  HistoryXiIntent(FinanceIntent input) : receipt=_normalize(input) {
    if (receipt.kind != FinanceIntentKind.receipt) throw const FormatException('history_receipt_only');
    final c=receipt.changes;
    if(c.length!=5 || !c.keys.toSet().containsAll({'kind','amount','method','fromName','date'}) ||
      !['departure','during'].contains(c['kind']) || !['Cash','Transfer'].contains(c['method']) ||
      c['amount'] is! num || !(c['amount'] as num).isFinite || (c['amount'] as num)<=0 ||
      c['fromName'] is! String || (c['fromName'] as String).trim().isEmpty ||
      (c['date'] is! DateTime && c['date'] is! FinanceTimestamp)) {
      throw const FormatException('history_invalid_receipt');
    }
  }
  static FinanceIntent _normalize(FinanceIntent input){
    final value=input.changes['date'];
    FinanceTimestamp exact;
    if(value is FinanceTimestamp){exact=value;}
    else if(value is DateTime){
      final micros=value.toUtc().microsecondsSinceEpoch;
      var seconds=micros~/1000000;
      if(micros<0 && micros%1000000!=0)seconds--;
      exact=FinanceTimestamp(seconds,(micros-seconds*1000000)*1000);
    }else{throw const FormatException('history_exact_date_required');}
    return FinanceIntent(operationId:input.operationId,actorUid:input.actorUid,
      teamId:input.teamId,collection:input.collection,documentId:input.documentId,
      baseRevision:input.baseRevision,kind:input.kind,changes:{...input.changes,'date':exact});
  }
  String get summaryPath=>'financeHistoryXi/${receipt.collection=='finance'?'f':'s'}_${receipt.documentId}';
  String get rowPath=>'$summaryPath/receipts/${receipt.operationId}';
  String encode()=>canonicalFinanceJson({'protocol':2,'receipt':receipt.toMap()});
  factory HistoryXiIntent.decode(String raw) {
    final d=decodeCanonicalFinanceJson(raw);
    if(d is! Map || d.length!=2 || d['protocol']!=2 || d['receipt'] is! Map) {
      throw const FormatException('history_protocol_required');
    }
    return HistoryXiIntent(FinanceIntent.decode(canonicalFinanceJson(d['receipt'])));
  }
  String get digest=>sha256.convert(utf8.encode(encode())).toString();
  Map<String,Object?> row()=>{'protocol':2,'operationId':receipt.operationId,
    'digest':digest,'actorUid':receipt.actorUid,'teamId':receipt.teamId,
    'targetPath':receipt.targetPath,'baseRevision':receipt.baseRevision,
    'revision':receipt.baseRevision+1,...receipt.changes,
    // Native SDK timestamps may be canonicalized to microseconds. Preserve the
    // exact integer representation in this NEW protocol's immutable payload.
    'date':{'seconds':(receipt.changes['date'] as FinanceTimestamp).seconds,
      'nanoseconds':(receipt.changes['date'] as FinanceTimestamp).nanoseconds}};
  @override String toString()=>'HistoryXiIntent';
}

FinanceTimestamp _exactRowDate(Object? value){
  if(value is! Map || value.length!=2 || value['seconds'] is! int || value['nanoseconds'] is! int) {
    throw const FinanceRefusal('history_invalid_date');
  }
  return FinanceTimestamp(value['seconds'] as int,value['nanoseconds'] as int);
}
const _summaryKeys={'protocol','teamId','sourceCollection','sourceId','revision',
  'receivedDeparture','receivedDuring','lastOperationId','updatedAt'};
bool _money(Object? v)=>v is num && v.isFinite && v>=0;
void validateHistoryXiSummary(Map<String,Object?> data,HistoryXiIntent i) {
  final rev=data['revision'];
  if(data.keys.any((k)=>!_summaryKeys.contains(k)) || data['protocol']!=2 ||
    data['teamId']!=i.receipt.teamId || data['sourceCollection']!=i.receipt.collection ||
    data['sourceId']!=i.receipt.documentId || rev is! int || rev<1 || rev>9007199254740991 ||
    !_money(data['receivedDeparture']) || !_money(data['receivedDuring']) ||
    data['lastOperationId'] is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(data['lastOperationId'] as String)) {
    throw const FinanceRefusal('history_invalid_summary');
  }
}
Map<String,Object?> historyXiNext(HistoryXiIntent intent,Map<String,Object?>? old) {
  final i=intent.receipt;
  if(old!=null)validateHistoryXiSummary(old,intent);
  if((old?['revision']??0)!=i.baseRevision)throw const FinanceRevisionConflict();
  final departure=(old?['receivedDeparture'] as num? ?? 0).toDouble();
  final during=(old?['receivedDuring'] as num? ?? 0).toDouble();
  final amount=(i.changes['amount'] as num).toDouble();
  final nextDeparture=departure+(i.changes['kind']=='departure'?amount:0);
  final nextDuring=during+(i.changes['kind']=='during'?amount:0);
  if(!nextDeparture.isFinite || !nextDuring.isFinite ||
      (i.changes['kind']=='departure'?nextDeparture<=departure:nextDuring<=during)) {
    throw const FinanceRefusal('history_precision_or_overflow');
  }
  return Map.unmodifiable({'protocol':2,'teamId':i.teamId,'sourceCollection':i.collection,
    'sourceId':i.documentId,'revision':i.baseRevision+1,'lastOperationId':i.operationId,
    'receivedDeparture':nextDeparture,'receivedDuring':nextDuring});
}

class FinanceHistoryXiRepository {
  final FinanceAtomicPort port;
  final String ownerUid;
  final bool Function() _owner;
  bool _open=true;
  FinanceHistoryXiRepository({required this.port,required this.ownerUid,
    required bool Function() sessionIsCurrent}):_owner=sessionIsCurrent;
  bool _current(){
    if(!_open)return false;
    try {if(!_owner())_open=false;}catch(_){_open=false;}
    return _open;
  }
  void dispose(){_open=false;}
  void _guard(HistoryXiIntent i){
    if(!_current() || i.receipt.actorUid!=ownerUid)throw const FinanceRefusal('history_session_expired');
  }
  bool _matches(HistoryXiIntent i,Map<String,Object?> row)=>
    sameFinanceValue({for(final e in row.entries)if(e.key!='createdAt')e.key:e.value},i.row());
  Future<FinanceIntentResult> executeExplicitly(HistoryXiIntent i) async {
    var scheduled=false,started=false;
    try {
      _guard(i);
      started=true;
      final replayed=await port.atomic((tx) async {
        _guard(i);
        final row=await tx.read(i.rowPath);_guard(i);
        final summary=await tx.read(i.summaryPath);_guard(i);
        if(summary!=null)validateHistoryXiSummary(summary,i);
        if(row!=null){
          if(!_matches(i,row) || summary==null || (summary['revision'] as int)<i.receipt.baseRevision+1) {
            throw const FinanceRevisionConflict();
          }
          return true;
        }
        if(summary==null){
          final legacy=await tx.read(i.receipt.targetPath);_guard(i);
          // Only a genuinely empty existing source is eligible for this demo.
          // Existing money/history needs a separately approved migration.
          if(legacy==null || legacy['teamId']!=i.receipt.teamId || legacy['closed']==true ||
            (legacy['receivedDeparture']??0)!=0 || (legacy['receivedDuring']??0)!=0 ||
            (legacy['receivedOpeningDeparture']??0)!=0 || (legacy['receivedOpeningDuring']??0)!=0 ||
            (legacy['receivedEntries'] is List && (legacy['receivedEntries'] as List).isNotEmpty) ||
            (legacy['receivedEntries']!=null && legacy['receivedEntries'] is! List) ||
            (legacy['revision']??0)!=0)throw const FinanceRefusal('history_legacy_requires_migration');
        }
        final next=historyXiNext(i,summary);_guard(i);
        scheduled=true;tx.write(i.summaryPath,next);tx.write(i.rowPath,i.row());
        return false;
      });
      if(!_current())return const FinanceIntentResult(FinanceIntentStatus.uncertain,'history_session_expired');
      return FinanceIntentResult(FinanceIntentStatus.confirmed,'history_confirmed',
        revision:i.receipt.baseRevision+1,replayed:replayed);
    }on FinanceRevisionConflict{
      return FinanceIntentResult(scheduled?FinanceIntentStatus.uncertain:FinanceIntentStatus.conflict,
        scheduled?'history_uncertain':'history_revision_conflict');
    }on FinanceRefusal catch(e){
      final uncertain=scheduled || (started && e.code=='history_session_expired');
      return FinanceIntentResult(uncertain?FinanceIntentStatus.uncertain:FinanceIntentStatus.rejectedBeforeWrite,
        uncertain?'history_uncertain':e.code);
    }catch(_){return const FinanceIntentResult(FinanceIntentStatus.uncertain,'history_uncertain');}
  }
  Future<FinanceIntentResult> reconcileExplicitly(HistoryXiIntent i) async {
    try{
      _guard(i);final row=await port.readServer(i.rowPath);_guard(i);
      if(row.fromCache || row.pendingWrites || row.data==null) {
        return const FinanceIntentResult(FinanceIntentStatus.uncertain,'history_uncertain');
      }
      if(!_matches(i,row.data!))return const FinanceIntentResult(FinanceIntentStatus.conflict,'history_evidence_mismatch');
      final summary=await port.readServer(i.summaryPath);_guard(i);
      if(summary.fromCache || summary.pendingWrites || summary.data==null) {
        return const FinanceIntentResult(FinanceIntentStatus.uncertain,'history_uncertain');
      }
      validateHistoryXiSummary(summary.data!,i);
      if((summary.data!['revision'] as int)<i.receipt.baseRevision+1) {
        return const FinanceIntentResult(FinanceIntentStatus.conflict,'history_evidence_mismatch');
      }
      return FinanceIntentResult(FinanceIntentStatus.confirmed,'history_confirmed',revision:i.receipt.baseRevision+1,replayed:true);
    }catch(_){return const FinanceIntentResult(FinanceIntentStatus.uncertain,'history_uncertain');}
  }
}

// Bounded-memory audit of a pinned summary. A partial page is never a complete
// financial view. Caller supplies ONLY server pages, newest to oldest.
class HistoryXiConsistency {
  final HistoryXiIntent binding;
  final Map<String,Object?> summary;
  late int _next;
  double _departure=0,_during=0;
  bool _valid=true;
  HistoryXiConsistency(this.binding,Map<String,Object?> data)
    :summary=freezeFinanceValue(data) as Map<String,Object?> {
    validateHistoryXiSummary(summary,binding);_next=summary['revision'] as int;
  }
  bool get complete=>_valid && _next==0;
  void consume(List<Map<String,Object?>> rows,{bool fromCache=false,bool pendingWrites=false}){
    try{
      if(!_valid || _next==0 || fromCache || pendingWrites || rows.isEmpty || rows.length>20) {
        throw const FinanceRefusal('history_incomplete_or_cached');
      }
      for(final row in rows){
        final target=(row['targetPath'] as String).split('/');
        final i=HistoryXiIntent(FinanceIntent(operationId:row['operationId'] as String,
          actorUid:row['actorUid'] as String,teamId:row['teamId'] as String,collection:target[0],
          documentId:target[1],baseRevision:row['baseRevision'] as int,kind:FinanceIntentKind.receipt,
          changes:{for(final k in ['kind','amount','method','fromName'])k:row[k],
            'date':_exactRowDate(row['date'])}));
        if(row['revision']!=_next || i.receipt.baseRevision!=_next-1 ||
          i.summaryPath!=binding.summaryPath || i.receipt.teamId!=binding.receipt.teamId ||
          !sameFinanceValue({for(final e in row.entries)if(e.key!='createdAt')e.key:e.value},i.row()) ||
          (_next==summary['revision'] && row['operationId']!=summary['lastOperationId'])) {
          throw const FinanceRefusal('history_gap_or_binding');
        }
        final amount=(row['amount'] as num).toDouble();
        if(row['kind']=='departure'){_departure+=amount;}else{_during+=amount;}
        _next--;
      }
      // Floating sums follow the same accepted receipt order as the writer.
      // Reverse-order floating arithmetic may differ: refuse a proof rather
      // than round or silently reinterpret stored money.
      if(_next==0 && (_departure!=summary['receivedDeparture'] || _during!=summary['receivedDuring'])) {
        throw const FinanceRefusal('history_summary_mismatch');
      }
    }catch(_){_valid=false;throw const FinanceRefusal('history_consistency_unproven');}
  }
}
