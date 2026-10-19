import 'package:cloud_firestore/cloud_firestore.dart';
import 'correction_snapshot.dart';

/// The persistence operation used by HomePage after its permission and identity
/// checks. Update only: stale or deleted interventions must not be recreated.
Future<void> correctCentralizerRecordCompared(
  FirebaseFirestore db,
  String id, {
  required Map<String, Object?> expected,
  required Map<String, dynamic> changes,
}) async {
  final ref = db.collection('records').doc(id);
  await db.runTransaction((tx) async {
    final snapshot = await tx.get(ref);
    if (!snapshot.exists) {
      throw StateError('Intervenția a fost ștearsă. Reîncarcă Centralizatorul.');
    }
    final current = snapshot.data()!;
    if (!centralizerCorrectionSnapshotMatches(current, expected)) {
      throw StateError('Intervenția a fost modificată pe alt dispozitiv. Reîncarcă înainte de corectare.');
    }
    tx.update(ref, changes);
  });
}
