/// Calculates an indicative payment without treating pending transfers as received.
/// All amounts are integer bani; the plan does not mutate the financial ledger.
class PerDiemPaymentPlan {
  final int dueBani;
  final int confirmedPaidBani;
  final int pendingBani;
  final int newEntitlementBani;
  final int proposedPaymentBani;

  const PerDiemPaymentPlan({
    required this.dueBani,
    required this.confirmedPaidBani,
    required this.pendingBani,
    required this.newEntitlementBani,
    required this.proposedPaymentBani,
  });

  void _validate() {
    if (dueBani < 0 || confirmedPaidBani < 0 || pendingBani < 0 ||
        newEntitlementBani < 0 || proposedPaymentBani < 0) {
      throw ArgumentError('Per diem amounts cannot be negative');
    }
  }

  int get _currentNet {
    _validate();
    return dueBani - confirmedPaidBani;
  }

  int get currentOutstandingBani => _currentNet > 0 ? _currentNet : 0;
  int get currentAdvanceBani => _currentNet < 0 ? -_currentNet : 0;

  /// Includes new entitlement, but excludes pending transfers.
  int get recommendedPaymentBani {
    final net = _currentNet + newEntitlementBani;
    return net > 0 ? net : 0;
  }

  /// Hypothetical balance if the proposed payment is later confirmed.
  int get _expectedNet => _currentNet - proposedPaymentBani;
  int get expectedOutstandingBani => _expectedNet > 0 ? _expectedNet : 0;
  int get expectedAdvanceBani => _expectedNet < 0 ? -_expectedNet : 0;
}
