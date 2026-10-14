import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/per_diem_operations.dart';
import 'package:andi_carpeta/finance/per_diem_settlement.dart';

void main() {
  final at = DateTime.utc(2026, 10, 10);
  PerDiemOperation op(String id, int amount, {bool due = false, bool confirmed = true,
      String distributor = 'daniel'}) => PerDiemOperation(id: id,
    distributorId: distributor, beneficiaryId: 'ionut', amountBani: amount,
    isEntitlement: due, confirmed: confirmed, at: at);

  test('31: confirmarea parțială produce restanță', () {
    final settlement = Settlement(id: 's1', distributorId: 'daniel',
      beneficiaryId: 'ionut', declaredBani: 10000)
        .acknowledge(actorId: 'ionut', received: 7000);
    final entries = mergeConfirmedSettlements([op('due1', 10000, due: true)],
      [settlement], (_) => at);
    expect(balanceForPair(entries, 'daniel', 'ionut').outstandingBani, 3000);
  });
  test('32: refuzul nu creează plată', () {
    final settlement = Settlement(id: 's2', distributorId: 'daniel',
      beneficiaryId: 'ionut', declaredBani: 10000)
        .acknowledge(actorId: 'ionut', received: 0);
    final entries = mergeConfirmedSettlements([op('due', 10000, due: true)],
      [settlement], (_) => at);
    expect(balanceForPair(entries, 'daniel', 'ionut').paidBani, 0);
  });
  test('33: avansul se scade din următoarea diurnă', () {
    final entries = [op('due', 10000, due: true).toLedgerEntry(),
      op('paid', 15000).toLedgerEntry()];
    expect(balanceForPair(entries, 'daniel', 'ionut').advanceBani, 5000);
    expect(amountToPayNow(balanceForPair(entries, 'daniel', 'ionut'), 5000), 0);
  });
  test('34: restanța se cumulează cu diurna nouă', () {
    final entries = [op('due', 10000, due: true).toLedgerEntry(),
      op('paid', 7000).toLedgerEntry()];
    expect(amountToPayNow(balanceForPair(entries, 'daniel', 'ionut'), 5000), 8000);
  });
  test('35: distribuitorii sunt independenți', () {
    final entries = [op('due', 10000, due: true).toLedgerEntry(),
      op('paid', 7000).toLedgerEntry(),
      op('other', 9000, distributor: 'maria').toLedgerEntry()];
    expect(balanceForPair(entries, 'daniel', 'ionut').outstandingBani, 3000);
    expect(balanceForPair(entries, 'maria', 'ionut').advanceBani, 9000);
  });
  test('36: plata neconfirmată nu stinge restanța', () {
    final entries = [op('due', 10000, due: true).toLedgerEntry(),
      op('pending', 10000, confirmed: false).toLedgerEntry()];
    expect(balanceForPair(entries, 'daniel', 'ionut').outstandingBani, 10000);
    expect(pendingForPair(entries, 'daniel', 'ionut'), 10000);
  });
  test('37: duplicatele sunt respinse', () {
    expect(() => mergeConfirmedSettlements([op('dup', 10000), op('dup', 10000)],
      [], (_) => at), throwsStateError);
  });
}
