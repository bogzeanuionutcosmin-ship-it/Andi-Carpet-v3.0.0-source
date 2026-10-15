// Explicit CI invocation only; not part of offline unit-test discovery.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/firestore_finance_port.dart';

class ObservedPort implements FinanceAtomicPort {
 final FinanceAtomicPort inner;int atomicCalls=0,serverReads=0;
 bool loseAcknowledgement=false;
 Future<void> Function()? afterServerRead;
 ObservedPort(this.inner);
 @override Future<T> atomic<T>(Future<T> Function(FinanceTransaction) action)async{
  atomicCalls++;final result=await inner.atomic(action);
  if(loseAcknowledgement)throw TimeoutException('synthetic_ack_loss_after_real_commit');return result;
 }
 @override Future<FinanceServerObservation> readServer(String path)async{
  serverReads++;final result=await inner.readServer(path);await afterServerRead?.call();return result;
 }
}
FinanceIntent receipt(String target,int id,String uid,{int revision=0})=>FinanceIntent(operationId:id.toRadixString(16).padLeft(32,'0'),actorUid:uid,teamId:'flutter-team',collection:'settlements',documentId:target,baseRevision:revision,kind:FinanceIntentKind.receipt,changes:{'kind':'departure','amount':200.0,'method':'Cash','fromName':'Synthetic payer','date':DateTime.utc(2026,10,15)});
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 const options=FirebaseOptions(apiKey:'synthetic-emulator-key',appId:'1:123:web:synthetic',messagingSenderId:'123',projectId:'demo-andi-carpet');
 late FirebaseApp app,secondApp;late FirebaseAuth auth,secondAuth;late FirebaseFirestore db,secondDb;
 late ObservedPort port,secondPort;late String uid;
 Future<void> signIn(FirebaseAuth a,String suffix)=>a.signInWithEmailAndPassword(email:'viii-$suffix@example.test',password:'SyntheticEmulatorOnly123!');
 setUpAll(()async{
  app=await Firebase.initializeApp(name:'viii-primary',options:options);
  secondApp=await Firebase.initializeApp(name:'viii-second-device',options:options);
  auth=FirebaseAuth.instanceFor(app:app);secondAuth=FirebaseAuth.instanceFor(app:secondApp);
  await auth.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false);
  await secondAuth.useAuthEmulator('127.0.0.1',9099,automaticHostMapping:false);
  await auth.setPersistence(Persistence.NONE);await secondAuth.setPersistence(Persistence.NONE);
  db=FirebaseFirestore.instanceFor(app:app);secondDb=FirebaseFirestore.instanceFor(app:secondApp);
  db.settings=const Settings(persistenceEnabled:false);secondDb.settings=const Settings(persistenceEnabled:false);
  port=ObservedPort(FirestoreFinanceAtomicPort.emulator(firestore:db));
  secondPort=ObservedPort(FirestoreFinanceAtomicPort.emulator(firestore:secondDb));
  await signIn(auth,'a');await signIn(secondAuth,'a');uid=auth.currentUser!.uid;
 });
 tearDownAll(()async{await auth.signOut();await secondAuth.signOut();await app.delete();await secondApp.delete();});
 Future<Map<String,dynamic>> server(String target)async{
  final snapshot=await db.doc('settlements/$target').get(const GetOptions(source:Source.server));
  expect(snapshot.metadata.isFromCache,false);expect(snapshot.metadata.hasPendingWrites,false);return snapshot.data()!;
 }
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
  port.loseAcknowledgement=true;expect((await repo.execute(i)).status,FinanceIntentStatus.uncertain);port.loseAcknowledgement=false;
  final calls=port.atomicCalls;expect((await repo.reconcile(FinanceIntent.decode(i.encode()))).status,FinanceIntentStatus.confirmed);expect(port.atomicCalls,calls);
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
}
