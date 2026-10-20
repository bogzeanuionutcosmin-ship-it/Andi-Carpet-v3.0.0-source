import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/legacy_per_diem_balance.dart';
import 'package:andi_carpeta/finance/per_diem_ledger.dart';
import 'package:andi_carpeta/finance/per_diem_money.dart';

class _LegacyPerDiem {
  const _LegacyPerDiem({
    this.member = 'worker',
    this.distributor = 'manager',
    this.confirmed = true,
    this.declared = 100,
    this.received = 100,
    this.supplementaryFor,
  });

  final String member;
  final String? distributor;
  final bool confirmed;
  final double declared;
  final double? received;
  final String? supplementaryFor;
}

int _balance(Iterable<_LegacyPerDiem> entries,
    {String beneficiary = 'worker', String distributor = 'manager'}) {
  return calculateLegacyPerDiemDifferenceBani<_LegacyPerDiem>(
    entries: entries,
    beneficiaryId: beneficiary,
    distributorId: distributor,
    memberId: (entry) => entry.member,
    distributedBy: (entry) => entry.distributor,
    isConfirmed: (entry) => entry.confirmed,
    actualReceivedAmount: (entry) => entry.received,
    declaredAmount: (entry) => entry.declared,
    supplementaryFor: (entry) => entry.supplementaryFor,
  );
}

void main() {
  group('legacy per-diem carryover policy', () {
    test('exact receipt has no balance; short receipt leaves amount due', () {
      expect(_balance(const [_LegacyPerDiem(declared: 100, received: 100)]), 0);
      expect(_balance(const [_LegacyPerDiem(declared: 100, received: 90)]), 1000);
    });

    test('overpayment is reported as an advance', () {
      expect(_balance(const [_LegacyPerDiem(declared: 100, received: 110)]), -1000);
    });

    test('supplementary cash repays prior debt without adding entitlement', () {
      expect(
        _balance(const [
          _LegacyPerDiem(declared: 100, received: 80),
          _LegacyPerDiem(
            declared: 50,
            received: 50,
            supplementaryFor: 'original',
          ),
        ]),
        2000,
      );
    });

    test('pending, missing receipt, and malformed amounts are skipped', () {
      expect(
        _balance(const [
          _LegacyPerDiem(confirmed: false, declared: 100, received: 0),
          _LegacyPerDiem(received: null),
          _LegacyPerDiem(declared: double.nan, received: 10),
          _LegacyPerDiem(declared: 20, received: double.infinity),
        ]),
        0,
      );
    });

    test('other distributor-beneficiary pairs do not affect the balance', () {
      expect(
        _balance(const [
          _LegacyPerDiem(declared: 100, received: 80),
          _LegacyPerDiem(member: 'other-worker', declared: 500, received: 0),
          _LegacyPerDiem(distributor: 'other-manager', declared: 700, received: 0),
        ]),
        2000,
      );
    });
  });

  test('parser and ledger limits differ; they are not interchangeable', () {
    // Legacy parser values are lei converted to bani. The standalone ledger
    // has its own validation limit; this boundary test documents the mismatch
    // and does not adapt or feed legacy balances into the ledger.
    final ledgerMaximumBani = parsePerDiemBani('1000000')!;
    expect(ledgerMaximumBani, 100000000);

    PerDiemLedgerEntry ledgerEntry(int amountBani) => PerDiemLedgerEntry(
      id: 'entry',
      distributorId: 'manager',
      beneficiaryId: 'worker',
      kind: PerDiemLedgerKind.payment,
      amountBani: amountBani,
      confirmed: true,
      occurredAt: DateTime(2026, 10, 20),
    );

    expect(
      () => calculatePerDiemBalance(
        [ledgerEntry(ledgerMaximumBani)],
        distributorId: 'manager',
        beneficiaryId: 'worker',
      ),
      returnsNormally,
    );

    final aboveLedgerMaximumBani = parsePerDiemBani('1000000.01')!;
    expect(aboveLedgerMaximumBani, 100000001);
    expect(
      () => calculatePerDiemBalance(
        [ledgerEntry(aboveLedgerMaximumBani)],
        distributorId: 'manager',
        beneficiaryId: 'worker',
      ),
      throwsStateError,
    );
    expect(parsePerDiemBani('100000000'), 10000000000);
  });
}
