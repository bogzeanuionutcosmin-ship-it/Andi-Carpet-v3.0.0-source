import 'package:cloud_firestore/cloud_firestore.dart';
import '../intents/finance_repository.dart';
import '../intents/firestore_finance_port.dart';

// Separate demo namespace + port. Existing v1 SDK port and app remain intact.
class HistoryXiFirestorePort implements FinanceAtomicPort {
  final FirebaseFirestore firestore;
  int atomicCalls=0,callbacks=0,reads=0,writes=0,serverReads=0;
  HistoryXiFirestorePort.emulator({required this.firestore}) {
    if(!firestore.app.options.projectId.startsWith('demo-'))throw ArgumentError('history_emulator_required');
    firestore.useFirestoreEmulator('127.0.0.1',8080);
  }
  @override Future<T> atomic<T>(Future<T> Function(FinanceTransaction) action) async {
    atomicCalls++;
    // All typed failures are conservatively unclassified by SDK. The model
    // treats wrapped failures as uncertain, never claims server rollback.
    return firestore.runTransaction<T>((tx)async{
      callbacks++;return action(_HistoryTransaction(this,tx));
    },maxAttempts:3,timeout:const Duration(seconds:30));
  }
  @override Future<FinanceServerObservation> readServer(String path) async {
    _path(path);serverReads++;
    final s=await firestore.doc(path).get(const GetOptions(source:Source.server));
    return FinanceServerObservation(decodeFinanceFirestoreDocument(s.data()),
      fromCache:s.metadata.isFromCache,pendingWrites:s.metadata.hasPendingWrites);
  }
}
void _path(String path){
  if(!RegExp(r'^(financeHistoryXi/[sf]_[^/]{1,128}(/receipts/[a-f0-9]{32})?|(finance|settlements)/[^/]{1,128})$').hasMatch(path)) {
    throw const FinanceRefusal('history_invalid_path');
  }
}
class _HistoryTransaction implements FinanceTransaction {
  final HistoryXiFirestorePort port;
  final Transaction tx;
  _HistoryTransaction(this.port,this.tx);
  @override Future<Map<String,Object?>?> read(String path)async{
    _path(path);port.reads++;
    return decodeFinanceFirestoreDocument((await tx.get(port.firestore.doc(path))).data());
  }
  @override void write(String path,Map<String,Object?> value){
    _path(path);
    if(!path.startsWith('financeHistoryXi/'))throw const FinanceRefusal('history_legacy_write_forbidden');
    port.writes++;
    tx.set(port.firestore.doc(path),{...encodeFinanceFirestoreSnapshot(value),
      path.contains('/receipts/')?'createdAt':'updatedAt':FieldValue.serverTimestamp()});
  }
}
