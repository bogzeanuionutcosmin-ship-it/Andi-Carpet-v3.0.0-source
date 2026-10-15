import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_repository.dart';
import 'finance_intent.dart';

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
  Future<T> atomic<T>(Future<T> Function(FinanceTransaction tx) action) async {
    Object? localRefusal;
    StackTrace? localStack;
    var anyWriteScheduled = false;
    try {
      return await firestore.runTransaction<T>((transaction) async {
        final tx = _FirestoreFinanceTransaction(firestore, transaction,
          () { anyWriteScheduled = true; });
        try { return await action(tx); }
        on FinanceRefusal catch (error, stack) {
          localRefusal = error; localStack = stack; rethrow;
        } on FinanceRevisionConflict catch (error, stack) {
          localRefusal = error; localStack = stack; rethrow;
        }
      }, maxAttempts: 3, timeout: const Duration(seconds: 30));
    } catch (_) {
      // Web SDK can wrap a Dart callback refusal in a generic Firebase error.
      // Only a typed local refusal with ZERO scheduled writes in ALL callback
      // attempts proves this invocation could not have committed a write.
      if (!anyWriteScheduled && localRefusal != null) {
        Error.throwWithStackTrace(localRefusal!, localStack!);
      }
      rethrow;
    }
  }
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
  if (value is Timestamp) {
    return value.nanoseconds % 1000 == 0 ? value.toDate().toUtc() :
      FinanceTimestamp(value.seconds, value.nanoseconds);
  }
  if (value is List) return value.map(_decode).toList();
  if (value is Map) return value.map((key, item) => MapEntry(key as String, _decode(item)));
  return value;
}
Map<String,Object?>? decodeFinanceFirestoreDocument(Map<String,dynamic>? value) =>
  value == null ? null : Map<String,Object?>.from(_decode(value) as Map);
Object? _encode(Object? value) {
  if (value is FinanceTimestamp) return Timestamp(value.seconds, value.nanoseconds);
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
Map<String,dynamic> encodeFinanceFirestoreSnapshot(Map<String,Object?> value) =>
  Map<String,dynamic>.from(_encode(value) as Map);
class _FirestoreFinanceTransaction implements FinanceTransaction {
  final FirebaseFirestore firestore;
  final Transaction transaction;
  final void Function() onWriteScheduled;
  _FirestoreFinanceTransaction(this.firestore, this.transaction, this.onWriteScheduled);
  @override
  Future<Map<String,Object?>?> read(String path) async {
    _validatePath(path);
    return decodeFinanceFirestoreDocument((await transaction.get(firestore.doc(path))).data());
  }
  @override
  void write(String path, Map<String,Object?> value) {
    final document = firestore.doc(path);
    final encoded = encodeFinanceFirestoreDocument(path, value);
    onWriteScheduled();
    transaction.set(document, encoded);
  }
}
