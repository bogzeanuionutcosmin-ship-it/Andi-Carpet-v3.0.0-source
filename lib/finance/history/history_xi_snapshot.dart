import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../intents/finance_intent.dart';
import '../intents/finance_repository.dart';
import 'history_xi.dart';

// Review-only, bounded-memory certificate for ONE immutable receipt prefix.
// Not a backup of all targets, not a write/restore capability, not a signature.
// Any future restore must compare the pinned summary inside its own atomic
// commit and must not overwrite/delete financial rows or local pending work.
class HistoryXiPrefixProof {
  final String summaryPath,orderedDigest;
  final Map<String,Object?> summary;
  final int receiptCount;
  HistoryXiPrefixProof._(this.summaryPath,this.summary,this.orderedDigest,this.receiptCount);
  bool matchesCurrent(FinanceServerObservation current)=>!current.fromCache &&
    !current.pendingWrites && current.data!=null && sameFinanceValue(current.data,summary);
  @override String toString()=>'HistoryXiPrefixProof';
}
class HistoryXiSnapshotReview {
  final HistoryXiIntent binding;
  late final HistoryXiConsistency _audit;
  late final Map<String,Object?> _summary;
  late String _digest;
  int _count=0;
  bool _failed=false,_sealed=false;
  HistoryXiSnapshotReview(this.binding,FinanceServerObservation observed){
    if(observed.fromCache || observed.pendingWrites || observed.data==null) {
      throw const FinanceRefusal('history_snapshot_server_required');
    }
    _summary=freezeFinanceValue(observed.data) as Map<String,Object?>;
    _audit=HistoryXiConsistency(binding,_summary);
    _digest=sha256.convert(utf8.encode(canonicalFinanceJson(_summary))).toString();
  }
  void addPage(List<Map<String,Object?>> rows,{bool fromCache=false,bool pendingWrites=false}){
    if(_failed || _sealed)throw const FinanceRefusal('history_snapshot_closed');
    try{
      _audit.consume(rows,fromCache:fromCache,pendingWrites:pendingWrites);
      for(final row in rows){
        _digest=sha256.convert(utf8.encode(_digest+canonicalFinanceJson(row))).toString();_count++;
      }
    }catch(_){_failed=true;rethrow;}
  }
  HistoryXiPrefixProof sealExplicitly(){
    if(_failed || !_audit.complete || _count!=_summary['revision']) {
      throw const FinanceRefusal('history_snapshot_incomplete');
    }
    _sealed=true;
    return HistoryXiPrefixProof._(binding.summaryPath,_summary,_digest,_count);
  }
}
