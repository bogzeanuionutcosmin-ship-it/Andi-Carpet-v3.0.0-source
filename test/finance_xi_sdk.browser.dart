// Genuine Chrome Auth + Firestore; all existing IX controls remain registered.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:andi_carpeta/finance/history/history_xi.dart';
import 'package:andi_carpeta/finance/history/history_xi_firestore.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'finance_ix_sdk.browser.dart' as ix;
import 'finance_flutter_sdk_emulator.browser.dart' show ObservedPort;

void main(){
 ix.main();
 late FirebaseApp app,secondApp;late FirebaseAuth auth,otherAuth;
 late FirebaseFirestore db,secondDb;late String uid;
 late HistoryXiFirestorePort port,secondPort;
 HistoryXiIntent intent(int n,String target,{int base=0})=>HistoryXiIntent(FinanceIntent(
  operationId:n.toRadixString(16).padLeft(32,'0'),actorUid:uid,teamId:'flutter-team',
  collection:'settlements',documentId:target,baseRevision:base,kind:FinanceIntentKind.receipt,
  changes:{'kind':'departure','amount':200,'method':'Cash','fromName':'Synthetic XI',
   'date':FinanceTimestamp(1790812800,123456789)}));
 setUpAll(()async{
  const options=FirebaseOptions(apiKey:'synthetic-emulator-key',appId:'1:123:web:xi',messagingSenderId:'123',projectId:'demo-andi-carpet');
  app=await Firebase.initializeApp(name:'xi-history',options:options);
  secondApp=await Firebase.initializeApp(name:'xi-history-device',options:options);
  auth=FirebaseAuth.instanceFor(app:app);otherAuth=FirebaseAuth.instanceFor(app:secondApp);
  for(final a in [auth,otherAuth]){
   await a.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false);
   await a.setPersistence(Persistence.NONE);
   await a.signInWithEmailAndPassword(email:'viii-a@example.test',password:'SyntheticEmulatorOnly123!');
  }
  uid=auth.currentUser!.uid;
  db=FirebaseFirestore.instanceFor(app:app);secondDb=FirebaseFirestore.instanceFor(app:secondApp);
  db.settings=const Settings(persistenceEnabled:false);secondDb.settings=const Settings(persistenceEnabled:false);
  port=HistoryXiFirestorePort.emulator(firestore:db);secondPort=HistoryXiFirestorePort.emulator(firestore:secondDb);
 });
 tearDownAll(()async{await auth.signOut();await otherAuth.signOut();await app.delete();await secondApp.delete();});
 test('XI Dart SDK append replay distinct receipts loss of ACK and exact row timestamps',()async{
  final observed=ObservedPort(port);
  final r=FinanceHistoryXiRepository(port:observed,ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid);
  final first=intent(7001,'xi-sdk-main');
  expect((await r.executeExplicitly(first)).status,FinanceIntentStatus.confirmed);
  expect((await r.executeExplicitly(first)).replayed,true);
  expect(port.atomicCalls,2);expect(port.writes,2);expect(port.reads,5);
  observed.loseAcknowledgement=true;
  final next=intent(7002,'xi-sdk-main',base:1);
  expect((await r.executeExplicitly(next)).status,FinanceIntentStatus.uncertain);
  expect(observed.lostAcknowledgements,1);expect(port.writes,4);
  final recreated=FinanceHistoryXiRepository(port:observed,ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid);
  final saved=HistoryXiIntent.decode(next.encode());
  expect((await recreated.reconcileExplicitly(saved)).status,FinanceIntentStatus.confirmed);
  expect(port.atomicCalls,3);expect(port.writes,4);expect(port.serverReads,2);
  final summary=await port.readServer(next.summaryPath);
  expect(summary.data!['receivedDeparture'],400);expect(summary.data!['revision'],2);
  expect(summary.data!.containsKey('receivedEntries'),false);
  final row=await port.readServer(next.rowPath);
  final date=row.data!['date'] as Map;expect(date['nanoseconds'],123456789);expect(date['seconds'],1790812800);
  expect(row.data!['digest'],saved.digest);
  final query=await db.collection('${first.summaryPath}/receipts').where('revision',isLessThanOrEqualTo:2)
   .orderBy('revision',descending:true).limit(20).get(const GetOptions(source:Source.server));
  expect(query.docs.map((d)=>d.data()['revision']),[2,1]);expect(query.metadata.isFromCache,false);
 },timeout:const Timeout(Duration(minutes:2)));
 test('XI genuine two SDK instances cannot accept two same-revision receipts',()async{
  final a=FinanceHistoryXiRepository(port:port,ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid);
  final b=FinanceHistoryXiRepository(port:secondPort,ownerUid:uid,sessionIsCurrent:()=>otherAuth.currentUser?.uid==uid);
  final results=await Future.wait([a.executeExplicitly(intent(7011,'xi-sdk-race')),b.executeExplicitly(intent(7012,'xi-sdk-race'))]);
  expect(results.where((r)=>r.status==FinanceIntentStatus.confirmed),hasLength(1));
  // SDK may wrap the callback conflict. It must never become success/retry UI.
  expect(results.where((r)=>r.status!=FinanceIntentStatus.confirmed),hasLength(1));
  final s=await port.readServer(intent(7011,'xi-sdk-race').summaryPath);
  expect(s.data!['revision'],1);expect(s.data!['receivedDeparture'],200);
  final rows=await db.collection('${intent(7011,'xi-sdk-race').summaryPath}/receipts').limit(20).get(const GetOptions(source:Source.server));
  expect(rows.docs,hasLength(1));
 },timeout:const Timeout(Duration(minutes:2)));
 test('XI Auth revocation retires old SDK owner without a second financial call',()async{
  final observed=ObservedPort(port);
  final r=FinanceHistoryXiRepository(port:observed,ownerUid:uid,sessionIsCurrent:()=>auth.currentUser?.uid==uid);
  final i=intent(7021,'xi-sdk-revoke');
  expect((await r.executeExplicitly(i)).status,FinanceIntentStatus.confirmed);
  await auth.signOut();
  expect((await r.executeExplicitly(intent(7022,'xi-sdk-revoke',base:1))).status,FinanceIntentStatus.rejectedBeforeWrite);
  expect(observed.atomicCalls,1);
  await auth.signInWithEmailAndPassword(email:'viii-a@example.test',password:'SyntheticEmulatorOnly123!');
  expect((await r.executeExplicitly(intent(7022,'xi-sdk-revoke',base:1))).status,FinanceIntentStatus.rejectedBeforeWrite);
  expect(observed.atomicCalls,1);
 },timeout:const Timeout(Duration(minutes:2)));
}
