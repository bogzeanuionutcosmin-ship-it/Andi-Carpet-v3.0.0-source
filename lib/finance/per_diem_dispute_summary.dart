/// PATCH 29: disputed differences remain visible, never automatically settled.
class DisputeSummary {
  final String settlementId;
  final int declaredBani;
  final int receivedBani;
  final String reason;
  const DisputeSummary(this.settlementId, this.declaredBani,
      this.receivedBani, this.reason);
  int get disputedDifferenceBani => declaredBani - receivedBani;
  bool get isValid => settlementId.isNotEmpty && reason.trim().isNotEmpty &&
      declaredBani > 0 && receivedBani >= 0 &&
      declaredBani != receivedBani;
}
