import 'per_diem_ledger.dart';
/// PATCH 25: debt and advances remain separated by distributor/beneficiary.
class Reconciliation {
  final String distributorId;
  final String beneficiaryId;
  final int dueBani;
  final int paidBani;
  final int pendingBani;
  const Reconciliation(this.distributorId, this.beneficiaryId,
      this.dueBani, this.paidBani, this.pendingBani);
  int get netBani => dueBani - paidBani;
  int get outstandingBani => netBani > 0 ? netBani : 0;
  int get advanceBani => netBani < 0 ? -netBani : 0;
}
List<Reconciliation> reconcilePairs(Iterable<PerDiemLedgerEntry> entries) {
  final source = entries.toList(growable: false);
  final pairs = <String, List<String>>{};
  for (final e in source) {
    pairs['${e.distributorId}\u0000${e.beneficiaryId}'] =
        [e.distributorId, e.beneficiaryId];
  }
  final result = <Reconciliation>[];
  for (final pair in pairs.values) {
    final b = calculatePerDiemBalance(source,
        distributorId: pair[0], beneficiaryId: pair[1]);
    result.add(Reconciliation(pair[0], pair[1], b.dueBani,
        b.paidBani, b.pendingPaymentBani));
  }
  result.sort((a,b) => a.beneficiaryId.compareTo(b.beneficiaryId) != 0
      ? a.beneficiaryId.compareTo(b.beneficiaryId)
      : a.distributorId.compareTo(b.distributorId));
  return result;
}
