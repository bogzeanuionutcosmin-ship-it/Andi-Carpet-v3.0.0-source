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
  // The native bridge can complete an offline transaction without a server
  // acknowledgement. Refuse before preparing it, then confirm authoritative
  // fields before HomePage is allowed to replace its local model.
  final available = await ref.get(const GetOptions(source: Source.server));
  if (available.metadata.isFromCache || available.metadata.hasPendingWrites) {
    throw StateError('Există o salvare neconfirmată. Reconectează și reîncarcă înainte de corectare.');
  }
  await db.runTransaction<void>((tx) async {
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
  final confirmed = await ref.get(const GetOptions(source: Source.server));
  final desired = <String, Object?>{...expected, ...changes}..remove('updatedAt');
  if (confirmed.metadata.isFromCache || confirmed.metadata.hasPendingWrites ||
      !confirmed.exists ||
      !centralizerCorrectionSnapshotMatches(confirmed.data()!, desired)) {
    throw StateError('Corecția nu a putut fi confirmată. Reîncarcă înainte de retry.');
  }
}
