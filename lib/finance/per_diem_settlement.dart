
import 'per_diem_ledger.dart';

/// Andi Carpet v3.0.1
/// PATCH 15–17 – Diurne
///
/// Model financiar independent de Firebase.
///
/// Reguli:
/// - Beneficiarul confirmă suma primită.
/// - Distribuitorul poate contesta diferența.
/// - Confirmările financiare sunt imuabile.
/// - Plățile suplimentare necesită un Settlement nou.
/// - Fiecare Settlement produce maximum o plată în ledger.
/// - Persistența și auditul se implementează separat.

enum SettlementStatus {
  pending,
  partiallyReceived,
  received,
  refused,
  disputed,
  cancelled,
}

class Settlement {
  static const int maxAmountBani = 100000000;

  final String id;
  final String distributorId;
  final String beneficiaryId;
  final int declaredBani;
  final int? receivedBani;
  final SettlementStatus status;
  final String? disputeReason;

  const Settlement({
    required this.id,
    required this.distributorId,
    required this.beneficiaryId,
    required this.declaredBani,
    this.receivedBani,
    this.status = SettlementStatus.pending,
    this.disputeReason,
  });

  /// Verifică integritatea datelor.
  void validate() {
    if (id.trim().isEmpty ||
        distributorId.trim().isEmpty ||
        beneficiaryId.trim().isEmpty) {
      throw StateError('Identificator invalid');
    }

    if (distributorId == beneficiaryId) {
      throw StateError(
        'Distribuitorul și beneficiarul trebuie să fie diferiți',
      );
    }

    if (declaredBani <= 0 ||
        declaredBani > maxAmountBani) {
      throw StateError('Sumă declarată invalidă');
    }

    if (receivedBani != null &&
        (receivedBani! < 0 ||
            receivedBani! > declaredBani)) {
      throw StateError('Sumă primită invalidă');
    }

    switch (status) {
      case SettlementStatus.pending:
        if (receivedBani != null) {
          throw StateError(
            'O solicitare nouă nu poate avea sumă confirmată',
          );
        }
        break;

      case SettlementStatus.received:
        if (receivedBani != declaredBani) {
          throw StateError(
            'Primirea integrală necesită suma completă',
          );
        }
        break;

      case SettlementStatus.partiallyReceived:
        if (receivedBani == null ||
            receivedBani! <= 0 ||
            receivedBani! >= declaredBani) {
          throw StateError(
            'Confirmarea parțială este invalidă',
          );
        }
        break;

      case SettlementStatus.refused:
        if (receivedBani != 0) {
          throw StateError(
            'Refuzul trebuie să aibă suma primită zero',
          );
        }
        break;

      case SettlementStatus.disputed:
        if (receivedBani == null ||
            receivedBani! >= declaredBani ||
            disputeReason == null ||
            disputeReason!.trim().isEmpty ||
            disputeReason!.trim().length > 1000) {
          throw StateError(
            'Contestație invalidă',
          );
        }
        break;

      case SettlementStatus.cancelled:
        if (receivedBani != null &&
            receivedBani != 0) {
          throw StateError(
            'O solicitare cu bani confirmați nu poate fi anulată',
          );
        }
        break;
    }

    if (status != SettlementStatus.disputed &&
        disputeReason != null) {
      throw StateError(
        'Motivul contestației nu corespunde stării',
      );
    }
  }

  /// Diferența dintre suma declarată și cea primită.
  int get differenceBani =>
      declaredBani - (receivedBani ?? 0);

  bool get isFullyReceived =>
      status == SettlementStatus.received &&
      receivedBani == declaredBani;

  bool get hasDifference =>
      receivedBani != null &&
      receivedBani != declaredBani;

  /// Beneficiarul confirmă suma primită.
  ///
  /// 0 = refuz
  /// parțial = primire parțială
  /// integral = primire completă
  ///
  /// Un refuz poate fi revizuit.
  /// O confirmare pozitivă nu poate fi rescrisă.
  Settlement acknowledge({
    required String actorId,
    required int received,
  }) {
    validate();

    if (actorId != beneficiaryId) {
      throw StateError(
        'Doar beneficiarul poate confirma încasarea',
      );
    }

    if (status != SettlementStatus.pending &&
        status != SettlementStatus.refused) {
      throw StateError(
        'Solicitarea a fost deja procesată',
      );
    }

    if (received < 0 || received > declaredBani) {
      throw RangeError.range(
        received,
        0,
        declaredBani,
        'received',
      );
    }

    final SettlementStatus nextStatus;

    if (received == 0) {
      nextStatus = SettlementStatus.refused;
    } else if (received == declaredBani) {
      nextStatus = SettlementStatus.received;
    } else {
      nextStatus = SettlementStatus.partiallyReceived;
    }

    final result = Settlement(
      id: id,
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      declaredBani: declaredBani,
      receivedBani: received,
      status: nextStatus,
    );

    result.validate();
    return result;
  }

  /// Distribuitorul contestă o diferență.
  ///
  /// Nu modifică suma deja confirmată.
  Settlement dispute({
    required String actorId,
    required String reason,
  }) {
    validate();

    if (actorId != distributorId) {
      throw StateError(
        'Doar distribuitorul poate contesta',
      );
    }

    if (status != SettlementStatus.partiallyReceived &&
        status != SettlementStatus.refused) {
      throw StateError(
        'Starea actuală nu permite contestarea',
      );
    }

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty ||
        normalizedReason.length > 1000) {
      throw ArgumentError(
        'Motivul trebuie să aibă între 1 și 1000 de caractere',
      );
    }

    final result = Settlement(
      id: id,
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      declaredBani: declaredBani,
      receivedBani: receivedBani,
      status: SettlementStatus.disputed,
      disputeReason: normalizedReason,
    );

    result.validate();
    return result;
  }

  /// Anulează o solicitare fără bani confirmați.
  ///
  /// Distribuitorul poate anula solicitarea.
  /// Nu se permite anularea unei plăți confirmate.
  Settlement cancel({
    required String actorId,
  }) {
    validate();

    if (actorId != distributorId) {
      throw StateError(
        'Doar distribuitorul poate anula solicitarea',
      );
    }

    if (status != SettlementStatus.pending &&
        status != SettlementStatus.refused) {
      throw StateError(
        'Solicitarea nu mai poate fi anulată',
      );
    }

    final result = Settlement(
      id: id,
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      declaredBani: declaredBani,
      status: SettlementStatus.cancelled,
    );

    result.validate();
    return result;
  }

  /// Generează intrarea financiară confirmată.
  ///
  /// ID stabil pentru deduplicare.
  /// Apelurile repetate produc același ID.
  ///
  /// IMPORTANT:
  /// Persistența trebuie să folosească create-if-absent
  /// într-o tranzacție atomică Firebase.
  PerDiemLedgerEntry? toConfirmedPayment(DateTime at) {
    validate();

    if (receivedBani == null ||
        receivedBani! <= 0) {
      return null;
    }

    if (status != SettlementStatus.received &&
        status != SettlementStatus.partiallyReceived &&
        status != SettlementStatus.disputed) {
      return null;
    }

    return PerDiemLedgerEntry(
      id: 'settlement:$id',
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      kind: PerDiemLedgerKind.payment,
      amountBani: receivedBani!,
      confirmed: true,
      occurredAt: at,
    );
  }
}

/// Rezumat financiar pentru diurne.
class SettlementSummary {
  final int dueBani;
  final int paidBani;
  final int pendingBani;
  final int outstandingBani;
  final int advanceBani;

  SettlementSummary(PerDiemBalance balance)
      : dueBani = balance.dueBani,
        paidBani = balance.paidBani,
        pendingBani = balance.pendingPaymentBani,
        outstandingBani = balance.outstandingBani,
        advanceBani = balance.advanceBani;
}
