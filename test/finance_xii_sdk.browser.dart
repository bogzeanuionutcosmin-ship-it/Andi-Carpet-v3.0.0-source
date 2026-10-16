// All XI/IX/VIII controls retained; this adds actual Dart→JS→IndexedDB→SDK.
import 'dart:html' as html;
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:andi_carpeta/finance/history/history_xi.dart';
import 'package:andi_carpeta/finance/history/history_xi_firestore.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/journal_v2/browser_journal.dart';
import 'package:andi_carpeta/finance/journal_v2/history_v2_journal.dart';
import 'finance_xi_sdk.browser.dart' as xi;
import 'finance_flutter_sdk_emulator.browser.dart' show ObservedPort;

void main(){
 xi.main();
 late FirebaseApp app;late FirebaseAuth auth;late String uid;
 late ObservedPort port;
 HistoryV2Journal journal()=>createBrowserHistoryV2Journal(ownerUid:uid,teamId:'flutter-team',sessionIsCurrent:()=>auth.currentUser?.uid==uid);
 FinanceHistoryXiRepository repository()=>FinanceHistoryXiRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid);
 HistoryXiIntent intent(int n,String target)=>HistoryXiIntent(FinanceIntent(operationId:n.toRadixString(16).padLeft(32,'0'),actorUid:uid,
   teamId:'flutter-team',collection:'settlements',documentId:target,baseRevision:0,kind:FinanceIntentKind.receipt,
   changes:{'kind':'departure','amount':200,'method':'Cash','fromName':'Synthetic XII','date':FinanceTimestamp(1790812800,123456789)}));
 setUpAll(()async{
  final script=html.ScriptElement()..type='module'..src='http://127.0.0.1:8082/journal-v2.mjs';
  final loaded=script.onLoad.first;html.document.head!.append(script);await loaded.timeout(const Duration(seconds:15));
  app=await Firebase.initializeApp(name:'xii-journal',options:const FirebaseOptions(apiKey:'synthetic-emulator-key',appId:'1:123:web:xii',messagingSenderId:'123',projectId:'demo-andi-carpet'));
  auth=FirebaseAuth.instanceFor(app:app);await auth.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false);
  await auth.setPersistence(Persistence.NONE);
  await auth.signInWithEmailAndPassword(email:'viii-a@example.test',password:'SyntheticEmulatorOnly123!');uid=auth.currentUser!.uid;
  final db=FirebaseFirestore.instanceFor(app:app);db.settings=const Settings(persistenceEnabled:false);
  port=ObservedPort(HistoryXiFirestorePort.emulator(firestore:db));
 });
 tearDownAll(()async{await auth.signOut();await app.delete();});
 test('XII real durable journal lost ACK restart exact reconcile makes no second financial transaction',()async{
  final j=journal(),i=intent(8101,'xi-sdk-empty');
  port.loseAcknowledgement=true;
  final c=HistoryV2Coordinator(repository:repository(),journal:j);
  final first=await c.executeExplicitly(i);
  expect(first.result.status,FinanceIntentStatus.uncertain);expect(first.journalPending,true);
  expect((await j.pending()).single.encode(),i.encode());expect(port.atomicCalls,1);
  j.dispose();final restored=journal(),again=HistoryV2Coordinator(repository:repository(),journal:restored);
  expect((await again.executeExplicitly(i)).result.status,FinanceIntentStatus.uncertain);expect(port.atomicCalls,1);
  expect((await again.reconcileExplicitly((await restored.pending()).single)).result.status,FinanceIntentStatus.confirmed);
  expect(await restored.pending(),isEmpty);expect(port.atomicCalls,1);expect(port.serverReads,2);
  restored.dispose();
 },timeout:const Timeout(Duration(minutes:2)));
 test('XII prepare without send survives scope disposal and missing server evidence retains exact bytes',()async{
  final j=journal(),i=intent(8102,'xii-never-sent');await j.prepare(i);j.dispose();
  final restored=journal(),c=HistoryV2Coordinator(repository:repository(),journal:restored);
  final before=port.atomicCalls;
  expect((await c.reconcileExplicitly(i)).result.status,FinanceIntentStatus.uncertain);
  expect((await restored.pending()).single.encode(),i.encode());expect(port.atomicCalls,before);
  await auth.signOut();await expectLater(restored.pending(),throwsA(anything));
  await auth.signInWithEmailAndPassword(email:'viii-a@example.test',password:'SyntheticEmulatorOnly123!');
  await expectLater(restored.pending(),throwsA(anything));
  final current=journal();expect((await current.pending()).single.digest,i.digest);current.dispose();
 },timeout:const Timeout(Duration(minutes:2)));
}
