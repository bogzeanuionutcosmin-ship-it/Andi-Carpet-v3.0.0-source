import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_repository.dart';
import 'finance_restore.dart';
import 'firestore_finance_port.dart';

class FirestoreDemoRestorePort implements FinanceRestorePort {
  final FirebaseFirestore firestore;
  FirestoreDemoRestorePort.fromFinanceEmulator(FirestoreFinanceAtomicPort source)
    : firestore=source.firestore;
  FirestoreDemoRestorePort.emulator({required this.firestore,
    String host='127.0.0.1',int port=8080}) {
    // Same explicit demo/loopback boundary as the financial writer.
    FirestoreFinanceAtomicPort.emulator(firestore:firestore,host:host,port:port);
  }
  @override Future<void> atomic(Future<void> Function(FinanceRestoreTransaction) action) async {
    Object? refusal;
    StackTrace? stack;
    var anyWrite=false;
    try {
      await firestore.runTransaction<void>((tx) async {
        try {
          await action(_RestoreTransaction(firestore,tx,()=>anyWrite=true));
        } on FinanceRefusal catch(error,trace) {
          refusal=error;stack=trace;rethrow;
        } on FinanceRevisionConflict catch(error,trace) {
          refusal=error;stack=trace;rethrow;
        }
      },maxAttempts:3,timeout:const Duration(seconds:30));
    } catch (_) {
      if (!anyWrite && refusal!=null) Error.throwWithStackTrace(refusal!,stack!);
      rethrow;
    }
  }
}
class _RestoreTransaction implements FinanceRestoreTransaction {
  final FirebaseFirestore db;
  final Transaction tx;
  final void Function() onWrite;
  var reads=0,writes=0;
  _RestoreTransaction(this.db,this.tx,this.onWrite);
  bool financial(String path) => RegExp(
    r'^(finance|settlements)/[^/]{1,128}(/financialIntents/[a-f0-9]{32})?$').hasMatch(path);
  bool operational(String path) => RegExp(r'^(locations|cars|documents)/[^/]{1,128}$').hasMatch(path);
  @override Future<Map<String,Object?>?> read(String path) async {
    if (writes!=0 || ++reads>FinanceRestorePlan.maxDocuments ||
        (!financial(path) && !operational(path))) {
      throw const FinanceRefusal('finance_restore_invalid_read');
    }
    return decodeFinanceFirestoreDocument((await tx.get(db.doc(path))).data());
  }
  @override void write(String path,Map<String,Object?> data) {
    if (!operational(path) || ++writes>FinanceRestorePlan.maxDocuments) {
      throw const FinanceRefusal('finance_restore_financial_write_forbidden');
    }
    final encoded=encodeFinanceFirestoreSnapshot(data);
    onWrite();tx.set(db.doc(path),encoded);
  }
}
