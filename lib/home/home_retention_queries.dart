import 'package:cloud_firestore/cloud_firestore.dart';

/// Existing retention selections only. Home computes cutoffs and retains
/// authorization, reads, batch deletion, parent ordering and error handling.
abstract class HomeRetentionQueries {
  factory HomeRetentionQueries.fromFirestore(FirebaseFirestore db) = _FirestoreHomeRetentionQueries;
  Query<Map<String, dynamic>> notificationsBefore(Timestamp cutoff);
  Query<Map<String, dynamic>> backupsBefore(Timestamp cutoff);
}

class _FirestoreHomeRetentionQueries implements HomeRetentionQueries {
  final FirebaseFirestore db;
  _FirestoreHomeRetentionQueries(this.db);
  @override
  Query<Map<String, dynamic>> notificationsBefore(Timestamp cutoff) =>
      db.collection('notifications').where('createdAt', isLessThan: cutoff);
  @override
  Query<Map<String, dynamic>> backupsBefore(Timestamp cutoff) =>
      db.collection('backups').where('createdAt', isLessThan: cutoff);
}
