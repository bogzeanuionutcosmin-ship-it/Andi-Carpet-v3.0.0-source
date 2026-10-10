import 'package:flutter_test/flutter_test.dart';
import 'per_diem_ledger.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10);
  PerDiemLedgerEntry entry(String id, int amount, {bool confirmed = false,
      PerDiemLedgerKind kind = PerDiemLedgerKind.payment,
      String? reversesId, String distributor = 'a', String beneficiary = 'b',
      DateTime? at}) => PerDiemLedgerEntry(
    id: id, distributorId: distributor, beneficiaryId: beneficiary,
    kind: kind, amountBani: amount, confirmed: confirmed,
    occurredAt: at ?? now, reversesId: reversesId,
  );

  test('Pending becomes paid without double counting', () {
    final before = calculatePerDiemBalance([entry('settlement:1', 10000)],
        distributorId: 'a', beneficiaryId: 'b');
    expect(before.pendingPaymentBani, 10000);
    expect(before.paidBani, 0);
    final after = calculatePerDiemBalance([entry('settlement:1', 10000, confirmed: true)],
        distributorId: 'a', beneficiaryId: 'b');
    expect(after.pendingPaymentBani, 0);
    expect(after.paidBani, 10000);
  });

  test('Partial confirmation is accounted at received amount', () {
    final b = calculatePerDiemBalance([entry('settlement:2', 6000, confirmed: true)],
        distributorId: 'a', beneficiaryId: 'b');
    expect(b.paidBani, 6000);
  });

  test('Duplicate ID across different pairs is rejected', () {
    expect(() => calculateAllPerDiemBalances([
      entry('same', 100), entry('same', 100, distributor: 'c')
    ]), throwsStateError);
  });

  test('Reversal cannot predate original', () {
    expect(() => calculateAllPerDiemBalances([
      entry('p', 100, confirmed: true),
      entry('r', 100, confirmed: true, kind: PerDiemLedgerKind.reversal,
        reversesId: 'p', at: now.subtract(const Duration(days: 1)))
    ]), throwsStateError);
  });

  test('Confirmed reversal removes paid amount', () {
    final b = calculatePerDiemBalance([
      entry('p', 100, confirmed: true),
      entry('r', 100, confirmed: true, kind: PerDiemLedgerKind.reversal,
        reversesId: 'p', at: now.add(const Duration(minutes: 1)))
    ], distributorId: 'a', beneficiaryId: 'b');
    expect(b.paidBani, 0);
  });
}
