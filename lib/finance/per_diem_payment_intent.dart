/// PATCH 28: explicit pending payment intents, never count as received.
class PaymentIntent {
  final String id;
  final String distributorId;
  final String beneficiaryId;
  final int declaredBani;
  final DateTime createdAt;
  const PaymentIntent({required this.id, required this.distributorId,
    required this.beneficiaryId, required this.declaredBani,
    required this.createdAt});
  void validate() {
    if (id.trim().isEmpty || distributorId.trim().isEmpty ||
        beneficiaryId.trim().isEmpty || distributorId == beneficiaryId ||
        declaredBani <= 0) throw ArgumentError('Plată invalidă');
  }
}
