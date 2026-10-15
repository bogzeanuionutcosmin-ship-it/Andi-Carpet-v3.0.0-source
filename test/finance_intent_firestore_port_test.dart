import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/firestore_finance_port.dart';

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
}
