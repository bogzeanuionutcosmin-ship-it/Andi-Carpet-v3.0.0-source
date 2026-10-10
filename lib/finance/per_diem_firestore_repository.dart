import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'per_diem_settlement.dart';

/// PATCH 15-17: persistență tranzacțională, audit și reconciliere.
/// Necesită reguli Firestore server-side înainte de folosirea în producție.
class PerDiemFirestoreRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  PerDiemFirestoreRepository(this.db, {FirebaseAuth? auth})
      : auth = auth ?? FirebaseAuth.instance;

  void _requireActor(String actorId) {
    if (auth.currentUser?.uid != actorId) {
      throw StateError('Utilizator neautorizat');
    }
  }

  DocumentReference<Map<String, dynamic>> _settlement(String id) =>
      db.collection('per_diem_settlements_v2').doc(id);

  /// Distribuitorul declară plata; beneficiarul trebuie să o confirme.
  Future<void> declarePayment({required String id, required String distributorId,
    required String beneficiaryId, required int amountBani,
    required String actorId, required String paymentMethod}) async {
    if (id.trim().isEmpty || distributorId.isEmpty || beneficiaryId.isEmpty ||
        distributorId == beneficiaryId || actorId != distributorId || amountBani <= 0 ||
        !{'cash', 'transfer'}.contains(paymentMethod)) {
      throw ArgumentError('Date de distribuire invalide');
    }
    _requireActor(actorId);
    final ref = _settlement(id);
    await db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) throw StateError('Distribuire deja înregistrată');
      tx.set(ref, {
        'distributorId': distributorId, 'beneficiaryId': beneficiaryId,
        'declaredBani': amountBani, 'receivedBani': null,
        'status': 'pending', 'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': 0,
      });
      tx.set(ref.collection('audit').doc('declare'), {
        'action': 'declare', 'actorId': actorId,
        'amountBani': amountBani, 'at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Încasarea este consemnată o singură dată; refuzul (0) poate fi revizuit.
  Future<void> acknowledge({required String id, required String actorId,
    required int receivedBani}) async {
    if (receivedBani < 0) throw RangeError.value(receivedBani);
    _requireActor(actorId);
    final ref = _settlement(id);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Distribuire inexistentă');
      final d = snap.data()!;
      final previous = Settlement(
        id: id, distributorId: d['distributorId'] as String,
        beneficiaryId: d['beneficiaryId'] as String,
        declaredBani: d['declaredBani'] as int,
        receivedBani: d['receivedBani'] as int?,
        status: SettlementStatus.values.byName(d['status'] as String),
      );
      final next = previous.acknowledge(actorId: actorId, received: receivedBani);
      final revision = (d['revision'] as int? ?? 0) + 1;
      tx.update(ref, {
        'receivedBani': receivedBani, 'status': next.status.name,
        'revision': revision, 'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(ref.collection('audit').doc('$revision'), {
        'action': receivedBani == 0 ? 'refuse' : 'acknowledge',
        'actorId': actorId, 'receivedBani': receivedBani,
        'previousStatus': previous.status.name, 'at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Contestația nu șterge încasarea confirmată și nu stinge diferența.
  Future<void> dispute({required String id, required String actorId,
    required String reason}) async {
    if (reason.trim().isEmpty) throw ArgumentError('Motiv obligatoriu');
    _requireActor(actorId);
    final ref = _settlement(id);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Distribuire inexistentă');
      final d = snap.data()!;
      final previous = Settlement(
        id: id, distributorId: d['distributorId'] as String,
        beneficiaryId: d['beneficiaryId'] as String,
        declaredBani: d['declaredBani'] as int,
        receivedBani: d['receivedBani'] as int?,
        status: SettlementStatus.values.byName(d['status'] as String),
      );
      final next = previous.dispute(actorId: actorId, reason: reason);
      final revision = (d['revision'] as int? ?? 0) + 1;
      tx.update(ref, {
        'status': next.status.name, 'disputeReason': reason.trim(),
        'revision': revision, 'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(ref.collection('audit').doc('dispute-$revision'), {
        'action': 'dispute', 'actorId': actorId,
        'reason': reason.trim(), 'at': FieldValue.serverTimestamp(),
      });
    });
  }
}
