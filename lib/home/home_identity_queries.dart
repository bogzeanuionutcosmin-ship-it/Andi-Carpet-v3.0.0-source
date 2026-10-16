import 'package:cloud_firestore/cloud_firestore.dart';

/// Selects the existing identity sources; Home owns all stream subscriptions.
/// No identity, profile or result is cached in this adapter.
abstract class HomeIdentityQueries {
  factory HomeIdentityQueries.fromFirestore(FirebaseFirestore db) = _FirestoreHomeIdentityQueries;
  DocumentReference<Map<String, dynamic>> ownProfile(String uid);
  Query<Map<String, dynamic>> directory({required bool isAdmin});
}

class _FirestoreHomeIdentityQueries implements HomeIdentityQueries {
  final FirebaseFirestore db;
  _FirestoreHomeIdentityQueries(this.db);
  @override
  DocumentReference<Map<String, dynamic>> ownProfile(String uid) =>
      db.collection('users').doc(uid);
  @override
  Query<Map<String, dynamic>> directory({required bool isAdmin}) =>
      isAdmin ? db.collection('users') : db.collection('memberDirectory');
}
