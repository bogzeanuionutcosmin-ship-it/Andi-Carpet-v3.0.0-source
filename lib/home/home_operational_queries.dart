import 'package:cloud_firestore/cloud_firestore.dart';

/// Existing global operational queries. Home owns snapshots and side effects.
abstract class HomeOperationalQueries {
  factory HomeOperationalQueries.fromFirestore(FirebaseFirestore db) = _FirestoreHomeOperationalQueries;
  Query<Map<String, dynamic>> teams();
  Query<Map<String, dynamic>> cars();
  Query<Map<String, dynamic>> locations();
  Query<Map<String, dynamic>> schedules();
  Query<Map<String, dynamic>> records();
}

class _FirestoreHomeOperationalQueries implements HomeOperationalQueries {
  final FirebaseFirestore db;
  _FirestoreHomeOperationalQueries(this.db);
  @override
  Query<Map<String, dynamic>> teams() => db.collection('teams');
  @override
  Query<Map<String, dynamic>> cars() => db.collection('cars');
  @override
  Query<Map<String, dynamic>> locations() => db.collection('locations');
  @override
  Query<Map<String, dynamic>> schedules() => db.collection('schedules');
  @override
  Query<Map<String, dynamic>> records() => db.collection('records');
}
