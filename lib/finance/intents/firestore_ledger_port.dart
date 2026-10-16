import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_ledger.dart';
import 'finance_repository.dart';
import 'firestore_finance_port.dart';

// Reuse an already validated demo+loopback port. No default app or independent
// endpoint configuration. No listener, offset, automatic next page or writes.
class FirestoreDemoLedgerPort implements FinanceLedgerPort {
  final FirestoreFinanceAtomicPort source;
  FirestoreDemoLedgerPort.fromFinanceEmulator(this.source);
  @override Future<FinanceServerObservation> target(String path)=>source.readServer(path);
  @override Future<FinanceLedgerObservation> page(String path,int maximumRevision,int limit)async{
    if(!RegExp(r'^(finance|settlements)/[^/]{1,128}$').hasMatch(path)||maximumRevision<1||
        maximumRevision>9007199254740991||limit<1||limit>20)throw const FinanceRefusal('finance_ledger_invalid_query');
    final result=await source.firestore.doc(path).collection('financialIntents')
      .where('revision',isLessThanOrEqualTo:maximumRevision)
      .orderBy('revision',descending:true).limit(limit).get(const GetOptions(source:Source.server));
    return FinanceLedgerObservation(result.docs.map((doc)=>FinanceLedgerRow(doc.id,
      decodeFinanceFirestoreDocument(doc.data())!)).toList(),
      fromCache:result.metadata.isFromCache||result.docs.any((d)=>d.metadata.isFromCache),
      pendingWrites:result.metadata.hasPendingWrites||result.docs.any((d)=>d.metadata.hasPendingWrites));
  }
}
