import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'per_diem_settlement.dart';

/// PATCH 15–17
/// Persistență tranzacțională, audit și reconciliere pentru diurne.
///
/// IMPORTANT:
/// Necesită reguli Firestore server-side înainte de producție.
class PerDiemFirestoreRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  /// Limită de siguranță: 1.000.000 RON.
  static const int maxAmountBani = 100000000;

  PerDiemFirestoreRepository(
    this.db, {
    FirebaseAuth? auth,
  }) : auth = auth ?? FirebaseAuth.instance;

  void _requireActor(String actorId) {
    if (actorId.trim().isEmpty ||
        auth.currentUser?.uid != actorId) {
      throw StateError('Utilizator neautorizat');
    }
  }

  void _validateId(String value, String field) {
    if (value.isEmpty ||
        value.trim() != value ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      throw ArgumentError('$field invalid');
    }
  }

  void _validateAmount(int amount, {bool allowZero = false}) {
    if (amount < (allowZero ? 0 : 1) ||
        amount > maxAmountBani) {
      throw RangeError.range(
        amount,
        allowZero ? 0 : 1,
        maxAmountBani,
        'amountBani',
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _settlement(String id) {
    _validateId(id, 'ID distribuire');

    return db.collection('per_diem_settlements_v2').doc(id);
  }

  Settlement _decodeSettlement(
    String id,
    Map<String, dynamic> data,
  ) {
    try {
      final distributorId = data['distributorId'] as String;
      final beneficiaryId = data['beneficiaryId'] as String;
      final declaredBani = data['declaredBani'] as int;
      final receivedBani = data['receivedBani'] as int?;
      final statusName = data['status'] as String;

      _validateId(distributorId, 'distributorId');
      _validateId(beneficiaryId, 'beneficiaryId');
      _validateAmount(declaredBani);

      if (distributorId == beneficiaryId) {
        throw StateError('Distribuitorul și beneficiarul coincid');
      }

      if (receivedBani != null) {
        _validateAmount(receivedBani, allowZero: true);
      }

      final status = SettlementStatus.values.byName(statusName);

      return Settlement(
        id: id,
        distributorId: distributorId,
        beneficiaryId: beneficiaryId,
        declaredBani: declaredBani,
        receivedBani: receivedBani,
        status: status,
      );
    } catch (error) {
      throw StateError(
        'Date Firestore invalide pentru distribuirea $id: $error',
      );
    }
  }

  int _nextRevision(Map<String, dynamic> data) {
    final revision = data['revision'];

    if (revision is! int || revision < 0) {
      throw StateError('Revizie Firestore invalidă');
    }

    if (revision >= 2147483647) {
      throw StateError('Limita reviziilor a fost atinsă');
    }

    return revision + 1;
  }

  /// Distribuitorul declară plata.
  /// Beneficiarul trebuie să confirme suma primită.
  Future<void> declarePayment({
    required String id,
    required String distributorId,
    required String beneficiaryId,
    required int amountBani,
    required String actorId,
    required String paymentMethod,
  }) async {
    _validateId(id, 'ID distribuire');
    _validateId(distributorId, 'distributorId');
    _validateId(beneficiaryId, 'beneficiaryId');
    _validateAmount(amountBani);

    if (distributorId == beneficiaryId ||
        actorId != distributorId ||
        !{'cash', 'transfer'}.contains(paymentMethod)) {
      throw ArgumentError('Date de distribuire invalide');
    }

    _requireActor(actorId);

    final ref = _settlement(id);
    final auditRef = ref.collection('audit').doc('declare');

    await db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);

      if (snapshot.exists) {
        throw StateError('Distribuire deja înregistrată');
      }

      tx.set(ref, {
        'distributorId': distributorId,
        'beneficiaryId': beneficiaryId,
        'declaredBani': amountBani,
        'receivedBani': null,
        'status': 'pending',
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': 0,
      });

      tx.set(auditRef, {
        'action': 'declare',
        'actorId': actorId,
        'amountBani': amountBani,
        'previousStatus': null,
        'newStatus': 'pending',
        'revision': 0,
        'at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Beneficiarul confirmă suma efectiv primită.
  /// Zero reprezintă refuzul încasării.
  Future<void> acknowledge({
    required String id,
    required String actorId,
    required int receivedBani,
  }) async {
    _validateId(id, 'ID distribuire');
    _validateAmount(receivedBani, allowZero: true);
    _requireActor(actorId);

    final ref = _settlement(id);

    await db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);

      if (!snapshot.exists) {
        throw StateError('Distribuire inexistentă');
      }

      final data = snapshot.data()!;
      final previous = _decodeSettlement(id, data);

      final next = previous.acknowledge(
        actorId: actorId,
        received: receivedBani,
      );

      final revision = _nextRevision(data);

      final auditRef = ref.collection('audit').doc(
        'revision-$revision',
      );

      tx.update(ref, {
        'receivedBani': receivedBani,
        'status': next.status.name,
        'revision': revision,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(auditRef, {
        'action': receivedBani == 0
            ? 'refuse'
            : 'acknowledge',
        'actorId': actorId,
        'receivedBani': receivedBani,
        'previousReceivedBani': previous.receivedBani,
        'previousStatus': previous.status.name,
        'newStatus': next.status.name,
        'revision': revision,
        'at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Contestarea nu șterge încasarea confirmată.
  /// Diferența financiară rămâne înregistrată.
  Future<void> dispute({
    required String id,
    required String actorId,
    required String reason,
  }) async {
    _validateId(id, 'ID distribuire');
    _requireActor(actorId);

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty ||
        normalizedReason.length > 1000) {
      throw ArgumentError(
        'Motivul trebuie să conțină între 1 și 1000 de caractere',
      );
    }

    final ref = _settlement(id);

    await db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);

      if (!snapshot.exists) {
        throw StateError('Distribuire inexistentă');
      }

      final data = snapshot.data()!;
      final previous = _decodeSettlement(id, data);

      final next = previous.dispute(
        actorId: actorId,
        reason: normalizedReason,
      );

      final revision = _nextRevision(data);

      final auditRef = ref.collection('audit').doc(
        'revision-$revision',
      );

      tx.update(ref, {
        'status': next.status.name,
        'disputeReason': normalizedReason,
        'revision': revision,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(auditRef, {
        'action': 'dispute',
        'actorId': actorId,
        'reason': normalizedReason,
        'previousStatus': previous.status.name,
        'newStatus': next.status.name,
        'revision': revision,
        'at': FieldValue.serverTimestamp(),
      });
    });
  }
}
