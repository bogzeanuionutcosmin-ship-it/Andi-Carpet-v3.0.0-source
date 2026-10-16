import 'package:cloud_firestore/cloud_firestore.dart';
import '../intents/finance_repository.dart';
import '../intents/firestore_finance_port.dart';

/// Emulator-only transport for the opt-in session candidate. This is not a
/// production endpoint factory. The standalone rules fixture is mandatory.
class SessionXiiiFirestorePort implements FinanceAtomicPort {
  final FirebaseFirestore firestore;
  int atomicCalls = 0, callbacks = 0, reads = 0, writes = 0, serverReads = 0;
  SessionXiiiFirestorePort.emulator({required this.firestore}) {
    if (!firestore.app.options.projectId.startsWith('demo-')) {
      throw ArgumentError('session_xiii_emulator_required');
    }
    firestore.useFirestoreEmulator('127.0.0.1', 8080);
  }
  @override Future<T> atomic<T>(Future<T> Function(FinanceTransaction) action) async {
    atomicCalls++;
    return firestore.runTransaction<T>((tx) async {
      callbacks++; return action(_SessionXiiiTransaction(this, tx));
    }, maxAttempts: 3, timeout: const Duration(seconds: 30));
  }
  @override Future<FinanceServerObservation> readServer(String path) async {
    _path(path); serverReads++;
    final snapshot = await firestore.doc(path).get(const GetOptions(source: Source.server));
    return FinanceServerObservation(decodeFinanceFirestoreDocument(snapshot.data()),
      fromCache: snapshot.metadata.isFromCache, pendingWrites: snapshot.metadata.hasPendingWrites);
  }
}
void _path(String path) {
  if (!RegExp(r'^(financeHistoryXi/[sf]_[^/]{1,128}(/receipts/[a-f0-9]{32})?|financeSessionEpochXiii/[^/]{1,128}|financeSessionXiii/[sf]_[^/]{1,128}/permits/[a-f0-9]{32}|(finance|settlements)/[^/]{1,128})$').hasMatch(path)) {
    throw const FinanceRefusal('session_xiii_invalid_path');
  }
}
class _SessionXiiiTransaction implements FinanceTransaction {
  final SessionXiiiFirestorePort port;
  final Transaction tx;
  _SessionXiiiTransaction(this.port, this.tx);
  @override Future<Map<String, Object?>?> read(String path) async {
    _path(path); port.reads++;
    return decodeFinanceFirestoreDocument((await tx.get(port.firestore.doc(path))).data());
  }
  @override void write(String path, Map<String, Object?> value) {
    _path(path);
    if (!path.startsWith('financeHistoryXi/') && !path.startsWith('financeSessionXiii/')) {
      throw const FinanceRefusal('session_xiii_authority_write_forbidden');
    }
    port.writes++;
    final encoded = encodeFinanceFirestoreSnapshot(value);
    tx.set(port.firestore.doc(path), path.startsWith('financeHistoryXi/')
      ? {...encoded, path.contains('/receipts/') ? 'createdAt' : 'updatedAt': FieldValue.serverTimestamp()}
      : encoded);
  }
}
