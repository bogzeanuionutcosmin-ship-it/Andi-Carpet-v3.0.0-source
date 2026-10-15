import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/finance/intents/finance_demo_panel.dart';
import 'package:andi_carpeta/finance/intents/finance_expense_demo_adapter.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
import 'support/finance_atomic_fixture.dart';

class _Storage implements FinanceJournalStorage {
  final values=<String,String>{};
  @override Future<String?> read(String key)async=>values[key];
  @override Future<void> write(String key,String value)async{values[key]=value;}
}
class _Harness {
  final db=FinanceAtomicFixture(),storage=_Storage();
  final fixture=ExpenseDocumentFixture('');
  late FinanceDemoScope scope;
  late FinanceExpenseDemoAdapter adapter;
  bool current=true,failRefresh=false;
  int refreshes=0;
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
    adapter=FinanceExpenseDemoAdapter(scope:scope,port:db,acceptServerSnapshot:(path,data)async{
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
  test('cached observation never becomes an adapter baseline',(){
    final h=_Harness();
    expect(()=>h.adapter.observeSettlement(h.fixture.settlementOverride!,
      FinanceServerObservation(h.db.documents['settlements/settlement'],fromCache:true,pendingWrites:false)),
      throwsA(isA<FinanceSaveRejected>()));
    expect(h.db.calls,0);
  });
}
