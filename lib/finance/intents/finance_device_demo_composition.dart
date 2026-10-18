import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'finance_checked_journal.dart';
import 'finance_demo_panel.dart';
import 'finance_secure_journal.dart';
import 'firestore_finance_port.dart';

// An optional seam for a future Home owner. Only an explicitly demo/loopback
// Firestore port can be passed. Never constructed by main/Home/AuthGate.
// Ownership closure must contain authoritative UID AND epoch. This candidate
// cannot certify multi-tab/process exclusion or physical device durability.
class FinanceDeviceDemoComposition {
  final FinanceDemoScope scope;
  final FinanceCheckedJournalStorage storage;
  FinanceDeviceDemoComposition._(this.scope, this.storage);
  factory FinanceDeviceDemoComposition.singleWriter({required String ownerUid,
    required bool Function() sessionIsCurrent,
    required FirestoreFinanceAtomicPort port}) {
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError:false, migrateOnAlgorithmChange:false),
      webOptions: WebOptions(useSessionStorage:false),
    );
    final storage = FinanceCheckedJournalStorage.singleWriterCandidate(
      storage:const FinanceSecureJournalStorage(secure), ownerUid:ownerUid,
      sessionIsCurrent:sessionIsCurrent);
    final scope = FinanceDemoScope(ownerUid:ownerUid,
      sessionIsCurrent:sessionIsCurrent,port:port,storage:storage);
    return FinanceDeviceDemoComposition._(scope,storage);
  }
  void dispose() { scope.dispose(); storage.dispose(); }
}
