import 'dart:convert';
import 'finance_intent.dart';
import 'finance_repository.dart';

class FinanceLedgerRow {
  final String id;
  final Map<String,Object?> data;
  FinanceLedgerRow(this.id,Map<String,Object?> data):data=freezeFinanceValue(data) as Map<String,Object?>;
  @override String toString()=>'FinanceLedgerRow';
}
class FinanceLedgerObservation {
  final List<FinanceLedgerRow> rows;
  final bool fromCache,pendingWrites;
  FinanceLedgerObservation(List<FinanceLedgerRow> rows,{this.fromCache=false,this.pendingWrites=false})
    :rows=List.unmodifiable(rows);
}
abstract interface class FinanceLedgerPort {
  Future<FinanceServerObservation> target(String path);
  Future<FinanceLedgerObservation> page(String path,int maximumRevision,int limit);
}
class FinanceLedgerCursor {
  final Object _scope;
  final String targetPath,teamId,latestOperationId;
  final int upperRevision,nextRevision;
  FinanceLedgerCursor._(this._scope,this.targetPath,this.teamId,this.latestOperationId,this.upperRevision,this.nextRevision);
}
class FinanceLedgerPage {
  final List<FinanceLedgerRow> rows;
  final FinanceLedgerCursor? next;
  final int upperRevision;
  // Completeness ONLY for marker revisions 1..upperRevision, never a backup or
  // proof of aggregate-only legacy money. No financial payload is reconstructed.
  bool get completeThroughUpperRevision=>next==null;
  FinanceLedgerPage._(List<FinanceLedgerRow> rows,this.next,this.upperRevision):rows=List.unmodifiable(rows);
}
bool _id(Object? value)=>value is String&&value.isNotEmpty&&value.length<=128&&!value.contains('/');

// Pass the actual AuthGate ownership closure, including its epoch.
// Read-only, explicit, bounded Admin review of ONE target's immutable markers.
// Appending newer revisions cannot shift the captured upper revision. This is
// not a collection scan, export, full snapshot, migration or history deletion.
class FinanceLedgerReader {
  final FinanceLedgerPort port;
  final bool Function() _owner;
  bool _open=true;
  bool sessionIsCurrent()=>_open&&_owner();
  void invalidate(){_scope=Object();}
  void dispose(){_open=false;invalidate();}
  final int pageSize;
  Object _scope=Object();
  FinanceLedgerReader({required this.port,required bool Function() sessionIsCurrent,this.pageSize=20}):_owner=sessionIsCurrent {
    if(pageSize<1||pageSize>20)throw ArgumentError('finance_ledger_page_limit');
  }
  void _guard([Object? epoch]){if(!sessionIsCurrent()||(epoch!=null&&!identical(epoch,_scope)))throw const FinanceRefusal('finance_session_expired');}
  Future<FinanceLedgerPage> firstExplicitly(String path) async {
    final epoch=_scope;_guard(epoch);
    if(!RegExp(r'^(finance|settlements)/[^/]{1,128}$').hasMatch(path))throw const FinanceRefusal('finance_invalid_path');
    final observed=await port.target(path);_guard(epoch);
    final data=observed.data;
    if(observed.fromCache||observed.pendingWrites||data==null)throw const FinanceRefusal('finance_ledger_server_required');
    final revision=data['revision']??0,team=data['teamId'],last=data['lastOperationId'];
    if(revision is! int||revision<0||revision>9007199254740991||!_id(team)||
        (path.startsWith('finance/')&&path.split('/').last!=team)||
        (revision==0&&last!=null)||
        (revision>0&&(last is! String||!RegExp(r'^[a-f0-9]{32}$').hasMatch(last)))) {
      throw const FinanceRefusal('finance_ledger_invalid_target');
    }
    if(revision==0)return FinanceLedgerPage._([],null,0);
    return nextExplicitly(FinanceLedgerCursor._(epoch,path,team as String,last as String,revision,revision));
  }
  Future<FinanceLedgerPage> nextExplicitly(FinanceLedgerCursor cursor) async {
    _guard();
    if(!identical(cursor._scope,_scope))throw const FinanceRefusal('finance_ledger_scope_mismatch');
    final observed=await port.page(cursor.targetPath,cursor.nextRevision,pageSize);_guard(cursor._scope);
    if(observed.fromCache||observed.pendingWrites)throw const FinanceRefusal('finance_ledger_server_required');
    final count=cursor.nextRevision<pageSize?cursor.nextRevision:pageSize;
    if(observed.rows.length!=count)throw const FinanceRefusal('finance_ledger_gap_or_limit');
    var expected=cursor.nextRevision,bytes=0;
    for(final row in observed.rows) {
      final d=row.data,digest=d['digest'];
      bytes+=utf8.encode(canonicalFinanceJson(d)).length;
      if(bytes>64*1024)throw const FinanceRefusal('finance_ledger_page_capacity');
      if(d.keys.any((k)=>!const {'operationId','actorUid','teamId','targetPath','revision','baseRevision','kind','digest','createdAt'}.contains(k))||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(row.id)||d['operationId']!=row.id||
          d['targetPath']!=cursor.targetPath||d['teamId']!=cursor.teamId||!_id(d['actorUid'])||
          d['revision'] is! int||d['baseRevision'] is! int||d['revision']!=expected||d['baseRevision']!=expected-1||
          digest is! String||!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)||
          !FinanceIntentKind.values.any((kind)=>kind.name==d['kind'])||
          (cursor.targetPath.startsWith('finance/')&&d['kind']!='receipt')||
          (expected==cursor.upperRevision&&row.id!=cursor.latestOperationId)) {
        throw const FinanceRefusal('finance_ledger_invalid_evidence');
      }
      expected--;
    }
    return FinanceLedgerPage._(observed.rows,expected==0?null:FinanceLedgerCursor._(
      _scope,cursor.targetPath,cursor.teamId,cursor.latestOperationId,cursor.upperRevision,expected),cursor.upperRevision);
  }
}
