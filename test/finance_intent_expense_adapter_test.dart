import 'dart:convert';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/finance/intents/finance_demo_panel.dart';
import 'package:andi_carpeta/finance/intents/finance_expense_demo_adapter.dart';
import 'package:andi_carpeta/finance/intents/finance_expense_demo_recovery.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/finance_atomic_fixture.dart';

class _Storage implements FinanceJournalStorage {
  final values=<String,String>{};
  int cleanupFailure=0;
  @override Future<String?> read(String key)async=>values[key];
  @override Future<void> write(String key,String value)async{
    if(cleanupFailure!=0&&((jsonDecode(value) as Map)['intents'] as List).isEmpty){
      if(cleanupFailure==2)values[key]=value;
      throw StateError('synthetic_local_cleanup_failure');
    }
    values[key]=value;
  }
}
class _Harness {
  final db=FinanceAtomicFixture(),storage=_Storage();
  final fixture=ExpenseDocumentFixture('');
  late FinanceDemoScope scope;
  late FinanceExpenseDemoAdapter adapter;
  bool current=true,failRefresh=false;
  int refreshes=0;
  Object? Function(String)? readModelOverride;
  final created=DateTime.utc(2026,10,1);
  _Harness(){
    final model=TravelSettlement(id:'settlement',teamId:'team',name:'Synthetic Trip',
      startDate:created,createdAt:created,managerId:'worker');
    fixture.settlementOverride=model;
    db.seed('settlements/settlement',{'teamId':'team','name':model.name,'startDate':created,
      'createdAt':created,'managerId':'worker','perDiemRate':model.perDiemRate,
      'closed':false,'endDate':null,'receivedDeparture':0,'receivedDuring':0,
      'receivedOpeningDeparture':0,'receivedOpeningDuring':0,'receivedEntries':<Object?>[]});
    scope=FinanceDemoScope(ownerUid:'worker',sessionIsCurrent:()=>current,port:db,storage:storage);
    adapter=FinanceExpenseDemoAdapter(scope:scope,port:db,
      readAcceptedModel:(path)=>readModelOverride==null?fixture.settlementOverride:readModelOverride!(path),
      acceptServerSnapshot:(path,data)async{
      if(failRefresh)throw StateError('synthetic_refresh_failure');
      refreshes++;
      fixture.settlementOverride=TravelSettlement(id:path.split('/').last,teamId:'team',name:data['name'] as String,
        startDate:data['startDate'] as DateTime,createdAt:data['createdAt'] as DateTime,
        managerId:data['managerId'] as String,closed:data['closed'] as bool,endDate:data['endDate'] as DateTime?,
        revision:data['revision'] as int,lastOperationId:data['lastOperationId'] as String,
        receivedDeparture:(data['receivedDeparture'] as num).toDouble(),
        receivedDuring:(data['receivedDuring'] as num).toDouble(),
        receivedEntries:(data['receivedEntries'] as List).map((raw){final e=raw as Map;
          return ReceivedMoneyEntry(id:e['id'] as String,kind:e['kind'] as String,
            amount:(e['amount'] as num).toDouble(),method:e['method'] as String,
            fromName:e['fromName'] as String,date:e['date'] as DateTime);}).toList());
      fixture.rebuild((){});
    });
    adapter.observeSettlement(model,FinanceServerObservation(db.documents['settlements/settlement'],fromCache:false,pendingWrites:false));
    fixture.saveSettlementOverride=(model)=>model.id=='settlement'?adapter.saveSettlement(model):adapter.createSettlement(model);
    fixture.diagnosticSessionIsCurrent=scope.sessionIsCurrent;
  }
  Future<void> receipt(WidgetTester t)async{
    await t.ensureVisible(find.text('Primit la plecare'));await t.tap(find.text('Primit la plecare'));await t.pumpAndSettle();
    await fixture.enter(t,'Valoare','200');await fixture.enter(t,'De la cine','Synthetic');
    await t.tap(find.widgetWithText(FilledButton,'Adaugă'));await t.pumpAndSettle();
  }
  Future<void> close(WidgetTester t)async{
    await t.ensureVisible(find.text('Închide decontul'));await t.tap(find.text('Închide decontul'));await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton,'Închide'));await t.pumpAndSettle();
  }
}
void main(){
  testWidgets('real receipt dialog confirms only after authoritative model replacement',(t)async{
    final h=_Harness();await h.fixture.mount(t);await h.receipt(t);
    expect(h.db.calls,1);expect(h.db.writes,2);expect(h.refreshes,1);
    expect(h.fixture.logs,hasLength(1));
    final model=h.fixture.settlementOverride!;
    expect(model.revision,1);expect(model.receivedEntries.single.id,model.lastOperationId);
    expect(model.receivedDeparture,200);expect(h.adapter.pendingCodes,isEmpty);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('successive real receipt dialogs reuse the accepted server baseline without external observation',(t)async{
    final h=_Harness();await h.fixture.mount(t);await h.receipt(t);
    expect(h.fixture.logs,hasLength(1));expect(h.db.calls,1);
    await h.receipt(t);
    expect(h.fixture.logs,hasLength(2));expect(h.db.calls,2);expect(h.db.writes,4);
    expect(h.db.serverReads,2,reason:'Only the existing authoritative refresh after each operation');
    final model=h.fixture.settlementOverride!;
    expect(model.revision,2);expect(model.receivedDeparture,400);expect(model.receivedEntries,hasLength(2));
    expect(model.receivedEntries.first.id,isNot(model.receivedEntries.last.id));
    await t.pumpWidget(const SizedBox());h.adapter.dispose();
  });
  for(final fault in ['null','wrong_type','stale_revision','wrong_value']) {
    testWidgets('accepted model $fault cannot release a confirmed save or seed a new baseline',(t)async{
      final h=_Harness();
      final initial=h.fixture.settlementOverride!;
      h.readModelOverride=(_){
        if(fault=='null')return null;
        if(fault=='wrong_type')return Object();
        if(fault=='stale_revision')return initial;
        final model=h.fixture.settlementOverride!;model.receivedDeparture=999;return model;
      };
      await h.fixture.mount(t);await h.receipt(t);
      expect(h.fixture.logs,isEmpty);expect(h.db.calls,1);expect(h.db.writes,2);
      expect(h.adapter.pendingCodes.values.single,'finance_authoritative_refresh_required');
      expect(()=>h.adapter.forgetBaselineExplicitly('settlements/settlement'),throwsA(isA<FinanceSaveRejected>()));
      h.readModelOverride=null;await h.adapter.reconcileExplicitly('settlements/settlement');await t.pumpAndSettle();
      expect(h.fixture.logs,hasLength(1));expect(h.db.calls,1);expect(h.fixture.settlementOverride!.receivedDeparture,200);
      await h.receipt(t);expect(h.fixture.logs,hasLength(2));expect(h.db.calls,2);
      await t.pumpWidget(const SizedBox());h.adapter.dispose();
    });
  }
  testWidgets('a later writer conflicts with the reused baseline instead of silently rebasing',(t)async{
    final h=_Harness();await h.fixture.mount(t);await h.receipt(t);
    h.db.seed('settlements/settlement',{
      ...h.db.documents['settlements/settlement']!,'revision':2,'name':'Newer writer'});
    await h.receipt(t);
    expect(h.adapter.pendingCodes.values.single,'finance_revision_conflict');
    expect(h.db.calls,2);expect(h.db.writes,2);expect(h.fixture.logs,hasLength(1));
    expect(h.db.documents['settlements/settlement']!['name'],'Newer writer');
    expect(h.db.documents['settlements/settlement']!['receivedDeparture'],200);
    await t.pumpWidget(const SizedBox());h.adapter.dispose();
  });
  test('accepted baseline capacity is bounded and an explicit forget never deletes an intent',()async{
    final h=_Harness(),original=h.fixture.settlementOverride!;
    for(var n=0;n<31;n++){
      final model=TravelSettlement(id:'seen$n',teamId:'team',name:original.name,startDate:h.created,
        createdAt:h.created,managerId:'worker');
      h.adapter.observeSettlement(model,FinanceServerObservation(h.db.documents['settlements/settlement'],fromCache:false,pendingWrites:false));
    }
    final newModel=TravelSettlement(id:'new',teamId:'team',name:'New',startDate:h.created,createdAt:h.created,managerId:'worker');
    expect(()=>h.adapter.createSettlement(newModel),throwsA(isA<FinanceSaveRejected>()));
    expect(h.db.calls,0);expect(h.db.writes,0);
    expect(h.adapter.forgetBaselineExplicitly('settlements/seen0'),true);
    expect(h.adapter.forgetBaselineExplicitly('settlements/seen0'),false);
    expect(await h.scope.coordinator.journal.pending(),isEmpty);h.adapter.dispose();
  });
  for(final afterWrite in [false,true]) {
    testWidgets('confirmed SDK result with local cleanup failure stays recoverable afterWrite=$afterWrite',(t)async{
      final h=_Harness();h.storage.cleanupFailure=afterWrite?2:1;
      h.fixture.wrapPage=(page)=>FinanceExpenseDemoRecovery(adapter:h.adapter,child:page);
      await h.fixture.mount(t);await h.receipt(t);
      expect(h.db.calls,1);expect(h.db.writes,2);
      await t.tap(find.text('Primit la plecare'));await t.pumpAndSettle();
      expect(find.text('Adaugă sumă primită la plecare'),findsNothing,
        reason:'An unresolved local cleanup must not release this target for a fresh operation ID');
      expect(h.fixture.logs,isEmpty);
      expect(h.adapter.pendingCodes.values.single,'finance_confirmed_local_cleanup_required');
      expect(find.text('Salvarea este confirmată. Jurnalul local necesită verificare.'),findsOneWidget);
      expect(h.db.serverReads,0);expect(h.refreshes,0);
      expect(await h.scope.coordinator.journal.pending(),hasLength(afterWrite?0:1));
      await t.tap(find.text('Primit la plecare'));await t.pumpAndSettle();
      expect(find.text('Adaugă sumă primită la plecare'),findsNothing);expect(h.db.calls,1);
      if(!afterWrite){
        await t.tap(find.text('Verifică salvarea'));await t.pumpAndSettle();
        expect(h.adapter.pendingCodes.values.single,'finance_confirmed_local_cleanup_required');
        expect(h.db.serverReads,0);expect(h.fixture.logs,isEmpty);expect(h.db.calls,1);
      }
      h.storage.cleanupFailure=0;
      await t.tap(find.text('Verifică salvarea'));await t.pumpAndSettle();
      expect(h.adapter.pendingCodes,isEmpty);expect(h.fixture.logs,hasLength(1));
      expect(h.refreshes,1);expect(h.db.calls,1);expect(h.db.writes,2);
      expect(h.db.serverReads,1,reason:'Known confirmation needs only target refresh, no new marker query or transaction');
      expect(await h.scope.coordinator.journal.pending(),isEmpty);
      expect(h.fixture.settlementOverride!.receivedDeparture,200);
      expect(h.fixture.settlementOverride!.receivedEntries,hasLength(1));
      await t.pumpWidget(const SizedBox());h.adapter.dispose();
    });
  }
  testWidgets('real close dialog lost ack stays locked until explicit marker reconciliation',(t)async{
    final h=_Harness();h.db.commitThenThrow=true;await h.fixture.mount(t);await h.close(t);
    expect(h.db.documents['settlements/settlement']!['closed'],true);
    expect(h.fixture.settlementOverride!.closed,true);expect(h.fixture.logs,isEmpty);
    expect(h.adapter.pendingCodes.values.single,'finance_result_uncertain');
    await t.pump(const Duration(minutes:1));expect(h.db.calls,1);
    await h.adapter.reconcileExplicitly('settlements/settlement');await t.pumpAndSettle();
    expect(h.db.calls,1);expect(h.refreshes,1);expect(h.fixture.logs,hasLength(1));
    expect(h.fixture.settlementOverride!.closed,true);expect(h.adapter.pendingCodes,isEmpty);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('real receipt dialog lost ack blocks manual reentry without a second intent',(t)async{
    final h=_Harness();h.db.commitThenThrow=true;await h.fixture.mount(t);await h.receipt(t);
    await t.tap(find.text('Primit la plecare'));await t.pumpAndSettle();
    expect(find.text('Adaugă sumă primită la plecare'),findsNothing);
    expect(h.db.calls,1);expect((await h.scope.coordinator.journal.pending()),hasLength(1));
    await h.adapter.reconcileExplicitly('settlements/settlement');await t.pumpAndSettle();
    expect(h.fixture.logs,hasLength(1));expect(h.db.calls,1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('confirmed marker and failed refresh can recover without a journal or resubmission',(t)async{
    final h=_Harness();h.failRefresh=true;await h.fixture.mount(t);await h.receipt(t);
    expect(h.fixture.logs,isEmpty);expect(await h.scope.coordinator.journal.pending(),isEmpty);
    h.failRefresh=false;await h.adapter.reconcileExplicitly('settlements/settlement');await t.pumpAndSettle();
    expect(h.fixture.logs,hasLength(1));expect(h.db.calls,1);expect(h.refreshes,1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('fresh certain refusal rolls back only the existing receipt attempt',(t)async{
    final h=_Harness();h.db.documents['settlements/settlement']!['closed']=true;
    await h.fixture.mount(t);await h.receipt(t);
    expect(h.db.writes,0);expect(h.fixture.logs,isEmpty);
    expect(h.fixture.settlementOverride!.receivedEntries,isEmpty);
    expect(h.fixture.settlementOverride!.receivedDeparture,0);
    expect(h.adapter.pendingCodes,isEmpty);await t.pumpWidget(const SizedBox());
  });
  testWidgets('late confirmed completion cannot refresh or log into a revoked UI session',(t)async{
    final h=_Harness();h.db.commitThenThrow=true;await h.fixture.mount(t);await h.close(t);
    h.current=false;
    await expectLater(h.adapter.reconcileExplicitly('settlements/settlement'),throwsA(isA<FinanceSaveRejected>()));
    expect(h.refreshes,0);expect(h.fixture.logs,isEmpty);expect(h.db.calls,1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('real edit dialog commits only its changed fields and refreshes its revision',(t)async{
    final h=_Harness();await h.fixture.mount(t);
    await t.ensureVisible(find.text('Editează deplasarea'));await t.tap(find.text('Editează deplasarea'));await t.pumpAndSettle();
    await h.fixture.enter(t,'Denumire','Revised');
    await t.tap(find.widgetWithText(FilledButton,'Salvează'));await t.pumpAndSettle();
    expect(h.db.calls,1);expect(h.db.writes,2);expect(h.refreshes,1);
    expect(h.fixture.settlementOverride!.name,'Revised');expect(h.fixture.settlementOverride!.revision,1);
    expect(h.fixture.logs,hasLength(1));await t.pumpWidget(const SizedBox());
  });
  testWidgets('stale baseline conflict stays pending without overwriting the newer server revision',(t)async{
    final h=_Harness();h.db.seed('settlements/settlement',{
      ...h.db.documents['settlements/settlement']!,'revision':1,'name':'New server name'});
    await h.fixture.mount(t);await h.close(t);
    expect(h.db.writes,0);expect(h.db.documents['settlements/settlement']!['name'],'New server name');
    expect(h.fixture.logs,isEmpty);expect(h.adapter.pendingCodes.values.single,'finance_revision_conflict');
    expect(await h.scope.coordinator.journal.pending(),hasLength(1));
    await t.pump(const Duration(minutes:1));expect(h.db.calls,1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('real create dialog keeps its new target and reconciles a committed lost acknowledgement',(t)async{
    final h=_Harness();h.db.commitThenThrow=true;await h.fixture.mount(t);
    await t.tap(find.text('Nouă'));await t.pumpAndSettle();
    await h.fixture.enter(t,'Denumire','New synthetic trip');
    await t.tap(find.widgetWithText(FilledButton,'Creează'));await t.pumpAndSettle();
    expect(h.db.calls,1);expect(h.db.writes,2);expect(h.fixture.logs,isEmpty);
    final pending=(await h.scope.coordinator.journal.pending()).single;
    final path=pending.targetPath;
    expect(path,isNot('settlements/settlement'));
    expect(h.db.documents[path]!['name'],'New synthetic trip');
    await h.adapter.reconcileExplicitly(path);await t.pumpAndSettle();
    expect(h.db.calls,1);expect(h.refreshes,1);expect(h.fixture.logs,hasLength(1));
    expect(h.fixture.settlementOverride!.id,pending.documentId);
    expect(h.fixture.settlementOverride!.revision,1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('recovery banner in the original page explicitly reconciles without rebuild network traffic',(t)async{
    final h=_Harness();h.db.commitThenThrow=true;
    h.fixture.wrapPage=(page)=>FinanceExpenseDemoRecovery(adapter:h.adapter,child:page);
    await h.fixture.mount(t);expect(h.db.calls,0);expect(h.db.serverReads,0);
    await h.receipt(t);expect(h.fixture.logs,isEmpty);
    expect(find.text('Rezultatul salvării nu este încă confirmat.'),findsOneWidget);
    h.fixture.rebuild((){});await t.pumpAndSettle();expect(h.db.calls,1);expect(h.db.serverReads,0);
    await t.tap(find.text('Verifică salvarea'));await t.pumpAndSettle();
    expect(h.db.calls,1);expect(h.db.serverReads,2);expect(h.fixture.logs,hasLength(1));
    expect(find.text('Verifică salvarea'),findsNothing);
    await t.pumpWidget(const SizedBox());h.adapter.dispose();
  });
  testWidgets('real legacy receipt dialog preserves opening balance and distinct equal intentions',(t)async{
    final h=_Harness();h.fixture.legacyFinance=true;
    h.fixture.financeOverride=TeamFinance(teamId:'team',managerId:'worker',receivedDeparture:1,receivedOpeningDeparture:1);
    h.db.seed('finance/team',{'teamId':'team','managerId':'worker','perDiemRate':50,
      'receivedDeparture':1,'receivedDuring':0,'receivedOpeningDeparture':1,'receivedOpeningDuring':0,
      'receivedEntries':<Object?>[]});
    final adapter=FinanceExpenseDemoAdapter(scope:h.scope,port:h.db,readAcceptedModel:(_)=>h.fixture.financeOverride,acceptServerSnapshot:(path,data)async{
      h.fixture.financeOverride=TeamFinance(teamId:'team',managerId:'worker',revision:data['revision'] as int,
        lastOperationId:data['lastOperationId'] as String,receivedDeparture:(data['receivedDeparture'] as num).toDouble(),
        receivedOpeningDeparture:1,receivedEntries:(data['receivedEntries'] as List).map((raw){final e=raw as Map;
          return ReceivedMoneyEntry(id:e['id'] as String,kind:e['kind'] as String,amount:(e['amount'] as num).toDouble(),
            method:e['method'] as String,fromName:e['fromName'] as String,date:e['date'] as DateTime);}).toList());
      h.fixture.rebuild((){});
    });
    h.fixture.saveFinanceOverride=adapter.saveFinance;
    void observe()=>adapter.observeFinance(h.fixture.financeOverride!,
      FinanceServerObservation(h.db.documents['finance/team'],fromCache:false,pendingWrites:false));
    observe();await h.fixture.mount(t);await h.receipt(t);
    expect(h.fixture.financeOverride!.receivedDeparture,201);expect(h.fixture.logs,hasLength(1));
    await h.receipt(t);
    final entries=h.fixture.financeOverride!.receivedEntries;
    expect(entries,hasLength(2));expect(entries.first.id,isNot(entries.last.id));
    expect(h.fixture.financeOverride!.receivedDeparture,401);expect(h.fixture.financeOverride!.receivedOpeningDeparture,1);
    expect(h.db.calls,2);expect(h.db.writes,4);expect(h.db.serverReads,2);expect(h.fixture.logs,hasLength(2));
    await t.pumpWidget(const SizedBox());adapter.dispose();
  });
  testWidgets('recreated view loads exact lost-ack intent and reconciles without another submit',(t)async{
    final h=_Harness();h.db.commitThenThrow=true;await h.fixture.mount(t);await h.receipt(t);
    final old=(await h.scope.coordinator.journal.pending()).single;
    final accept=h.adapter.acceptServerSnapshot;
    await t.pumpWidget(const SizedBox());h.adapter.dispose();
    h.scope=FinanceDemoScope(ownerUid:'worker',sessionIsCurrent:()=>true,port:h.db,storage:h.storage);
    h.adapter=FinanceExpenseDemoAdapter(scope:h.scope,port:h.db,acceptServerSnapshot:accept);
    h.fixture.diagnosticSessionIsCurrent=h.scope.sessionIsCurrent;
    h.fixture.saveSettlementOverride=h.adapter.saveSettlement;
    h.fixture.wrapPage=(page)=>FinanceExpenseDemoRecovery(adapter:h.adapter,child:page);
    await h.fixture.mount(t);
    expect(h.adapter.pendingCodes,isEmpty);expect(h.db.calls,1);expect(h.db.serverReads,0);
    await t.tap(find.text('Verifică operațiile în așteptare'));await t.pumpAndSettle();
    expect(h.adapter.pendingCodes,hasLength(1));expect(h.db.calls,1);expect(h.db.serverReads,0);
    expect((await h.scope.coordinator.journal.pending()).single.encode(),old.encode());
    await t.tap(find.text('Verifică salvarea'));await t.pumpAndSettle();
    expect(h.db.calls,1);expect(h.db.writes,2);expect(h.db.serverReads,2);
    expect(h.fixture.settlementOverride!.lastOperationId,old.operationId);
    expect(h.fixture.logs,isEmpty,reason:'A recreated view does not invent the old dialog success audit');
    expect(await h.scope.coordinator.journal.pending(),isEmpty);
    await t.pumpWidget(const SizedBox());h.adapter.dispose();
  });
  for(final committed in [false,true]) {
    testWidgets('new dialog before local review cannot strand an older intent committed=$committed',(t)async{
      final h=_Harness();
      final old=FinanceIntent(operationId:'7'*32,actorUid:'worker',teamId:'team',
        collection:'settlements',documentId:'settlement',baseRevision:0,
        kind:FinanceIntentKind.receipt,changes:{'kind':'departure','amount':150,
          'method':'Cash','fromName':'Earlier','date':h.created});
      if(committed) {
        h.db.commitThenThrow=true;
        expect((await h.scope.coordinator.executeExplicitly(old)).result.status,FinanceIntentStatus.uncertain);
      } else {await h.scope.coordinator.journal.prepare(old);}
      final calls=h.db.calls,writes=h.db.writes;
      h.fixture.wrapPage=(page)=>FinanceExpenseDemoRecovery(adapter:h.adapter,child:page);
      await h.fixture.mount(t);await h.receipt(t);
      expect(h.db.calls,calls);expect(h.db.writes,writes);expect(h.db.serverReads,0);
      expect(h.fixture.logs,isEmpty);
      expect(h.adapter.pendingCodes,isEmpty,reason:'The refused new ID must not occupy the old target');
      expect((await h.scope.coordinator.journal.pending()).single.encode(),old.encode());
      // Explicit review must remain usable in the same adapter and owner scope.
      await h.adapter.loadPendingForReviewExplicitly();await t.pumpAndSettle();
      expect(h.adapter.recoveryCode,isNull);expect(h.adapter.pendingCodes,hasLength(1));
      await h.adapter.reconcileExplicitly(old.targetPath);await t.pumpAndSettle();
      expect(h.db.calls,calls);expect(h.db.writes,writes);expect(h.fixture.logs,isEmpty);
      if(committed) {
        expect(h.fixture.settlementOverride!.receivedDeparture,150);
        expect(h.fixture.settlementOverride!.lastOperationId,old.operationId);
        expect(await h.scope.coordinator.journal.pending(),isEmpty);
        expect(h.adapter.pendingCodes,isEmpty);expect(h.db.serverReads,2);
      } else {
        expect((await h.scope.coordinator.journal.pending()).single.encode(),old.encode());
        expect(h.adapter.pendingCodes,hasLength(1));expect(h.db.serverReads,1);
      }
      await t.pumpWidget(const SizedBox());h.adapter.dispose();
    });
  }
  test('loading an uncommitted persisted request never executes it',()async{
    final h=_Harness();
    final intent=FinanceIntent(operationId:'8'*32,actorUid:'worker',teamId:'team',
      collection:'settlements',documentId:'settlement',baseRevision:0,kind:FinanceIntentKind.close,
      changes:{'closed':true,'endDate':DateTime.utc(2026,10,15)});
    await h.scope.coordinator.journal.prepare(intent);
    await h.adapter.loadPendingForReviewExplicitly();
    await h.adapter.loadPendingForReviewExplicitly();
    expect(h.adapter.pendingCodes,hasLength(1));expect(h.db.calls,0);expect(h.db.serverReads,0);
    await h.adapter.reconcileExplicitly(intent.targetPath);
    expect(h.db.calls,0);expect(h.db.writes,0);expect(h.db.serverReads,1);
    expect((await h.scope.coordinator.journal.pending()).single.digest,intent.digest);
    h.adapter.dispose();
  });
  test('corrupt local recovery is reported without a partial attachment or server access',()async{
    final h=_Harness();h.storage.values['finance_intents_v1_worker']='{broken';
    await h.adapter.loadPendingForReviewExplicitly();
    expect(h.adapter.recoveryCode,'finance_local_recovery_unavailable');
    expect(h.adapter.pendingCodes,isEmpty);expect(h.db.calls,0);expect(h.db.serverReads,0);
    expect(h.storage.values['finance_intents_v1_worker'],'{broken');h.adapter.dispose();
  });
  test('a successor account cannot attach or submit another owners journal',()async{
    final h=_Harness();
    final intent=FinanceIntent(operationId:'9'*32,actorUid:'worker',teamId:'team',
      collection:'settlements',documentId:'settlement',baseRevision:0,kind:FinanceIntentKind.edit,changes:{'name':'Pending'});
    await h.scope.coordinator.journal.prepare(intent);
    final successor=FinanceExpenseDemoAdapter(scope:FinanceDemoScope(ownerUid:'other',
      sessionIsCurrent:()=>true,port:h.db,storage:h.storage),port:h.db,acceptServerSnapshot:(_,__)async{});
    await successor.loadPendingForReviewExplicitly();
    expect(successor.pendingCodes,isEmpty);expect(h.db.calls,0);expect(h.db.serverReads,0);
    expect((await h.scope.coordinator.journal.pending()).single.digest,intent.digest);
    successor.dispose();h.adapter.dispose();
  });
  testWidgets('all 32 recovered operations remain reachable on a small screen without automatic network reads',(t)async{
    final h=_Harness();
    for(var n=0;n<32;n++) {
      await h.scope.coordinator.journal.prepare(FinanceIntent(
        operationId:n.toRadixString(16).padLeft(32,'0'),actorUid:'worker',teamId:'team',
        collection:'settlements',documentId:'trip$n',baseRevision:0,
        kind:FinanceIntentKind.edit,changes:{'name':'Pending'}));
    }
    await t.binding.setSurfaceSize(const Size(320,480));
    addTearDown(()=>t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(home:Scaffold(body:FinanceExpenseDemoRecovery(
      adapter:h.adapter,child:const SizedBox()))));
    await t.tap(find.text('Verifică operațiile în așteptare'));await t.pumpAndSettle();
    expect(h.adapter.pendingCodes,hasLength(32));expect(t.takeException(),isNull);
    final last=find.byKey(const ValueKey(('finance-pending','settlements/trip31')));
    final lastControl=find.descendant(of:last,matching:find.widgetWithText(TextButton,'Verifică salvarea'));
    await t.scrollUntilVisible(lastControl,250,maxScrolls:100,scrollable:find.descendant(
      of:find.byKey(const ValueKey('finance-pending-list')),matching:find.byType(Scrollable)));
    await t.pumpAndSettle();
    expect(lastControl.hitTestable(),findsOneWidget);expect(t.takeException(),isNull);
    expect(h.db.calls,0);expect(h.db.serverReads,0);
    await t.tap(lastControl);await t.pumpAndSettle();
    expect(h.db.serverReads,1);expect(h.db.calls,0);expect(h.adapter.pendingCodes,hasLength(32));
    await t.pumpWidget(const SizedBox());h.adapter.dispose();
  });
  test('cached observation never becomes an adapter baseline',(){
    final h=_Harness();
    expect(()=>h.adapter.observeSettlement(h.fixture.settlementOverride!,
      FinanceServerObservation(h.db.documents['settlements/settlement'],fromCache:true,pendingWrites:false)),
      throwsA(isA<FinanceSaveRejected>()));
    expect(h.db.calls,0);
  });
}
