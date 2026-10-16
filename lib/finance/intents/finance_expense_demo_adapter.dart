import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../main.dart' show TravelSettlement, TeamFinance, ReceivedMoneyEntry, FinanceSaveRejected;
import 'finance_demo_panel.dart';
import 'finance_intent.dart';
import 'finance_journal.dart';
import 'finance_repository.dart';

Map<String,Object?> _entry(ReceivedMoneyEntry e)=>{'id':e.id,'kind':e.kind,
  'amount':e.amount,'method':e.method,'fromName':e.fromName,'date':e.date};
Map<String,Object?> _finance(TeamFinance f)=>{'teamId':f.teamId,'managerId':f.managerId,
  'perDiemRate':f.perDiemRate,'receivedDeparture':f.receivedDeparture,
  'receivedDuring':f.receivedDuring,'receivedOpeningDeparture':f.receivedOpeningDeparture,
  'receivedOpeningDuring':f.receivedOpeningDuring,'receivedEntries':f.receivedEntries.map(_entry).toList()};
Map<String,Object?> _settlement(TravelSettlement s)=>{'teamId':s.teamId,'managerId':s.managerId,
  'perDiemRate':s.perDiemRate,'receivedDeparture':s.receivedDeparture,
  'receivedDuring':s.receivedDuring,'receivedOpeningDeparture':s.receivedOpeningDeparture,
  'receivedOpeningDuring':s.receivedOpeningDuring,'receivedEntries':s.receivedEntries.map(_entry).toList(),
  'name':s.name,'startDate':s.startDate,'endDate':s.endDate,'closed':s.closed,'createdAt':s.createdAt};
Object? _display(Object? value) {
  if(value is FinanceTimestamp)return DateTime.fromMicrosecondsSinceEpoch(
    value.seconds*1000000+value.nanoseconds~/1000,isUtc:true);
  if(value is List)return value.map(_display).toList();
  if(value is Map)return value.map((k,v)=>MapEntry(k as String,_display(v)));
  return value;
}
class _Baseline {
  final Map<String,Object?> data,model;
  _Baseline(Map<String,Object?> data,Map<String,Object?> model)
    : data=freezeFinanceValue(data) as Map<String,Object?>,
      model=freezeFinanceValue(model) as Map<String,Object?>;
}
class _Save {
  final FinanceIntent intent;
  final done=Completer<void>();
  bool busy=false,confirmed=false,cleanupPending=false;
  String code='finance_pending';
  _Save(this.intent);
}

// Explicit DEMO composition for the existing ExpensePage callback signatures.
// Production Home never constructs this adapter. Bind ExpensePage's session
// guard to the SAME scope. acceptServerSnapshot must replace mutable UI models.
class FinanceExpenseDemoAdapter extends ChangeNotifier {
  final FinanceDemoScope scope;
  final FinanceAtomicPort port;
  final Future<void> Function(String path,Map<String,Object?> data) acceptServerSnapshot;
  // Optional synchronous read-back of the model actually installed by the UI.
  // Returns TravelSettlement/TeamFinance; never performs a network read.
  final Object? Function(String path)? readAcceptedModel;
  // Optional TEST/DEMO-only status listener. Receives only the status enum,
  // never the finance intent, amount, actor UID, server code or error message.
  // Monitoring must be best-effort and cannot alter a financial outcome.
  final void Function(FinanceIntentStatus)? observeStatus;
  bool _open=true;
  bool recoveryBusy=false;
  String? recoveryCode;
  // Local recovery is explicit and read-only: never execute an old request or
  // invent an ID while recreating a view/account scope.
  Future<void> loadPendingForReviewExplicitly() async {
    _guard();if(recoveryBusy)return;
    recoveryBusy=true;_notify();
    try {
      final pending=await scope.coordinator.journal.pending();_guard();
      final paths={..._saves.keys,...pending.map((i)=>i.targetPath)};
      if(paths.length>FinanceIntentJournal.maxPending)throw const FinanceRefusal('finance_demo_scope_full');
      for(final intent in pending) {
        final current=_saves[intent.targetPath];
        if(current!=null&&current.intent.digest!=intent.digest)throw const FinanceRefusal('finance_unresolved_target');
      }
      // Validate the ENTIRE local manifest before attaching any request.
      for(final intent in pending) {
        _saves.putIfAbsent(intent.targetPath,()=>_Save(intent)..code='finance_result_uncertain');
      }
      recoveryCode=null;
    } catch(_) {
      if(_open&&scope.sessionIsCurrent())recoveryCode='finance_local_recovery_unavailable';
    } finally {recoveryBusy=false;_notify();}
  }
  bool isBusy(String path)=>_saves[path]?.busy??false;
  void _notify(){if(_open)notifyListeners();}
  @override void dispose(){_open=false;scope.dispose();super.dispose();}
  final _baselines=<String,_Baseline>{};
  final _saves=<String,_Save>{};
  FinanceExpenseDemoAdapter({required this.scope,required this.port,required this.acceptServerSnapshot,this.readAcceptedModel,this.observeStatus}) {
    if(!identical(scope.coordinator.repository.port,port))throw ArgumentError('finance_scope_port_mismatch');
  }
  Map<String,String> get pendingCodes=>Map.unmodifiable(_saves.map((p,s)=>MapEntry(p,s.code)));
  void _guard(){if(!_open||!scope.sessionIsCurrent())throw FinanceSaveRejected('finance_session_expired');}
  void observeSettlement(TravelSettlement model,FinanceServerObservation server)=>
    _observe('settlements/${model.id}',_settlement(model),server);
  void observeFinance(TeamFinance model,FinanceServerObservation server)=>
    _observe('finance/${model.teamId}',_finance(model),server);
  void _observe(String path,Map<String,Object?> model,FinanceServerObservation server,{_Save? completedSave}) {
    _guard();
    if((_saves.containsKey(path)&&!identical(_saves[path],completedSave))||server.fromCache||server.pendingWrites||server.data==null)
      throw FinanceSaveRejected('finance_authoritative_refresh_required');
    final data=server.data!;
    // No evidence is inferred from a mutable UI object. Every represented field
    // must agree with the explicitly supplied server observation.
    for(final key in model.keys) {
      final value=data.containsKey(key)?data[key]:switch(key){
        'receivedEntries'=><Object?>[],
        'receivedDeparture'||'receivedDuring'||'receivedOpeningDeparture'||'receivedOpeningDuring'=>0,
        'closed'=>false,
        _=>null,
      };
      if(!sameFinanceValue(_display(value),model[key]))throw FinanceSaveRejected('finance_model_snapshot_mismatch');
    }
    if((data['revision']??0) is! int)throw FinanceSaveRejected('finance_invalid_revision');
    if(!_baselines.containsKey(path)&&_baselines.length>=32)throw FinanceSaveRejected('finance_demo_scope_full');
    _baselines[path]=_Baseline(data,model);
  }
  // Drops only a regenerable observation, never an unresolved intent/journal.
  bool forgetBaselineExplicitly(String path){
    _guard();
    if(_saves.containsKey(path))throw FinanceSaveRejected('finance_unresolved_target');
    return _baselines.remove(path)!=null;
  }
  void _captureAcceptedBaseline(String path,FinanceServerObservation server,_Save save){
    final read=readAcceptedModel;
    if(read==null){_baselines.remove(path);return;} // Existing explicit-observe API.
    final model=read(path);
    late final String modelPath;
    late final int? revision;
    late final String? operation;
    late final Map<String,Object?> represented;
    if(model is TravelSettlement){
      modelPath='settlements/${model.id}';revision=model.revision;operation=model.lastOperationId;represented=_settlement(model);
    } else if(model is TeamFinance){
      modelPath='finance/${model.teamId}';revision=model.revision;operation=model.lastOperationId;represented=_finance(model);
    } else {throw FinanceSaveRejected('finance_accepted_model_required');}
    if(modelPath!=path||revision!=server.data!['revision']||operation!=server.data!['lastOperationId'])
      throw FinanceSaveRejected('finance_accepted_model_mismatch');
    // _observe reuses the existing full model/value/metadata validation. The
    // exact completed request alone may replace its baseline before release.
    _observe(path,represented,server,completedSave:save);
  }
  // Wire this separately for the existing create dialog. Absence is checked
  // inside the same transaction; an existing target can never be overwritten.
  Future<void> createSettlement(TravelSettlement model) {
    _guard();final path='settlements/${model.id}';
    if(_saves.containsKey(path))throw FinanceSaveRejected('finance_unresolved_target');
    if(_saves.length>=32||(readAcceptedModel!=null&&!_baselines.containsKey(path)&&_baselines.length>=32))
      throw FinanceSaveRejected('finance_demo_scope_full');
    final intent=FinanceIntent(operationId:FinanceIntent.newOperationId(),actorUid:scope.ownerUid,
      teamId:model.teamId,collection:'settlements',documentId:model.id,baseRevision:0,
      kind:FinanceIntentKind.create,changes:{'name':model.name,'startDate':model.startDate,
        'endDate':model.endDate,'createdAt':model.createdAt,'managerId':model.managerId,
        'perDiemRate':model.perDiemRate});
    try {
      final expected=applyFinanceIntent(intent,null),candidate=_settlement(model);
      if(model.revision!=null&&model.revision!=0)throw const FinanceRefusal('finance_invalid_creation');
      for(final key in candidate.keys) {
        if(!sameFinanceValue(expected[key],candidate[key]))throw const FinanceRefusal('finance_invalid_creation');
      }
    } on Object {throw FinanceSaveRejected('finance_invalid_creation');}
    final save=_Save(intent);_saves[path]=save;unawaited(_run(path,save,false));return save.done.future;
  }
  Future<void> saveSettlement(TravelSettlement model)=>_save('settlements/${model.id}',_settlement(model));
  Future<void> saveFinance(TeamFinance model)=>_save('finance/${model.teamId}',_finance(model));
  Future<void> _save(String path,Map<String,Object?> candidate) {
    _guard();
    if(_saves.containsKey(path))throw FinanceSaveRejected('finance_unresolved_target');
    if(_saves.length>=FinanceIntentJournal.maxPending)throw FinanceSaveRejected('finance_demo_scope_full');
    final baseline=_baselines[path];
    if(baseline==null)throw FinanceSaveRejected('finance_authoritative_refresh_required');
    final before=baseline.model;
    final changed=candidate.keys.where((k)=>!sameFinanceValue(before[k],candidate[k])).toSet();
    late final FinanceIntentKind kind;
    late final Map<String,Object?> changes;
    if(changed.contains('receivedEntries')) {
      kind=FinanceIntentKind.receipt;
      if(changed.any((k)=>!{'receivedEntries','receivedDeparture','receivedDuring'}.contains(k)))
        throw FinanceSaveRejected('finance_mixed_action');
      final old=before['receivedEntries'] as List,entries=candidate['receivedEntries'] as List;
      if(entries.length!=old.length+1||!sameFinanceValue(entries.take(old.length).toList(),old))
        throw FinanceSaveRejected('finance_history_replacement_forbidden');
      changes=Map<String,Object?>.from(entries.last as Map)..remove('id');
    } else if(changed.contains('closed')) {
      kind=FinanceIntentKind.close;
      if(changed.any((k)=>!{'closed','endDate'}.contains(k)))throw FinanceSaveRejected('finance_mixed_action');
      changes={'closed':candidate['closed'],'endDate':candidate['endDate']};
    } else {
      kind=FinanceIntentKind.edit;
      if(changed.isEmpty||changed.any((k)=>!{'name','startDate','endDate'}.contains(k)))
        throw FinanceSaveRejected('finance_unsupported_action');
      changes={for(final key in changed)key:candidate[key]};
    }
    final parts=path.split('/');
    final intent=FinanceIntent(operationId:FinanceIntent.newOperationId(),actorUid:scope.ownerUid,
      teamId:candidate['teamId'] as String,collection:parts[0],documentId:parts[1],
      baseRevision:(baseline.data['revision']??0) as int,kind:kind,changes:changes);
    // Validate the exact transition before storing or executing any request.
    try {
      final next=applyFinanceIntent(intent,baseline.data);
      for(final key in candidate.keys.where((k)=>k!='receivedEntries')) {
        if(!sameFinanceValue(_display(next.containsKey(key)?next[key]:before[key]),candidate[key]))throw const FinanceRefusal('finance_model_transition_mismatch');
      }
    } on Object {throw FinanceSaveRejected('finance_model_transition_rejected');}
    final save=_Save(intent);_saves[path]=save;
    unawaited(_run(path,save,false));
    return save.done.future;
  }
  Future<void> reconcileExplicitly(String path) async {
    _guard();final save=_saves[path];
    if(save!=null&&!save.busy)await _run(path,save,true);
  }
  Future<void> _run(String path,_Save save,bool reconcile) async {
    if(save.busy||!scope.sessionIsCurrent())return;
    save.busy=true;_notify();
    try {
      // A confirmed operation is never retransmitted to repair local storage.
      // Only an explicit recovery action may retry the local journal cleanup.
      if(save.confirmed&&save.cleanupPending){
        if(!reconcile)return;
        try {
          await scope.coordinator.journal.recordResult(save.intent,
            const FinanceIntentResult(FinanceIntentStatus.confirmed,'finance_confirmed'));
        } catch(_) {
          save.code='finance_confirmed_local_cleanup_required';return;
        }
        if(!scope.sessionIsCurrent())return;
        save.cleanupPending=false;
      }
      final outcome=save.confirmed?null:(reconcile?await scope.coordinator.reconcileExplicitly(save.intent):
        await scope.coordinator.executeExplicitly(save.intent));
      if(!scope.sessionIsCurrent())return;
      if(outcome!=null) {
        save.code=outcome.result.code;
        try {
          observeStatus?.call(outcome.result.status);
        } catch (_) {
          // Telemetry cannot block, confirm or roll back a financial write.
        }
        // The optional observer may synchronously revoke its own session.
        if(!scope.sessionIsCurrent())return;
      }
      if(outcome!=null&&outcome.result.status==FinanceIntentStatus.rejectedBeforeWrite&&
          (!outcome.journalPending||outcome.blockedByPendingIntent)) {
        _saves.remove(path);
        save.done.completeError(FinanceSaveRejected(save.code));return;
      }
      if(outcome!=null&&outcome.result.status!=FinanceIntentStatus.confirmed)return;
      save.confirmed=true;
      if(outcome?.journalPending==true){
        save.cleanupPending=true;
        save.code='finance_confirmed_local_cleanup_required';return;
      }
      // A marker confirms the operation, not the latest display snapshot.
      final server=await port.readServer(path);
      if(!scope.sessionIsCurrent())return;
      final data=server.data;
      if(server.fromCache||server.pendingWrites||data==null||data['teamId']!=save.intent.teamId||
          data['revision'] is! int||(data['revision'] as int)<save.intent.baseRevision+1) {
        save.code='finance_authoritative_refresh_required';return;
      }
      final acceptedData=freezeFinanceValue(data) as Map<String,Object?>;
      await acceptServerSnapshot(path,acceptedData);
      if(!scope.sessionIsCurrent())return;
      _captureAcceptedBaseline(path,FinanceServerObservation(acceptedData,
        fromCache:server.fromCache,pendingWrites:server.pendingWrites),save);
      _saves.remove(path);save.done.complete();
    } catch(_) {
      // Never send a generic error into the old close-dialog rollback path.
      save.code=save.confirmed?
        (save.cleanupPending?'finance_confirmed_local_cleanup_required':'finance_authoritative_refresh_required'):
        'finance_result_uncertain';
    } finally {save.busy=false;_notify();}
  }
}
