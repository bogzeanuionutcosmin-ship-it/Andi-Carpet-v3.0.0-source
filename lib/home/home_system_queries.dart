import 'package:cloud_firestore/cloud_firestore.dart';

/// Existing settings/audit selections; Home retains authorization guards,
/// snapshots, callbacks, maintenance, mutable settings and cancellation.
abstract class HomeSystemQueries {
  factory HomeSystemQueries.fromFirestore(FirebaseFirestore db) = _FirestoreHomeSystemQueries;
  DocumentReference<Map<String, dynamic>> uiSettings();
  Query<Map<String, dynamic>> audit();
}

class _FirestoreHomeSystemQueries implements HomeSystemQueries {
  final FirebaseFirestore db;
  _FirestoreHomeSystemQueries(this.db);
  @override
  DocumentReference<Map<String, dynamic>> uiSettings() => db.collection('meta').doc('uiSettings');
  @override
  Query<Map<String, dynamic>> audit() => db.collection('audit').orderBy('at', descending: true).limit(500);
}
