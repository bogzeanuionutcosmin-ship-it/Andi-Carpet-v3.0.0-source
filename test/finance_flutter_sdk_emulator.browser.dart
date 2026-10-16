// Explicit CI invocation only; not part of offline unit-test discovery.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'support/expense_document_fixture.dart';
import 'package:andi_carpeta/finance/intents/finance_expense_demo_recovery.dart';
import 'package:andi_carpeta/finance/intents/finance_ledger.dart';
import 'package:andi_carpeta/finance/intents/firestore_ledger_port.dart';
import 'package:andi_carpeta/main.dart' show TravelSettlement, ReceivedMoneyEntry, AndiCarpetaApp, AuthGateSources, AppSettings;
import 'package:andi_carpeta/finance/intents/finance_demo_panel.dart';
import 'package:andi_carpeta/finance/intents/finance_expense_demo_adapter.dart';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/firestore_finance_port.dart';
import 'package:andi_carpeta/finance/intents/finance_restore.dart';
import 'package:andi_carpeta/finance/intents/firestore_restore_port.dart';
import 'package:andi_carpeta/finance/intents/finance_coordinator.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';

// Bounded synthetic setup diagnostics; never emit token/UID/financial payload.
Future<T> sdkStage<T>(String code,Future<T> Function() action) async {
 print('VIII_SDK_STAGE $code');
 return action().timeout(const Duration(seconds:30),onTimeout:()=>throw TimeoutException('VIII_SDK_STAGE_TIMEOUT $code'));
}

class ObservedPort implements FinanceAtomicPort {
 final FinanceAtomicPort inner;int atomicCalls=0,serverReads=0;
 FinanceServerObservation? lastObservation;
 int lostAcknowledgements=0;
 bool loseAcknowledgement=false;
 Future<void> Function()? afterServerRead,afterLostAck;
 ObservedPort(this.inner);
 @override Future<T> atomic<T>(Future<T> Function(FinanceTransaction) action)async{
  atomicCalls++;final result=await inner.atomic(action);
  if(loseAcknowledgement){lostAcknowledgements++;await afterLostAck?.call();throw TimeoutException('synthetic_ack_loss_after_real_commit');}return result;
 }
 @override Future<FinanceServerObservation> readServer(String path)async{
  serverReads++;lastObservation=null;final result=await inner.readServer(path);lastObservation=result;await afterServerRead?.call();return result;
 }
}
// In-memory journal fixture isolates transport acceptance from physical secure
// storage durability. Reconstructing it does not model an OS process restart.
class BrowserJournalStorage implements FinanceJournalStorage {
 final values=<String,String>{};
 bool failCleanup=false;
 @override Future<String?> read(String key)async=>values[key];
 @override Future<void> write(String key,String value)async{
  if(failCleanup&&((jsonDecode(value) as Map)['intents'] as List).isEmpty)throw StateError('synthetic_local_cleanup_failure');
  values[key]=value;
 }
}
// Original dialogs + genuine SDK, with only journal storage held in memory.
// This closes the UI/SDK test boundary; it is not a production Home factory.
class SdkExpenseUi {
 final ObservedPort port;
 final ExpenseDocumentFixture fixture;
 late final FinanceDemoScope scope;
 late final FinanceExpenseDemoAdapter adapter;
 SdkExpenseUi(String uid,this.port,bool Function() current,{FinanceJournalStorage? storage})
   :fixture=ExpenseDocumentFixture('',userId:uid,teamId:'flutter-team'){
  scope=FinanceDemoScope(ownerUid:uid,sessionIsCurrent:current,port:port,storage:storage??BrowserJournalStorage());
  adapter=FinanceExpenseDemoAdapter(scope:scope,port:port,acceptServerSnapshot:(path,data)async{
   fixture.settlementOverride=TravelSettlement(id:path.split('/').last,teamId:data['teamId'] as String,
    name:data['name'] as String,startDate:data['startDate'] as DateTime,createdAt:data['createdAt'] as DateTime,
    endDate:data['endDate'] as DateTime?,managerId:data['managerId'] as String?,
    perDiemRate:(data['perDiemRate'] as num).toDouble(),closed:data['closed'] as bool,
    revision:data['revision'] as int,lastOperationId:data['lastOperationId'] as String,
    receivedDeparture:(data['receivedDeparture'] as num).toDouble(),receivedDuring:(data['receivedDuring'] as num).toDouble(),
    receivedOpeningDeparture:(data['receivedOpeningDeparture'] as num).toDouble(),
    receivedOpeningDuring:(data['receivedOpeningDuring'] as num).toDouble(),
    receivedEntries:(data['receivedEntries'] as List).map((raw){final e=raw as Map;
     return ReceivedMoneyEntry(id:e['id'] as String,kind:e['kind'] as String,amount:(e['amount'] as num).toDouble(),
      method:e['method'] as String,fromName:e['fromName'] as String,date:e['date'] as DateTime);
    }).toList());
   fixture.rebuild((){});
  });
  fixture.saveSettlementOverride=(model)=>model.revision==null&&fixture.settlementOverride?.id!=model.id?
    adapter.createSettlement(model):adapter.saveSettlement(model);
  fixture.diagnosticSessionIsCurrent=scope.sessionIsCurrent;
  fixture.wrapPage=(page)=>FinanceExpenseDemoRecovery(adapter:adapter,child:page);
 }
 // Bounded TEST-only event-loop wait for real browser I/O. No app polling or
 // financial retry: timeout fails the acceptance, never fabricates success.
 Future<void> wait(WidgetTester t,bool Function() ready)async{
  await t.runAsync(()async{
   final deadline=DateTime.now().add(const Duration(seconds:30));
   while(!ready()){
    if(DateTime.now().isAfter(deadline))throw TimeoutException('finance_ui_sdk_boundary_timeout');
    await Future<void>.delayed(const Duration(milliseconds:20));
    await t.pump(); // Drain widget microtasks while genuine SDK I/O advances.
   }
  });
  await t.pumpAndSettle();
 }
 Future<void> baseline(WidgetTester t)async{
  final model=fixture.settlementOverride!;
  final observation=await t.runAsync(()=>port.readServer('settlements/${model.id}'));
  adapter.observeSettlement(model,observation!);
 }
 Future<void> create(WidgetTester t)async{
  await t.tap(find.text('Nouă'));await t.pumpAndSettle();
  await fixture.enter(t,'Denumire','Synthetic real SDK UI');
  await t.tap(find.widgetWithText(FilledButton,'Creează'));await t.pump();
  await wait(t,()=>fixture.logs.length==1);
 }
 Future<void> receipt(WidgetTester t)async{
  await t.ensureVisible(find.text('Primit la plecare'));await t.tap(find.text('Primit la plecare'));await t.pumpAndSettle();
  await fixture.enter(t,'Valoare','200');await fixture.enter(t,'De la cine','Synthetic UI');
  await t.tap(find.widgetWithText(FilledButton,'Adaugă'));await t.pump();
 }
 Future<void> close(WidgetTester t)async{
  await t.pumpWidget(const SizedBox());adapter.dispose();
 }
}
// Ownership is tied to the actual AuthGate widget lifetime, not UID equality.
class SdkExpenseOwnedView extends StatefulWidget {
 final SdkExpenseUi Function() create;
 const SdkExpenseOwnedView({super.key,required this.create});
 @override State<SdkExpenseOwnedView> createState()=>_SdkExpenseOwnedViewState();
}
class _SdkExpenseOwnedViewState extends State<SdkExpenseOwnedView> {
 late final SdkExpenseUi ui;
 @override void initState(){super.initState();ui=widget.create();}
 @override Widget build(BuildContext context)=>ui.fixture.buildPage();
 @override void dispose(){ui.adapter.dispose();super.dispose();}
}
FinanceIntent receipt(String target,int id,String uid,{int revision=0})=>FinanceIntent(operationId:id.toRadixString(16).padLeft(32,'0'),actorUid:uid,teamId:'flutter-team',collection:'settlements',documentId:target,baseRevision:revision,kind:FinanceIntentKind.receipt,changes:{'kind':'departure','amount':200.0,'method':'Cash','fromName':'Synthetic payer','date':DateTime.utc(2026,10,15)});
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 // Browser unit-test entrypoints do not run the application's generated
 // plugin registrant. Register genuine web SDK delegates, never test doubles.
 FirebaseCoreWeb.registerWith(webPluginRegistrar);
 FirebaseAuthWeb.registerWith(webPluginRegistrar);
 FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
 webPluginRegistrar.registerMessageHandler();
 final createdApps=<FirebaseApp>[];final createdAuths=<FirebaseAuth>[];
 const options=FirebaseOptions(apiKey:'synthetic-emulator-key',appId:'1:123:web:synthetic',messagingSenderId:'123',projectId:'demo-andi-carpet');
 late FirebaseApp app,secondApp,offlineApp;late FirebaseAuth auth,secondAuth,offlineAuth;late FirebaseFirestore db,secondDb,offlineDb;
 late ObservedPort port,secondPort,offlinePort;late String uid;
 Future<void> signIn(FirebaseAuth a,String suffix)=>a.signInWithEmailAndPassword(email:'viii-$suffix@example.test',password:'SyntheticEmulatorOnly123!');
 setUpAll(()async{
  app=await sdkStage('initialize_primary',()=>Firebase.initializeApp(name:'viii-primary',options:options));createdApps.add(app);
  secondApp=await sdkStage('initialize_second',()=>Firebase.initializeApp(name:'viii-second-device',options:options));createdApps.add(secondApp);
  offlineApp=await sdkStage('initialize_offline_client',()=>Firebase.initializeApp(name:'viii-offline-client',options:options));createdApps.add(offlineApp);
  auth=FirebaseAuth.instanceFor(app:app);secondAuth=FirebaseAuth.instanceFor(app:secondApp);offlineAuth=FirebaseAuth.instanceFor(app:offlineApp);createdAuths.addAll([auth,secondAuth,offlineAuth]);
  await sdkStage('auth_emulator_primary',()=>auth.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false));
  await sdkStage('auth_emulator_second',()=>secondAuth.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false));
  await sdkStage('auth_emulator_offline',()=>offlineAuth.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false));
  await sdkStage('persistence_primary',()=>auth.setPersistence(Persistence.NONE));await sdkStage('persistence_second',()=>secondAuth.setPersistence(Persistence.NONE));
  await sdkStage('persistence_offline',()=>offlineAuth.setPersistence(Persistence.NONE));
  db=FirebaseFirestore.instanceFor(app:app);secondDb=FirebaseFirestore.instanceFor(app:secondApp);offlineDb=FirebaseFirestore.instanceFor(app:offlineApp);
  db.settings=const Settings(persistenceEnabled:false);secondDb.settings=const Settings(persistenceEnabled:false);offlineDb.settings=const Settings(persistenceEnabled:false);
  port=ObservedPort(FirestoreFinanceAtomicPort.emulator(firestore:db));
  secondPort=ObservedPort(FirestoreFinanceAtomicPort.emulator(firestore:secondDb));
  offlinePort=ObservedPort(FirestoreFinanceAtomicPort.emulator(firestore:offlineDb,port:8081));
  await sdkStage('sign_in_primary',()=>signIn(auth,'a'));await sdkStage('sign_in_second',()=>signIn(secondAuth,'a'));uid=auth.currentUser!.uid;
  await sdkStage('sign_in_offline',()=>signIn(offlineAuth,'a'));
 });
 tearDownAll(()async{for(final a in createdAuths){await sdkStage('cleanup_auth',()=>a.signOut());}for(final a in createdApps.reversed){await sdkStage('cleanup_app',()=>a.delete());}});
 Future<Map<String,dynamic>> server(String target)async{
  final snapshot=await db.doc('settlements/$target').get(const GetOptions(source:Source.server));
  expect(snapshot.metadata.isFromCache,false);expect(snapshot.metadata.hasPendingWrites,false);return snapshot.data()!;
 }
 testWidgets('original ExpensePage create receipt edit close use genuine SDK atomic writes',(t)async{
  final ui=SdkExpenseUi(uid,ObservedPort(port.inner),()=>auth.currentUser?.uid==uid);
  // The UI owns its own counter wrapper, sharing only the validated emulator.
  await ui.fixture.mount(t);expect(ui.port.atomicCalls,0);expect(ui.port.serverReads,0);
  try {
   await ui.create(t);expect(ui.port.atomicCalls,1);expect(ui.fixture.settlementOverride!.revision,1);
   await ui.baseline(t);await ui.receipt(t);await ui.wait(t,()=>ui.fixture.logs.length==2);
   expect(ui.fixture.settlementOverride!.receivedDeparture,200);expect(ui.fixture.settlementOverride!.revision,2);
   await ui.baseline(t);
   await t.ensureVisible(find.text('Editează deplasarea'));await t.tap(find.text('Editează deplasarea'));await t.pumpAndSettle();
   await ui.fixture.enter(t,'Denumire','SDK UI revised');await t.tap(find.widgetWithText(FilledButton,'Salvează'));await t.pump();
   await ui.wait(t,()=>ui.fixture.logs.length==3);expect(ui.fixture.settlementOverride!.revision,3);
   await ui.baseline(t);
   await t.ensureVisible(find.text('Închide decontul'));await t.tap(find.text('Închide decontul'));await t.pumpAndSettle();
   await t.tap(find.widgetWithText(FilledButton,'Închide'));await t.pump();
   await ui.wait(t,()=>ui.fixture.logs.length==4);
   final data=await t.runAsync(()=>server(ui.fixture.settlementOverride!.id));
   expect(data!['closed'],true);expect(data['name'],'SDK UI revised');expect(data['revision'],4);
   expect(data['receivedDeparture'],200);expect(data['receivedEntries'],hasLength(1));
   expect(ui.port.atomicCalls,4);expect(ui.adapter.pendingCodes,isEmpty);
   expect(await t.runAsync(()=>ui.scope.coordinator.journal.pending()),isEmpty);
  } finally {await ui.close(t);}
 },timeout:const Timeout(Duration(minutes:2)));
 testWidgets('original receipt recovery button reconciles genuine committed lost ack without another write',(t)async{
  final ui=SdkExpenseUi(uid,ObservedPort(port.inner),()=>auth.currentUser?.uid==uid);
  await ui.fixture.mount(t);
  try {
   await ui.create(t);await ui.baseline(t);ui.port.loseAcknowledgement=true;
   await ui.receipt(t);await ui.wait(t,()=>ui.adapter.pendingCodes.values.contains('finance_result_uncertain'));
   expect(ui.fixture.logs,hasLength(1));expect(ui.port.lostAcknowledgements,1);expect(ui.port.atomicCalls,2);
   final before=await t.runAsync(()=>ui.scope.coordinator.journal.pending());
   expect(before,hasLength(1));final digest=before!.single.digest;
   await t.ensureVisible(find.text('Primit la plecare'));await t.tap(find.text('Primit la plecare'));await t.pumpAndSettle();
   expect(find.text('Adaugă sumă primită la plecare'),findsNothing);expect(ui.port.atomicCalls,2);
   final checks=ui.port.serverReads;
   await t.ensureVisible(find.text('Verifică salvarea'));await t.tap(find.text('Verifică salvarea'));await t.pump();
   await ui.wait(t,()=>ui.fixture.logs.length==2);
   expect(ui.port.atomicCalls,2);expect(ui.port.serverReads,checks+2);expect(ui.adapter.pendingCodes,isEmpty);
   final data=await t.runAsync(()=>server(ui.fixture.settlementOverride!.id));
   expect(data!['revision'],2);expect(data['receivedDeparture'],200);expect(data['receivedEntries'],hasLength(1));
   final marker=await t.runAsync(()=>ui.port.readServer('settlements/${ui.fixture.settlementOverride!.id}/financialIntents/${before.single.operationId}'));
   expect(marker!.data!['digest'],digest);
   expect(await t.runAsync(()=>ui.scope.coordinator.journal.pending()),isEmpty);
  } finally {await ui.close(t);}
 },timeout:const Timeout(Duration(minutes:2)));
 testWidgets('genuine SDK confirmation survives journal cleanup failure and explicit UI recovery',(t)async{
  final storage=BrowserJournalStorage();
  final ui=SdkExpenseUi(uid,ObservedPort(port.inner),()=>auth.currentUser?.uid==uid,storage:storage);
  await ui.fixture.mount(t);
  try {
   await ui.create(t);await ui.baseline(t);storage.failCleanup=true;
   final reads=ui.port.serverReads;
   await ui.receipt(t);await ui.wait(t,()=>ui.adapter.pendingCodes.values.contains('finance_confirmed_local_cleanup_required'));
   expect(ui.fixture.logs,hasLength(1));expect(ui.port.atomicCalls,2);expect(ui.port.serverReads,reads);
   expect(find.text('Salvarea este confirmată. Jurnalul local necesită verificare.'),findsOneWidget);
   final pending=(await t.runAsync(()=>ui.scope.coordinator.journal.pending()))!.single;
   final data=await t.runAsync(()=>server(pending.documentId));
   expect(data!['revision'],2);expect(data['receivedDeparture'],200);expect(data['receivedEntries'],hasLength(1));
   storage.failCleanup=false;
   await t.ensureVisible(find.text('Verifică salvarea'));await t.tap(find.text('Verifică salvarea'));await t.pump();
   await ui.wait(t,()=>ui.fixture.logs.length==2);
   expect(ui.port.atomicCalls,2);expect(ui.port.serverReads,reads+1);
   expect(ui.adapter.pendingCodes,isEmpty);expect(await t.runAsync(()=>ui.scope.coordinator.journal.pending()),isEmpty);
   expect(ui.fixture.settlementOverride!.lastOperationId,pending.operationId);
  } finally {await ui.close(t);}
 },timeout:const Timeout(Duration(minutes:2)));
 testWidgets('real AuthGate SDK A B A2 isolates original dialogs and recovers the same pending intent',(t)async{
  final storage=BrowserJournalStorage(),created=<SdkExpenseUi>[];
  final sources=AuthGateSources(currentUser:()=>auth.currentUser,authStateChanges:auth.authStateChanges,
   uiSettingsSnapshots:()=>const Stream<DocumentSnapshot<Map<String,dynamic>>>.empty(),
   profileSnapshots:(owner)=>db.doc('users/$owner').snapshots());
  await t.pumpWidget(AndiCarpetaApp(settings:AppSettings()..brandingBackgroundId='none',authSources:sources,
   homeBuilder:(key,profile,current)=>SdkExpenseOwnedView(key:key,create:(){
    final ui=SdkExpenseUi(profile.uid,ObservedPort(port.inner),current,storage:storage);created.add(ui);return ui;
   })));
  // Wait for the real Firestore profile stream without inventing a profile.
  await t.runAsync(()async{
   final deadline=DateTime.now().add(const Duration(seconds:30));
   while(created.isEmpty){
    if(DateTime.now().isAfter(deadline))throw TimeoutException('finance_authgate_profile_timeout');
    await Future<void>.delayed(const Duration(milliseconds:20));await t.pump();
   }
  });
  await t.pumpAndSettle();final old=created.last;
  final release=Completer<void>(),ackReleased=Completer<void>();
  try {
   expect(old.scope.ownerUid,uid);await old.create(t);await old.baseline(t);
   expect(find.textContaining('Synthetic real SDK UI'),findsWidgets);
   old.port.loseAcknowledgement=true;
   old.port.afterLostAck=()async{await release.future;ackReleased.complete();};
   await old.receipt(t);await old.wait(t,()=>old.port.lostAcknowledgements==1);
   final original=(await t.runAsync(()=>old.scope.coordinator.journal.pending()))!.single;
   final oldReads=old.port.serverReads;
   await t.runAsync(()=>signIn(auth,'b'));
   await old.wait(t,()=>created.last.scope.ownerUid!=uid&&created.last.scope.sessionIsCurrent());
   final b=created.last;
   expect(old.scope.sessionIsCurrent(),false);expect(find.textContaining('Synthetic real SDK UI'),findsNothing);
   await t.tap(find.text('Verifică operațiile în așteptare'));await t.pumpAndSettle();
   await b.wait(t,()=>!b.adapter.recoveryBusy);
   expect(b.adapter.pendingCodes,isEmpty);expect(b.port.atomicCalls,0);expect(b.port.serverReads,0);
   await t.runAsync(()=>signIn(auth,'a'));
   await old.wait(t,()=>!identical(created.last,old)&&created.last.scope.ownerUid==uid&&created.last.scope.sessionIsCurrent());
   final a2=created.last;expect(b.scope.sessionIsCurrent(),false);expect(old.scope.sessionIsCurrent(),false);
   release.complete();await old.wait(t,()=>ackReleased.isCompleted);await t.pumpAndSettle();
   expect(old.fixture.logs,hasLength(1));expect(old.port.serverReads,oldReads);
   expect(a2.port.atomicCalls,0);expect(a2.fixture.logs,isEmpty);
   await t.tap(find.text('Verifică operațiile în așteptare'));await t.pumpAndSettle();
   await a2.wait(t,()=>!a2.adapter.recoveryBusy);
   expect(a2.adapter.pendingCodes,hasLength(1));expect(a2.port.serverReads,0);
   final recovered=(await t.runAsync(()=>a2.scope.coordinator.journal.pending()))!.single;
   expect(recovered.encode(),original.encode());
   await t.ensureVisible(find.text('Verifică salvarea'));await t.tap(find.text('Verifică salvarea'));await t.pump();
   await a2.wait(t,()=>a2.adapter.pendingCodes.isEmpty);
   expect(a2.port.atomicCalls,0);expect(a2.port.serverReads,2);expect(a2.fixture.logs,isEmpty);
   expect(a2.fixture.settlementOverride!.lastOperationId,original.operationId);
   expect(a2.fixture.settlementOverride!.receivedDeparture,200);
   final data=await t.runAsync(()=>server(original.documentId));
   expect(data!['revision'],2);expect(data['receivedEntries'],hasLength(1));
  } finally {
   if(!release.isCompleted)release.complete();
   await t.pumpWidget(const SizedBox());await t.pumpAndSettle();
   await t.runAsync(()=>signIn(auth,'a'));
  }
 },timeout:const Timeout(Duration(minutes:2)));
 test('actual Flutter SDK receipt replay, editing and closure preserve history',()async{
  final repo=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid);
  final i=receipt('flutter-main',1,uid);expect((await repo.execute(i)).status,FinanceIntentStatus.confirmed);
  expect((await repo.execute(FinanceIntent.decode(i.encode()))).replayed,true);
  var data=await server('flutter-main');expect(data['receivedDeparture'],225);expect(data['receivedOpeningDeparture'],25);expect(data['receivedEntries'],hasLength(1));
  for(final kind in [FinanceIntentKind.edit,FinanceIntentKind.close]){
   final revision=kind==FinanceIntentKind.edit?1:2;
   final op=FinanceIntent(operationId:(revision+1).toRadixString(16).padLeft(32,'0'),actorUid:uid,teamId:'flutter-team',collection:'settlements',documentId:'flutter-main',baseRevision:revision,kind:kind,changes:kind==FinanceIntentKind.edit?{'name':'Revised SDK trip'}:{'closed':true,'endDate':DateTime.utc(2026,10,15)});
   expect((await repo.execute(op)).status,FinanceIntentStatus.confirmed);
  }
  expect((await repo.execute(receipt('flutter-main',4,uid,revision:3))).status,FinanceIntentStatus.rejectedBeforeWrite);
  data=await server('flutter-main');expect(data['revision'],3);expect(data['receivedDeparture'],225);expect(data['closed'],true);
 });
 test('actual Flutter SDK lost acknowledgement reconciles by explicit server read without writes',()async{
  final repo=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>true);final i=receipt('flutter-lost',10,uid);
  final lostBefore=port.lostAcknowledgements;
  port.loseAcknowledgement=true;expect((await repo.execute(i)).status,FinanceIntentStatus.uncertain);port.loseAcknowledgement=false;
  expect(port.lostAcknowledgements,lostBefore+1,reason:'fixture must actually commit before losing acknowledgement');
  final calls=port.atomicCalls;expect((await repo.reconcile(FinanceIntent.decode(i.encode()))).status,FinanceIntentStatus.confirmed,
   reason:'server evidence flags: cache=${port.lastObservation?.fromCache}, pending=${port.lastObservation?.pendingWrites}, present=${port.lastObservation?.data!=null}');expect(port.atomicCalls,calls);
  final data=await server('flutter-lost');expect(data['revision'],1);expect(data['receivedEntries'],hasLength(1));
 });
 test('actual independent Flutter SDK clients cannot lose a concurrent receipt',()async{
  final a=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>true),b=FinanceRepository(port:secondPort,ownerUid:uid,sessionIsCurrent:()=>true);
  final results=await Future.wait([a.execute(receipt('flutter-race',20,uid)),b.execute(receipt('flutter-race',21,uid))]);
  expect(results.where((r)=>r.status==FinanceIntentStatus.confirmed),hasLength(1));
  expect(results.where((r)=>r.status==FinanceIntentStatus.conflict||r.status==FinanceIntentStatus.uncertain),hasLength(1));
  final data=await server('flutter-race');expect(data['revision'],1);expect(data['receivedEntries'],hasLength(1));expect(data['receivedDeparture'],225);
 });
 test('actual Auth emulator A to B to A2 cannot complete old ownership epoch',()async{
  var epoch=1;final repo=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>epoch==1 && auth.currentUser?.uid==uid);
  final i=receipt('flutter-owner',30,uid);expect((await repo.execute(i)).status,FinanceIntentStatus.confirmed);
  final entered=Completer<void>(),release=Completer<void>();port.afterServerRead=()async{entered.complete();await release.future;};
  final checking=repo.reconcile(i);await entered.future;
  await auth.signOut();epoch=2;await signIn(auth,'b');expect(auth.currentUser!.uid,isNot(uid));
  final b=FinanceRepository(port:port,ownerUid:auth.currentUser!.uid,sessionIsCurrent:()=>true);
  expect((await b.execute(receipt('flutter-owner',31,auth.currentUser!.uid,revision:1))).status,FinanceIntentStatus.uncertain);
  await auth.signOut();epoch=3;await signIn(auth,'a');expect(auth.currentUser!.uid,uid);release.complete();
  expect((await checking).status,FinanceIntentStatus.uncertain);port.afterServerRead=null;
  final a2=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>epoch==3 && auth.currentUser?.uid==uid);
  expect((await a2.reconcile(i)).status,FinanceIntentStatus.confirmed);expect((await server('flutter-owner'))['revision'],1);
 });
 test('actual Flutter SDK view-own transaction can create a stable empty target',()async{
  final repo=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>true);
  final i=FinanceIntent(operationId:'c'*32,actorUid:uid,teamId:'flutter-team',collection:'settlements',documentId:'flutter-created',baseRevision:0,kind:FinanceIntentKind.create,changes:{'name':'Created SDK trip','startDate':DateTime.utc(2026,10,1),'createdAt':DateTime.utc(2026,10,15),'managerId':uid,'perDiemRate':50.0});
  expect((await repo.execute(i)).status,FinanceIntentStatus.confirmed);expect((await repo.execute(i)).replayed,true);
  final data=await server('flutter-created');expect(data['revision'],1);expect(data['receivedEntries'],isEmpty);
 });
 test('actual Flutter SDK preserves historical timestamp nanoseconds through receipt and edit',()async{
  final repo=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>true);
  final original=await server('flutter-nanos');
  expect((await repo.execute(receipt('flutter-nanos',40,uid))).status,FinanceIntentStatus.confirmed);
  final edit=FinanceIntent(operationId:'e'*32,actorUid:uid,teamId:'flutter-team',collection:'settlements',documentId:'flutter-nanos',baseRevision:1,kind:FinanceIntentKind.edit,changes:{'name':'Exact edited'});
  expect((await repo.execute(edit)).status,FinanceIntentStatus.confirmed);
  final data=await server('flutter-nanos');
  expect(data['startDate'],original['startDate']);
  expect(data['createdAt'],original['createdAt']);
  expect(((data['receivedEntries'] as List).first as Map)['date'],((original['receivedEntries'] as List).first as Map)['date']);
  // Independent JS verifier reads raw server Timestamp seconds/nanos after the
  // Flutter suite. Flutter web's decoded view alone cannot certify precision.
  expect(data['receivedDeparture'],225);expect(data['receivedEntries'],hasLength(2));
 });
 test('actual Flutter SDK targeted Admin restore preserves evidence and globally refuses stale finance',()async{
  final repo=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>true);
  final initial=receipt('flutter-restore',50,uid);
  expect((await repo.execute(initial)).status,FinanceIntentStatus.confirmed);
  await secondAuth.signOut();await signIn(secondAuth,'admin');
  try {
   const room='locations/flutter-restore-room';
   Future<Map<String,Object?>?> snapshot(String path)async {
    final value=await secondDb.doc(path).get(const GetOptions(source:Source.server));
    expect(value.metadata.isFromCache,false);expect(value.metadata.hasPendingWrites,false);
    return decodeFinanceFirestoreDocument(value.data());
   }
   final expected=<String,Object?>{
    initial.targetPath:await snapshot(initial.targetPath),
    initial.markerPath:await snapshot(initial.markerPath),room:await snapshot(room),
   };
   final plan=FinanceRestorePlan.decode(FinanceRestorePlan(expected:expected,
    replacements:{room:{'name':'Restored demo room'}}).encode());
   final restore=FinanceDemoRestore(port:FirestoreDemoRestorePort.fromFinanceEmulator(secondPort.inner as FirestoreFinanceAtomicPort),
    sessionIsCurrent:()=>secondAuth.currentUser!=null);
   expect((await restore.executeExplicitly(plan)).status,FinanceIntentStatus.confirmed);
   expect(await snapshot(room),{'name':'Restored demo room'});
   expect(sameFinanceValue(await snapshot(initial.targetPath),expected[initial.targetPath]),true);
   expect(sameFinanceValue(await snapshot(initial.markerPath),expected[initial.markerPath]),true);
   final stale=FinanceRestorePlan(expected:{...expected,room:await snapshot(room)},
    replacements:{room:{'name':'Must not be written'}});
   expect((await repo.execute(receipt('flutter-restore',51,uid,revision:1))).status,FinanceIntentStatus.confirmed);
   expect((await restore.executeExplicitly(stale)).status,FinanceIntentStatus.conflict);
   expect(await snapshot(room),{'name':'Restored demo room'});
   expect((await server('flutter-restore'))['revision'],2);
   expect((await server('flutter-restore'))['receivedEntries'],hasLength(2));
  } finally {await secondAuth.signOut();await signIn(secondAuth,'a');}
 });
 test('actual Flutter SDK adapter recovers committed create after scope recreation without resubmission',()async{
  final storage=BrowserJournalStorage(),committed=Completer<void>();
  final calls=port.atomicCalls,lost=port.lostAcknowledgements;
  Map<String,Object?>? refreshed;
  FinanceExpenseDemoAdapter make()=>FinanceExpenseDemoAdapter(
   scope:FinanceDemoScope(ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid,port:port,storage:storage),
   port:port,acceptServerSnapshot:(_,data)async{refreshed=data;});
  final first=make();
  port.loseAcknowledgement=true;port.afterLostAck=()async{committed.complete();};
  try {
   unawaited(first.createSettlement(TravelSettlement(id:'flutter-adapter-recovery',teamId:'flutter-team',
    name:'Scope recovery fixture',managerId:uid,startDate:DateTime.utc(2026,10,1),createdAt:DateTime.utc(2026,10,15))));
   await committed.future.timeout(const Duration(seconds:30));
   final original=(await first.scope.coordinator.journal.pending()).single;
   first.dispose();port.afterLostAck=null;port.loseAcknowledgement=false;
   final second=make();
   try {
    expect(second.pendingCodes,isEmpty);
    await second.loadPendingForReviewExplicitly();
    expect((await second.scope.coordinator.journal.pending()).single.encode(),original.encode());
    expect(port.atomicCalls,calls+1);expect(refreshed,isNull);
    await second.reconcileExplicitly(original.targetPath);
    expect(second.pendingCodes,isEmpty);expect(port.atomicCalls,calls+1);
    expect(port.lostAcknowledgements,lost+1);
    expect(refreshed!['lastOperationId'],original.operationId);expect(refreshed!['revision'],1);
    expect(refreshed!['receivedEntries'],isEmpty);
    expect(await second.scope.coordinator.journal.pending(),isEmpty);
   }finally{second.dispose();}
  }finally{port.afterLostAck=null;port.loseAcknowledgement=false;}
 });
 test('actual Flutter SDK Admin bounded ledger pages exclude revisions appended after the captured watermark',()async{
  final repo=FinanceRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid);
  FinanceIntent request(int n)=>FinanceIntent(operationId:n.toRadixString(16).padLeft(32,'0'),actorUid:uid,
   teamId:'flutter-team',collection:'settlements',documentId:'flutter-ledger',baseRevision:n-1,
   kind:n==1?FinanceIntentKind.create:FinanceIntentKind.edit,changes:n==1?
    {'name':'Ledger','startDate':DateTime.utc(2026,10,1),'createdAt':DateTime.utc(2026,10,15),'managerId':uid,'perDiemRate':50}:
    {'name':'Ledger revised $n'});
  for(var n=1;n<=3;n++)expect((await repo.execute(request(n))).status,FinanceIntentStatus.confirmed);
  final managerReader=FinanceLedgerReader(port:FirestoreDemoLedgerPort.fromFinanceEmulator(port.inner as FirestoreFinanceAtomicPort),
   sessionIsCurrent:()=>auth.currentUser?.uid==uid,pageSize:2);
  await expectLater(managerReader.firstExplicitly('settlements/flutter-ledger'),
   throwsA(isA<FirebaseException>().having((e)=>e.code,'code','permission-denied')));
  await secondAuth.signOut();await signIn(secondAuth,'admin');
  final adminUid=secondAuth.currentUser!.uid;
  try {
  final reader=FinanceLedgerReader(port:FirestoreDemoLedgerPort.fromFinanceEmulator(secondPort.inner as FirestoreFinanceAtomicPort),
   sessionIsCurrent:()=>secondAuth.currentUser?.uid==adminUid,pageSize:2);
  final first=await reader.firstExplicitly('settlements/flutter-ledger');
  expect(first.rows.map((r)=>r.data['revision']),[3,2]);expect(first.upperRevision,3);
  expect((await repo.execute(request(4))).status,FinanceIntentStatus.confirmed);
  final last=await reader.nextExplicitly(first.next!);
  expect(last.rows.map((r)=>r.data['revision']),[1]);expect(last.upperRevision,3);expect(last.next,isNull);
  expect((await reader.firstExplicitly('settlements/flutter-ledger')).rows.map((r)=>r.data['revision']),[4,3]);
  }finally{await secondAuth.signOut();await signIn(secondAuth,'a');}
 });
 test('actual Flutter SDK disableNetwork cached read and reconnect never replay financial intent automatically',()async{
  final storage=BrowserJournalStorage();
  FinanceIntentCoordinator coordinator()=>FinanceIntentCoordinator(
   repository:FinanceRepository(port:offlinePort,ownerUid:uid,sessionIsCurrent:()=>offlineAuth.currentUser?.uid==uid),
   journal:FinanceIntentJournal(storage:storage,ownerUid:uid,sessionIsCurrent:()=>offlineAuth.currentUser?.uid==uid));
  final request=receipt('flutter-offline',60,uid),before=await server('flutter-offline');
  await offlineDb.doc(request.targetPath).get(const GetOptions(source:Source.server));
  var current=coordinator();final calls=offlinePort.atomicCalls;
  await offlineDb.disableNetwork();
  await html.HttpRequest.request('http://127.0.0.1:8082/network',method:'POST',sendData:'offline');
  try {
   final cached=await offlineDb.doc(request.targetPath).get(const GetOptions(source:Source.cache));
   expect(cached.metadata.isFromCache,true);
   expect((await current.executeExplicitly(request)).result.status,FinanceIntentStatus.uncertain);
   expect((await current.reconcileExplicitly(request)).result.status,FinanceIntentStatus.uncertain);
   expect(offlinePort.atomicCalls,calls+1);
   expect((await current.journal.pending()).single.digest,request.digest);
  } finally {
   await html.HttpRequest.request('http://127.0.0.1:8082/network',method:'POST',sendData:'online');
   await offlineDb.enableNetwork();
  }
  current=coordinator();
  expect((await current.journal.pending()).single.digest,request.digest);
  final after=await server('flutter-offline');expect(after['receivedDeparture'],before['receivedDeparture']);
  expect(after['receivedEntries'],before['receivedEntries']);expect(offlinePort.atomicCalls,calls+1);
  expect((await current.executeExplicitly(request)).result.status,FinanceIntentStatus.confirmed);
  expect((await current.executeExplicitly(request)).result.replayed,true);
  expect((await server('flutter-offline'))['receivedEntries'],hasLength(1));
  expect(await current.journal.pending(),isEmpty);
 },timeout:const Timeout(Duration(minutes:2)));
}
