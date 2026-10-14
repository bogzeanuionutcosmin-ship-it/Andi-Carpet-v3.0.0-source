import 'per_diem_ledger.dart';
import 'per_diem_settlement.dart';

/// PATCH 31-37: proiecții deterministe; fără scrieri Firestore.
/// Sumele sunt în bani. Fiecare obligație și plată trebuie să aibă ID stabil.
class PerDiemOperation {
  final String id;
  final String distributorId;
  final String beneficiaryId;
  final int amountBani;
  final bool isEntitlement;
  final bool confirmed;
  final DateTime at;
  const PerDiemOperation({required this.id, required this.distributorId,
    required this.beneficiaryId, required this.amountBani,
    required this.isEntitlement, required this.confirmed, required this.at});

  PerDiemLedgerEntry toLedgerEntry() {
    if (id.trim().isEmpty || distributorId.trim().isEmpty ||
        beneficiaryId.trim().isEmpty || distributorId == beneficiaryId ||
        amountBani <= 0) {
      throw StateError('Operațiune financiară invalidă');
    }
    return PerDiemLedgerEntry(id: id, distributorId: distributorId,
      beneficiaryId: beneficiaryId, amountBani: amountBani,
      kind: isEntitlement ? PerDiemLedgerKind.entitlement : PerDiemLedgerKind.payment,
      confirmed: confirmed, occurredAt: at);
  }
}

/// Include plățile confirmate din noul flux, fără a trata refuzurile drept plăți.
/// Operațiunile istorice trebuie importate cu identificatori deterministici.
List<PerDiemLedgerEntry> mergeConfirmedSettlements(
    Iterable<PerDiemOperation> operations, Iterable<Settlement> settlements,
    DateTime Function(String settlementId) confirmedAt) {
  final entries = operations.map((e) => e.toLedgerEntry()).toList();
  for (final settlement in settlements) {
    final payment = settlement.toConfirmedPayment(confirmedAt(settlement.id));
    if (payment != null) entries.add(payment);
  }
  final ids = <String>{};
  for (final entry in entries) {
    if (!ids.add(entry.id)) throw StateError('Tranzacție duplicată: ${entry.id}');
  }
  return List.unmodifiable(entries);
}

/// Sold net între deplasări, fără a compensa soldurile altor distribuitori.
PerDiemBalance balanceForPair(Iterable<PerDiemLedgerEntry> entries,
    String distributorId, String beneficiaryId) => calculatePerDiemBalance(
      entries, distributorId: distributorId, beneficiaryId: beneficiaryId);

/// Avansul se compensează matematic prin soldul net; nu creează o plată fictivă.
int amountToPayNow(PerDiemBalance balance, int newEntitlementBani) {
  if (newEntitlementBani < 0) throw RangeError.value(newEntitlementBani);
  final amount = balance.netBani + newEntitlementBani;
  return amount > 0 ? amount : 0;
}

/// Într-o dispută, suma efectiv confirmată rămâne neschimbată.
bool hasOpenDispute(Settlement settlement) =>
    settlement.status == SettlementStatus.disputed;

/// Sumele încă neconfirmate nu se însumează la încasări.
int pendingForPair(Iterable<PerDiemLedgerEntry> entries,
    String distributorId, String beneficiaryId) =>
    balanceForPair(entries, distributorId, beneficiaryId).pendingPaymentBani;
