import 'package:flutter_test/flutter_test.dart';
import '../lib/finance/per_diem_ledger.dart';

void main() {
  mainAllBalancesTests();
  final date = DateTime(2026, 10, 10);
  PerDiemLedgerEntry e(String id, PerDiemLedgerKind kind, int amount,
      {bool confirmed = true, String? reversesId}) => PerDiemLedgerEntry(
    id: id, distributorId: 'daniel', beneficiaryId: 'ionut',
    kind: kind, amountBani: amount, confirmed: confirmed,
    reversesId: reversesId, occurredAt: date,
  );

  test('Restanța se reportează și se cumulează cu diurna nouă', () {
    final b = calculatePerDiemBalance([
      e('d1', PerDiemLedgerKind.entitlement, 10000),
      e('p1', PerDiemLedgerKind.payment, 7000),
      e('d2', PerDiemLedgerKind.entitlement, 5000),
    ], distributorId: 'daniel', beneficiaryId: 'ionut');
    expect(b.outstandingBani, 8000);
  });

  test('Avansul reduce automat soldul ulterior', () {
    final b = calculatePerDiemBalance([
      e('d1', PerDiemLedgerKind.entitlement, 10000),
      e('p1', PerDiemLedgerKind.payment, 15000),
      e('d2', PerDiemLedgerKind.entitlement, 5000),
    ], distributorId: 'daniel', beneficiaryId: 'ionut');
    expect(b.netBani, 0);
  });

  test('Plata neconfirmată nu modifică soldul', () {
    final b = calculatePerDiemBalance([
      e('d1', PerDiemLedgerKind.entitlement, 10000),
      e('p1', PerDiemLedgerKind.payment, 10000, confirmed: false),
    ], distributorId: 'daniel', beneficiaryId: 'ionut');
    expect(b.outstandingBani, 10000);
    expect(b.pendingPaymentBani, 10000);
  });

  test('Corecția validă anulează o plată, fără ștergerea istoricului', () {
    final b = calculatePerDiemBalance([
      e('d1', PerDiemLedgerKind.entitlement, 10000),
      e('p1', PerDiemLedgerKind.payment, 7000),
      e('r1', PerDiemLedgerKind.reversal, 7000, reversesId: 'p1'),
    ], distributorId: 'daniel', beneficiaryId: 'ionut');
    expect(b.outstandingBani, 10000);
  });

  test('Nu acceptă tranzacții duplicate', () {
    expect(() => calculatePerDiemBalance([
      e('p1', PerDiemLedgerKind.payment, 7000),
      e('p1', PerDiemLedgerKind.payment, 7000),
    ], distributorId: 'daniel', beneficiaryId: 'ionut'), throwsStateError);
  });
}

// Teste suplimentare pentru raportarea soldurilor între echipe/deconturi.
// Sunt separate de main() pentru a păstra testele inițiale intacte.
void mainAllBalancesTests() {
  test('Soldurile a doi distribuitori nu se compensează reciproc', () {
    final date = DateTime(2026, 10, 10);
    PerDiemLedgerEntry entry(String id, String from, String to,
        PerDiemLedgerKind kind, int amount) => PerDiemLedgerEntry(
      id: id, distributorId: from, beneficiaryId: to,
      kind: kind, amountBani: amount, confirmed: true, occurredAt: date,
    );
    final result = calculateAllPerDiemBalances([
      entry('d1', 'daniel', 'ionut', PerDiemLedgerKind.entitlement, 10000),
      entry('p1', 'daniel', 'ionut', PerDiemLedgerKind.payment, 7000),
      entry('d2', 'alt_coleg', 'ionut', PerDiemLedgerKind.entitlement, 5000),
      entry('p2', 'alt_coleg', 'ionut', PerDiemLedgerKind.payment, 8000),
    ]);
    expect(result.length, 2);
    expect(result.values.map((b) => b.netBani).toSet(), {3000, -3000});
  });
}
