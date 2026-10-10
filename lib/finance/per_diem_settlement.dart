
import 'per_diem_ledger.dart';

/// PATCH 15–17
/// Model de stare pentru distribuirea și confirmarea diurnelor.
///
/// Persistența, autentificarea și auditul sunt gestionate separat.
/// Tranzițiile trebuie validate și prin regulile Firestore.

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

  /// Diferența rămasă de achitat.
  int get differenceBani {
    final received = receivedBani ?? 0;
    return declaredBani - received;
  }

  /// Confirmă dacă suma declarată a fost primită integral.
  bool get isFullyReceived =>
      status == SettlementStatus.received &&
      receivedBani == declaredBani;

  /// Indică existența unei diferențe financiare.
  bool get hasDifference =>
      receivedBani != null &&
      receivedBani != declaredBani;

  /// Beneficiarul confirmă suma efectiv primită.
  ///
  /// 0 = refuz
  /// între 0 și suma declarată = primire parțială
  /// suma declarată = primire integrală
  ///
  /// Un refuz poate fi revizuit.
  Settlement acknowledge({
    required String actorId,
    required int received,
  }) {
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

    if (declaredBani <= 0 ||
        declaredBani > maxAmountBani) {
      throw StateError(
        'Suma declarată este invalidă',
      );
    }

    if (received < 0 || received > declaredBani) {
      throw RangeError.range(
        received,
        0,
        declaredBani,
        'received',
        'Suma confirmată nu poate depăși suma declarată',
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

    return Settlement(
      id: id,
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      declaredBani: declaredBani,
      receivedBani: received,
      status: nextStatus,
    );
  }

  /// Distribuitorul poate contesta o diferență.
  ///
  /// Contestarea nu modifică suma deja confirmată.
  Settlement dispute({
    required String actorId,
    required String reason,
  }) {
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

    if (receivedBani == null ||
        receivedBani! >= declaredBani) {
      throw StateError(
        'Nu există diferență contestabilă',
      );
    }

    final normalizedReason = reason.trim();

    if (normalizedReason.isEmpty ||
        normalizedReason.length > 1000) {
      throw ArgumentError(
        'Motivul trebuie să aibă între 1 și 1000 de caractere',
      );
    }

    return Settlement(
      id: id,
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      declaredBani: declaredBani,
      receivedBani: receivedBani,
      status: SettlementStatus.disputed,
      disputeReason: normalizedReason,
    );
  }

  /// Transformă o încasare confirmată într-o intrare de ledger.
  ///
  /// ID-ul stabil permite deduplicarea în ledger.
  /// Contestarea nu anulează banii deja primiți.
  PerDiemLedgerEntry? toConfirmedPayment(DateTime at) {
    if (receivedBani == null ||
        receivedBani! <= 0) {
      return null;
    }

    if (status != SettlementStatus.received &&
        status != SettlementStatus.partiallyReceived &&
        status != SettlementStatus.disputed) {
      return null;
    }

    if (receivedBani! > declaredBani ||
        declaredBani <= 0) {
      throw StateError(
        'Valori financiare inconsistente',
      );
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

/// Rezumatul financiar al diurnelor.
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
