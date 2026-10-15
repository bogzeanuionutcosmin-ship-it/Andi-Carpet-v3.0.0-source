import 'package:andi_carpeta/finance/intents/finance_ledger.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:andi_carpeta/finance/intents/finance_ledger_demo_panel.dart';
import 'dart:async';

class _Port implements FinanceLedgerPort {
  int revision=5,reads=0,queries=0;
  bool cache=false,pending=false;
  final rows=<FinanceLedgerRow>[];
  Future<void> Function()? afterRead;
  _Port(){for(var n=5;n>=1;n--)rows.add(row(n));}
  static FinanceLedgerRow row(int n)=>FinanceLedgerRow(n.toRadixString(16).padLeft(32,'0'),{
    'operationId':n.toRadixString(16).padLeft(32,'0'),'teamId':'team','actorUid':'manager',
    'targetPath':'settlements/trip','revision':n,'baseRevision':n-1,'kind':'receipt','digest':'a'*64});
  @override Future<FinanceServerObservation> target(String path)async{
    reads++;await afterRead?.call();return FinanceServerObservation({'teamId':'team','revision':revision,
      if(revision>0)'lastOperationId':revision.toRadixString(16).padLeft(32,'0')},fromCache:cache,pendingWrites:pending);
  }
  @override Future<FinanceLedgerObservation> page(String path,int maximumRevision,int limit)async{
    queries++;await afterRead?.call();return FinanceLedgerObservation(rows.where((r)=>(r.data['revision'] as int)<=maximumRevision).take(limit).toList(),fromCache:cache,pendingWrites:pending);
  }
}
void main(){
  test('explicit bounded pages keep a fixed upper revision while new markers are appended',()async{
    final p=_Port(),r=FinanceLedgerReader(port:_Port(),sessionIsCurrent:()=>true);
    final reader=FinanceLedgerReader(port:p,sessionIsCurrent:()=>true,pageSize:2);
    expect(p.reads,0);expect(p.queries,0);
    final first=await reader.firstExplicitly('settlements/trip');
    p.revision=6;p.rows.insert(0,_Port.row(6));
    final second=await reader.nextExplicitly(first.next!),third=await reader.nextExplicitly(second.next!);
    expect([...first.rows,...second.rows,...third.rows].map((r)=>r.data['revision']),[5,4,3,2,1]);
    expect(third.completeThroughUpperRevision,true);expect(third.upperRevision,5);expect(p.reads,1);
    await expectLater(r.nextExplicitly(first.next!),throwsA(isA<FinanceRefusal>()));
  });
  test('missing or duplicate revisions are refused rather than silently reported as complete',()async{
    for(final duplicate in [false,true]){
      final p=_Port();if(duplicate){p.rows[1]=_Port.row(5);}else{p.rows.removeAt(1);}
      await expectLater(FinanceLedgerReader(port:p,sessionIsCurrent:()=>true).firstExplicitly('settlements/trip'),throwsA(isA<FinanceRefusal>()));
    }
  });
  test('cache and pending observations cannot certify ledger pages',()async{
    for(final cached in [false,true]){
      final p=_Port();p.cache=cached;p.pending=!cached;
      await expectLater(FinanceLedgerReader(port:p,sessionIsCurrent:()=>true).firstExplicitly('settlements/trip'),throwsA(isA<FinanceRefusal>()));
      expect(p.queries,0);
    }
  });
  test('cross-bound or malformed evidence cannot be displayed as verified',()async{
    for(final patch in <Map<String,Object?>>[{'teamId':'other'},{'targetPath':'finance/team'},
      {'actorUid':''},{'digest':'bad'},{'kind':'unknown'},{'operationId':'f'*32},{'baseRevision':0}]){
      final p=_Port();p.rows[0]=FinanceLedgerRow(p.rows[0].id,{...p.rows[0].data,...patch});
      await expectLater(FinanceLedgerReader(port:p,sessionIsCurrent:()=>true).firstExplicitly('settlements/trip'),throwsA(isA<FinanceRefusal>()));
    }
  });
  test('session revocation after a target read prevents a page query',()async{
    var current=true;final p=_Port()..afterRead=()async{current=false;};
    await expectLater(FinanceLedgerReader(port:p,sessionIsCurrent:()=>current).firstExplicitly('settlements/trip'),throwsA(isA<FinanceRefusal>()));
    expect(p.queries,0);
  });
  test('legacy zero revision makes no claim about undated aggregate money',()async{
    final p=_Port()..revision=0;
    final result=await FinanceLedgerReader(port:p,sessionIsCurrent:()=>true).firstExplicitly('settlements/trip');
    expect(result.upperRevision,0);expect(result.rows,isEmpty);expect(p.queries,0);
  });
  test('page limits and target paths fail before network access',()async{
    final p=_Port();for(final n in [0,21])expect(()=>FinanceLedgerReader(port:p,sessionIsCurrent:()=>true,pageSize:n),throwsArgumentError);
    await expectLater(FinanceLedgerReader(port:p,sessionIsCurrent:()=>true).firstExplicitly('users/private'),throwsA(isA<FinanceRefusal>()));
    expect(p.reads,0);expect(p.queries,0);
  });
  testWidgets('ledger UI reads only explicit pages and rebuilds never advance the cursor',(t)async{
    final p=_Port(),reader=FinanceLedgerReader(port:_Port(),sessionIsCurrent:()=>true);
    final actual=FinanceLedgerReader(port:p,sessionIsCurrent:()=>true,pageSize:2);
    Widget view(FinanceLedgerReader r)=>MaterialApp(home:Scaffold(body:FinanceLedgerDemoPanel(reader:r,targetPath:'settlements/trip')));
    await t.pumpWidget(view(actual));expect(p.reads,0);expect(p.queries,0);
    await t.tap(find.text('Deschide registrul operațiilor'));await t.pumpAndSettle();
    expect(find.text('Revizie analizată: 5'),findsOneWidget);expect(p.reads,1);expect(p.queries,1);
    await t.pumpWidget(view(actual));await t.pumpAndSettle();expect(p.queries,1);
    await t.tap(find.text('Pagina următoare'));await t.pumpAndSettle();expect(p.queries,2);
    expect(find.text('Încasare · revizia 3'),findsOneWidget);expect(find.text('Încasare · revizia 5'),findsNothing);
    await t.pumpWidget(view(reader));expect(find.text('Revizie analizată: 5'),findsNothing);
    expect(p.queries,2);await t.pumpWidget(const SizedBox());
  });
  testWidgets('ledger same-frame double tap issues one target read and one page query',(t)async{
    final p=_Port(),release=Completer<void>();p.afterRead=()=>release.future;
    await t.pumpWidget(MaterialApp(home:Scaffold(body:FinanceLedgerDemoPanel(
      reader:FinanceLedgerReader(port:p,sessionIsCurrent:()=>true),targetPath:'settlements/trip'))));
    final callback=t.widget<TextButton>(find.widgetWithText(TextButton,'Deschide registrul operațiilor')).onPressed!;
    callback();callback();await t.pump();expect(p.reads,1);expect(p.queries,0);
    release.complete();await t.pumpAndSettle();expect(p.queries,1);await t.pumpWidget(const SizedBox());
  });
  testWidgets('disposed ledger view ignores a late read and never queries the page for a revoked owner',(t)async{
    final p=_Port(),release=Completer<void>();var current=true;p.afterRead=()=>release.future;
    await t.pumpWidget(MaterialApp(home:Scaffold(body:FinanceLedgerDemoPanel(
      reader:FinanceLedgerReader(port:p,sessionIsCurrent:()=>current),targetPath:'settlements/trip'))));
    await t.tap(find.text('Deschide registrul operațiilor'));await t.pump();
    current=false;await t.pumpWidget(const SizedBox());release.complete();await t.pumpAndSettle();
    expect(p.queries,0);expect(t.takeException(),isNull);
  });
  test('returned pages and row payloads are immutable and diagnostic strings are anonymous',()async{
    final page=await FinanceLedgerReader(port:_Port(),sessionIsCurrent:()=>true).firstExplicitly('settlements/trip');
    expect(()=>page.rows.clear(),throwsUnsupportedError);expect(()=>page.rows.first.data.clear(),throwsUnsupportedError);
    expect(page.rows.first.toString(),'FinanceLedgerRow');
  });
}
