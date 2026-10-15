import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_repository.dart';

// Mission VIII is an emulator-only staging protocol. No default Firebase app,
// live endpoint, listener, timer, background retry or production switch exists.
class FirestoreFinanceAtomicPort implements FinanceAtomicPort {
  final FirebaseFirestore firestore;
  FirestoreFinanceAtomicPort.emulator({required this.firestore,
    String host = '127.0.0.1', int port = 8080}) {
    if (!firestore.app.options.projectId.startsWith('demo-') ||
        !['127.0.0.1','localhost','10.0.2.2','::1'].contains(host) ||
        port < 1 || port > 65535) {
      throw ArgumentError('finance_emulator_required');
    }
    firestore.useFirestoreEmulator(host, port);
  }
  @override
  Future<T> atomic<T>(Future<T> Function(FinanceTransaction tx) action) =>
    firestore.runTransaction<T>((transaction) => action(_FirestoreFinanceTransaction(firestore, transaction)),
      maxAttempts: 3, timeout: const Duration(seconds: 30));
  @override
  Future<FinanceServerObservation> readServer(String path) async {
    _validatePath(path);
    final snapshot = await firestore.doc(path).get(const GetOptions(source: Source.server));
    return FinanceServerObservation(decodeFinanceFirestoreDocument(snapshot.data()),
      fromCache: snapshot.metadata.isFromCache, pendingWrites: snapshot.metadata.hasPendingWrites);
  }
}
void _validatePath(String path) {
  if (!RegExp(r'^(settlements|finance)/[^/]{1,128}(/financialIntents/[a-f0-9]{32})?$').hasMatch(path)) {
    throw const FinanceRefusal('finance_invalid_path');
  }
}
Object? _decode(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is List) return value.map(_decode).toList();
  if (value is Map) return value.map((key, item) => MapEntry(key as String, _decode(item)));
  return value;
}
Map<String,Object?>? decodeFinanceFirestoreDocument(Map<String,dynamic>? value) =>
  value == null ? null : Map<String,Object?>.from(_decode(value) as Map);
Object? _encode(Object? value) {
  if (value is DateTime) return Timestamp.fromDate(value.toUtc());
  if (value is List) return value.map(_encode).toList();
  if (value is Map) return value.map((key, item) => MapEntry(key as String, _encode(item)));
  return value;
}
Map<String,dynamic> encodeFinanceFirestoreDocument(String path, Map<String,Object?> value) {
  _validatePath(path);
  return <String,dynamic>{...Map<String,dynamic>.from(_encode(value) as Map),
    path.contains('/financialIntents/') ? 'createdAt' : 'updatedAt': FieldValue.serverTimestamp()};
}
class _FirestoreFinanceTransaction implements FinanceTransaction {
  final FirebaseFirestore firestore;
  final Transaction transaction;
  _FirestoreFinanceTransaction(this.firestore, this.transaction);
  @override
  Future<Map<String,Object?>?> read(String path) async {
    _validatePath(path);
    return decodeFinanceFirestoreDocument((await transaction.get(firestore.doc(path))).data());
  }
  @override
  void write(String path, Map<String,Object?> value) {
    transaction.set(firestore.doc(path), encodeFinanceFirestoreDocument(path, value));
  }
}
