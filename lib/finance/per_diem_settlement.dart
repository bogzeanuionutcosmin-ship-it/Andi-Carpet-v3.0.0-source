
import 'per_diem_ledger.dart';

/// Flux pur de stare. Persistența și autorizarea trebuie aplicate separat în Firebase.
enum SettlementStatus {
  pending,
  partiallyReceived,
  received,
  refused,
  disputed,
  cancelled,
}

class Settlement {
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

  Settlement acknowledge({
    required String actorId,
    required int received,
  }) {
    if (actorId != beneficiaryId) {
      throw StateError('Doar beneficiarul poate confirma');
    }

    if (status != SettlementStatus.pending &&
        status != SettlementStatus.refused) {
      throw StateError('Solicitare deja procesată');
    }

    if (received < 0) {
      throw RangeError.value(received, 'received');
    }

    return Settlement(
      id: id,
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      declaredBani: declaredBani,
      receivedBani: received,
      status: received == 0
          ? SettlementStatus.refused
          : received == declaredBani
              ? SettlementStatus.received
              : SettlementStatus.partiallyReceived,
    );
  }

  Settlement dispute({
    required String actorId,
    required String reason,
  }) {
    if (actorId != distributorId) {
      throw StateError('Doar distribuitorul poate contesta');
    }

    if (receivedBani == null ||
        receivedBani == declaredBani ||
        status == SettlementStatus.disputed ||
        status == SettlementStatus.cancelled) {
      throw StateError('Nu există diferență contestabilă');
    }

    if (reason.trim().isEmpty) {
      throw ArgumentError('Motiv obligatoriu');
    }

    return Settlement(
      id: id,
      distributorId: distributorId,
      beneficiaryId: beneficiaryId,
      declaredBani: declaredBani,
      receivedBani: receivedBani,
      status: SettlementStatus.disputed,
      disputeReason: reason.trim(),
    );
  }

  /// O plată confirmată produce o singură intrare;
  /// cheia stabilă previne dublarea.
  PerDiemLedgerEntry? toConfirmedPayment(DateTime at) {
    if (receivedBani == null || receivedBani! <= 0) {
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
