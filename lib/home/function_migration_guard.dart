import 'package:cloud_firestore/cloud_firestore.dart';

/// Login may inspect migration state, but must never reset role assignments or
/// delete definitions. A missing marker requires explicit reconciliation.
Future<bool> functionBadgeMigrationReady(FirebaseFirestore db) async {
  final snapshot=await db.collection('meta').doc('uiSettings')
    .get(const GetOptions(source:Source.server));
  if(snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
    throw StateError('Starea funcțiilor nu este confirmată de server.');
  }
  return snapshot.data()?['functionSystemVersion'] == 'badge_v2';
}
