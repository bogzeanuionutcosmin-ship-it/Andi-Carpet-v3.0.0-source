import 'package:cloud_firestore/cloud_firestore.dart';

/// Query selection only. Home owns snapshots, subscriptions and all callbacks.
abstract class HomeMessageQueries {
  factory HomeMessageQueries.fromFirestore(FirebaseFirestore db) = _FirestoreHomeMessageQueries;
  Query<Map<String, dynamic>> notifications({required bool isAdmin, required String uid});
  Query<Map<String, dynamic>> privateMessages(String uid);
  Query<Map<String, dynamic>> groupMessages();
}

class _FirestoreHomeMessageQueries implements HomeMessageQueries {
  final FirebaseFirestore db;
  _FirestoreHomeMessageQueries(this.db);
  @override
  Query<Map<String, dynamic>> notifications({required bool isAdmin, required String uid}) =>
      isAdmin ? db.collection('notifications')
          : db.collection('notifications').where('userId', isEqualTo: uid);
  @override
  Query<Map<String, dynamic>> privateMessages(String uid) =>
      db.collection('chatMessages').where('recipientId', isEqualTo: uid);
  @override
  Query<Map<String, dynamic>> groupMessages() =>
      db.collection('groupChatMessages').orderBy('createdAt', descending: true).limit(20);
}
