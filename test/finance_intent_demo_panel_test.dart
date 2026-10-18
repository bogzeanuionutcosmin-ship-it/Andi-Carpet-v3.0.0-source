import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/finance/intents/finance_demo_panel.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_gate_fixture.dart';
import 'support/finance_atomic_fixture.dart';

class DemoStorage implements FinanceJournalStorage {
  final values=<String,String>{};bool fail=false;
  @override Future<String?> read(String key) async=>values[key];
  @override Future<void> write(String key,String value)async{
    if(fail)throw StateError('synthetic_storage_failure');values[key]=value;
  }
}
FinanceIntent demoIntent(String uid,{FinanceIntentKind kind=FinanceIntentKind.receipt})=>FinanceIntent(
  operationId:'f'*32,actorUid:uid,teamId:'team',collection:'settlements',documentId:'trip',
  baseRevision:0,kind:kind,changes:switch(kind){
    FinanceIntentKind.receipt=>{'kind':'departure','amount':200,'method':'Cash','fromName':'Synthetic','date':DateTime.utc(2026,10,15)},
    FinanceIntentKind.edit=>{'name':'Edited'},
    FinanceIntentKind.close=>{'closed':true,'endDate':DateTime.utc(2026,10,15)},
    FinanceIntentKind.create=>{'name':'Created','startDate':DateTime.utc(2026,10,15),'createdAt':DateTime.utc(2026,10,15),'managerId':uid,'perDiemRate':50},
  });
void main() {
  FinanceAtomicFixture fixture()=>FinanceAtomicFixture()..seed('settlements/trip',{
    'name':'Original','teamId':'team','closed':false,'receivedDeparture':0,'receivedDuring':0,'receivedEntries':[],
  });
  Future<void> mount(WidgetTester t,FinanceDemoScope scope,FinanceIntent intent)=>t.pumpWidget(
    MaterialApp(home:Scaffold(body:FinanceIntentDemoPanel(scope:scope,intent:intent))));
  for(final kind in FinanceIntentKind.values) {
    testWidgets('demo UI explicitly submits ${kind.name} through durable coordinator', (t)async {
      final db=fixture(),storage=DemoStorage();
      if(kind==FinanceIntentKind.create){db.documents.clear();db.versions.clear();}
      final scope=FinanceDemoScope(ownerUid:'a',sessionIsCurrent:()=>true,port:db,storage:storage);
      await mount(t,scope,demoIntent('a',kind:kind));expect(db.calls,0);
      await t.tap(find.text('Execută intenția'));await t.pumpAndSettle();
      expect(find.text('finance_confirmed'),findsOneWidget);expect(db.calls,1);expect(db.writes,2);
      expect(await scope.coordinator.journal.pending(),isEmpty);
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
    });
  }
  testWidgets('same frame double tap schedules one execution and keeps a stable request', (t)async {
    final db=fixture(),storage=DemoStorage(),release=Completer<void>();
    db.beforeCommit=()=>release.future;
    final scope=FinanceDemoScope(ownerUid:'a',sessionIsCurrent:()=>true,port:db,storage:storage);
    final intent=demoIntent('a');await mount(t,scope,intent);
    final handler=t.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
    handler();handler();await t.pumpAndSettle();expect(db.calls,1);
    expect((await scope.coordinator.journal.pending()).single.digest,intent.digest);
    release.complete();await t.pumpAndSettle();expect(db.writes,2);
  });
  testWidgets('lost ack remains visible and server check reconciles without resubmission', (t)async {
    final db=fixture()..commitThenThrow=true,storage=DemoStorage();
    final scope=FinanceDemoScope(ownerUid:'a',sessionIsCurrent:()=>true,port:db,storage:storage);
    await mount(t,scope,demoIntent('a'));await t.tap(find.text('Execută intenția'));await t.pumpAndSettle();
    expect(find.text('finance_result_uncertain'),findsOneWidget);expect(db.calls,1);
    await t.tap(find.text('Verifică pe server'));await t.pumpAndSettle();
    expect(find.text('finance_confirmed'),findsOneWidget);expect(db.calls,1);expect(db.serverReads,1);expect(db.writes,2);
  });
  testWidgets('storage failure never starts SDK execution', (t)async {
    final db=fixture(),storage=DemoStorage()..fail=true;
    final scope=FinanceDemoScope(ownerUid:'a',sessionIsCurrent:()=>true,port:db,storage:storage);
    await mount(t,scope,demoIntent('a'));await t.tap(find.text('Execută intenția'));await t.pumpAndSettle();
    expect(find.text('finance_storage_unavailable'),findsOneWidget);expect(db.calls,0);
  });
  testWidgets('disposing demo panel revokes its scope even while AuthGate UID stays unchanged', (t)async {
    final db=fixture(),storage=DemoStorage(),release=Completer<void>();
    db.beforeRead=(_)async{await release.future;};
    final scope=FinanceDemoScope(ownerUid:'a',sessionIsCurrent:()=>true,port:db,storage:storage);
    await mount(t,scope,demoIntent('a'));await t.tap(find.text('Execută intenția'));await t.pumpAndSettle();
    expect(db.calls,1);await t.pumpWidget(const SizedBox());expect(scope.sessionIsCurrent(),false);
    release.complete();await t.pumpAndSettle();expect(db.writes,0);expect(t.takeException(),isNull);
    final restarted=FinanceDemoScope(ownerUid:'a',sessionIsCurrent:()=>true,port:db,storage:storage);
    expect((await restarted.coordinator.journal.pending()).single.digest,demoIntent('a').digest);
    expect(db.calls,1);
  });
  testWidgets('actual AuthGate A to B to A2 revokes old coordinator and requires explicit recovery', (t)async {
    final gate=GateFixture(),db=fixture(),storage=DemoStorage(),release=Completer<void>();
    addTearDown(gate.close);db.beforeCommit=()=>release.future;
    final scopes=<FinanceDemoScope>[];
    await t.pumpWidget(AndiCarpetaApp(authSources:gate.sources,
      settings:AppSettings()..brandingBackgroundId='none',
      homeBuilder:(key,profile,current) {
        final scope=FinanceDemoScope(ownerUid:profile.uid,sessionIsCurrent:current,port:db,storage:storage);
        scopes.add(scope);
        return Scaffold(key:key,body:FinanceIntentDemoPanel(scope:scope,intent:demoIntent(profile.uid)));
      }));
    await flushFixtureGate(t);gate.profile('a').add(GateFixtureSnapshot({'active':true}));await flushFixtureGate(t);
    final old=scopes.last;
    await t.tap(find.text('Execută intenția'));await t.pumpAndSettle();expect(db.calls,1);
    for(final uid in ['b','a']) {
      gate.user=GateFixtureUser(uid,'$uid@example.test');gate.auth.add(gate.user);await flushFixtureGate(t);
      gate.profile(uid).add(GateFixtureSnapshot({'active':true}));await flushFixtureGate(t);
    }
    final a2=scopes.last;expect(old.sessionIsCurrent(),false);expect(a2.sessionIsCurrent(),true);
    expect(db.calls,1);expect(find.text('finance_ready'),findsOneWidget);
    release.complete();await t.pumpAndSettle();
    expect(find.text('finance_confirmed'),findsNothing);expect(db.writes,2);
    expect((await a2.coordinator.journal.pending()).single.digest,demoIntent('a').digest);
    await t.tap(find.text('Verifică pe server'));await t.pumpAndSettle();
    expect(find.text('finance_confirmed'),findsOneWidget);expect(db.calls,1);expect(db.serverReads,1);
    expect(await a2.coordinator.journal.pending(),isEmpty);
    await t.pumpWidget(const SizedBox());expect(t.takeException(),isNull);
  });
}
