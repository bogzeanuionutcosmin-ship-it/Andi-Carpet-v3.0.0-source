import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/firestore_finance_port.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';

class SyntheticApp implements FirebaseApp {
  final String project;
  SyntheticApp(this.project);
  @override FirebaseOptions get options => FirebaseOptions(apiKey:'synthetic',appId:'synthetic',messagingSenderId:'synthetic',projectId:project);
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class SyntheticFirestore implements FirebaseFirestore {
  final String project;
  int configured=0, attempts=0;
  Duration? timeout;
  SyntheticFirestore(this.project);
  @override FirebaseApp get app => SyntheticApp(project);
  @override void useFirestoreEmulator(String host,int port,{bool sslEnabled=false,bool automaticHostMapping=true}) {configured++;}
  @override Future<T> runTransaction<T>(TransactionHandler<T> handler,{Duration timeout=const Duration(seconds:30),int maxAttempts=5}) async {
    attempts=maxAttempts;this.timeout=timeout;
    return handler(SyntheticTransaction());
  }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class SyntheticTransaction implements Transaction {
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class AcceptingTransaction implements Transaction {
  int scheduled=0;
  @override dynamic noSuchMethod(Invocation invocation){
    if(invocation.memberName==#set){scheduled++;return this;}
    return super.noSuchMethod(invocation);
  }
}
class SyntheticReference implements DocumentReference<Map<String,dynamic>> {
  @override final String path;
  SyntheticReference(this.path);
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
class WrappingFirestore extends SyntheticFirestore {
  final tx=AcceptingTransaction();bool invokeTwice=false,failOutside=false;
  WrappingFirestore():super('demo-synthetic');
  @override DocumentReference<Map<String,dynamic>> doc(String path)=>SyntheticReference(path);
  @override Future<T> runTransaction<T>(TransactionHandler<T> handler,{Duration timeout=const Duration(seconds:30),int maxAttempts=5})async{
    if(failOutside)throw FirebaseException(plugin:'cloud_firestore',code:'unavailable');
    try{if(invokeTwice)await handler(tx);return await handler(tx);}
    catch(_){throw FirebaseException(plugin:'cloud_firestore',code:'unknown');}
  }
}
void main(){
 test('emulator adapter has bounded SDK attempts and no default app',()async{
   final db=SyntheticFirestore('demo-synthetic');final port=FirestoreFinanceAtomicPort.emulator(firestore:db);
   expect(await port.atomic((_)async=>42),42);expect(db.configured,1);expect(db.attempts,3);expect(db.timeout,const Duration(seconds:30));
 });
 for(final project in ['real-project','demo']){test('live project $project is refused before configuration',(){final db=SyntheticFirestore(project);expect(()=>FirestoreFinanceAtomicPort.emulator(firestore:db),throwsArgumentError);expect(db.configured,0);});}
 for(final host in ['example.com','192.168.1.2']){test('non-loopback endpoint $host refused',(){final db=SyntheticFirestore('demo-synthetic');expect(()=>FirestoreFinanceAtomicPort.emulator(firestore:db,host:host),throwsArgumentError);expect(db.configured,0);});}
 test('timestamps round trip recursively, server time remains separate',(){
   final date=DateTime.utc(2026,10,15);final encoded=encodeFinanceFirestoreDocument('settlements/trip',{'startDate':date,'receivedEntries':[{'date':date,'amount':20.0}]});
   expect(encoded['updatedAt'],isA<FieldValue>());expect(encoded['startDate'],isA<Timestamp>());
   final decoded=decodeFinanceFirestoreDocument({...encoded}..remove('updatedAt'))!;
   expect(decoded['startDate'],date);expect(((decoded['receivedEntries'] as List).single as Map)['date'],date);
 });
 test('marker gets server creation time without client payload duplication',(){final encoded=encodeFinanceFirestoreDocument('finance/team/financialIntents/${'a'*32}',{'digest':'b'*64});expect(encoded.keys.toSet(),{'digest','createdAt'});expect(encoded['createdAt'],isA<FieldValue>());});
 test('out of protocol paths are refused',(){for(final path in ['users/admin','settlements/trip/unrelated/id','finance/team/financialIntents/bad']){expect(()=>encodeFinanceFirestoreDocument(path,{}),throwsA(isA<Exception>()));}});
 test('missing snapshot remains missing',(){expect(decodeFinanceFirestoreDocument(null),isNull);});
 test('wrapped typed callback refusal is preserved only before any write',()async{
  final db=WrappingFirestore(),refusal=const FinanceRefusal('synthetic_prewrite');
  final port=FirestoreFinanceAtomicPort.emulator(firestore:db);
  await expectLater(port.atomic<void>((_)async{throw refusal;}),throwsA(same(refusal)));expect(db.tx.scheduled,0);
 });
 test('wrapped local conflict before writes retains conflict type',()async{
  final db=WrappingFirestore(),port=FirestoreFinanceAtomicPort.emulator(firestore:db);
  await expectLater(port.atomic<void>((_)async{throw const FinanceRevisionConflict();}),throwsA(isA<FinanceRevisionConflict>()));expect(db.tx.scheduled,0);
 });
 test('refusal after a scheduled write never certifies no-write',()async{
  final db=WrappingFirestore(),port=FirestoreFinanceAtomicPort.emulator(firestore:db);
  await expectLater(port.atomic<void>((tx)async{tx.write('settlements/trip',{});throw const FinanceRefusal('synthetic_after_write');}),throwsA(isA<FirebaseException>()));expect(db.tx.scheduled,1);
 });
 test('writes in earlier callback attempt prevent later refusal promotion',()async{
  final db=WrappingFirestore()..invokeTwice=true;final port=FirestoreFinanceAtomicPort.emulator(firestore:db);var calls=0;
  await expectLater(port.atomic<int>((tx)async{if(++calls==1){tx.write('settlements/trip',{});return 1;}throw const FinanceRefusal('synthetic_later_refusal');}),throwsA(isA<FirebaseException>()));expect(calls,2);expect(db.tx.scheduled,1);
 });
 test('untyped SDK failure without a callback refusal remains untyped',()async{
  final db=WrappingFirestore()..failOutside=true;final port=FirestoreFinanceAtomicPort.emulator(firestore:db);
  await expectLater(port.atomic<void>((_)async{}),throwsA(isA<FirebaseException>()));expect(db.tx.scheduled,0);
 });

}
