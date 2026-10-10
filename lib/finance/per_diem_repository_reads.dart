import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
/// PATCH 27: read-only, participant-scoped streams. Firestore rules are still required.
class PerDiemRepositoryReads {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  PerDiemRepositoryReads(this.db, this.auth);
  Stream<QuerySnapshot<Map<String, dynamic>>> incoming() {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Autentificare necesară');
    return db.collection('per_diem_settlements_v2')
      .where('beneficiaryId', isEqualTo: uid).snapshots();
  }
  Stream<QuerySnapshot<Map<String, dynamic>>> outgoing() {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Autentificare necesară');
    return db.collection('per_diem_settlements_v2')
      .where('distributorId', isEqualTo: uid).snapshots();
  }
}
