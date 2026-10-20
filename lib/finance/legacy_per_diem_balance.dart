import 'per_diem_money.dart';

/// Preserves the legacy Expenses carryover policy for one distributor and
/// beneficiary pair. Field selectors keep this policy independent from the
/// application part models and make its behavior directly testable.
///
/// This is intentionally separate from [calculatePerDiemBalance]: the legacy
/// model treats supplementary distributions as repayments, while the ledger
/// models entitlements, payments, and reversals.
int calculateLegacyPerDiemDifferenceBani<T>({
  required Iterable<T> entries,
  required String beneficiaryId,
  required String distributorId,
  required String? Function(T entry) memberId,
  required String? Function(T entry) distributedBy,
  required bool Function(T entry) isConfirmed,
  required num? Function(T entry) actualReceivedAmount,
  required num? Function(T entry) declaredAmount,
  required Object? Function(T entry) supplementaryFor,
}) {
  var balance = 0;
  for (final entry in entries) {
    final actualReceived = actualReceivedAmount(entry);
    if (memberId(entry) != beneficiaryId ||
        distributedBy(entry) != distributorId ||
        !isConfirmed(entry) ||
        actualReceived == null) {
      continue;
    }
    final receivedBani = parsePerDiemBani(actualReceived.toString());
    final declaredBani = parsePerDiemBani(declaredAmount(entry).toString());
    if (receivedBani == null || declaredBani == null) continue;

    // A supplementary distribution repays an earlier debt; it is not a new
    // daily allowance to add to the declared amount.
    balance += (supplementaryFor(entry) == null ? declaredBani : 0) -
        receivedBani;
  }
  return balance;
}
