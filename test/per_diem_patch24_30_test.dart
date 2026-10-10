import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/per_diem_money.dart';
import 'package:andi_carpeta/finance/per_diem_reconciliation.dart';
import 'package:andi_carpeta/finance/per_diem_payment_intent.dart';
import 'package:andi_carpeta/finance/per_diem_dispute_summary.dart';
import 'package:andi_carpeta/finance/per_diem_ledger.dart';
void main() {
  test('lei parsing is exact', () {
    expect(parseLeiToBani('10,05'), 1005);
    expect(parseLeiToBani('0.5'), 50);
    expect(() => parseLeiToBani('1.999'), throwsFormatException);
    expect(formatBani(-150), '-1,50 lei');
  });
  test('separate debt and advance per distributor', () {
    final t = DateTime.utc(2026,10,10);
    final entries = [
      PerDiemLedgerEntry(id:'d1', distributorId:'a',beneficiaryId:'b',
        kind:PerDiemLedgerKind.entitlement,amountBani:10000,confirmed:true,occurredAt:t),
      PerDiemLedgerEntry(id:'p1', distributorId:'a',beneficiaryId:'b',
        kind:PerDiemLedgerKind.payment,amountBani:7000,confirmed:true,occurredAt:t),
      PerDiemLedgerEntry(id:'p2', distributorId:'c',beneficiaryId:'b',
        kind:PerDiemLedgerKind.payment,amountBani:5000,confirmed:true,occurredAt:t),
    ];
    final balances = reconcilePairs(entries);
    expect(balances.length,2);
    expect(balances.first.outstandingBani,3000);
    expect(balances.last.advanceBani,5000);
  });
  test('payment intent validates parties', () {
    final p = PaymentIntent(id:'x',distributorId:'a',beneficiaryId:'a',
      declaredBani:100,createdAt:DateTime.utc(2026));
    expect(p.validate, throwsArgumentError);
  });
  test('dispute never changes confirmed received amount', () {
    final d = DisputeSummary('x',10000,7000,'Suma diferă');
    expect(d.isValid,isTrue);
    expect(d.disputedDifferenceBani,3000);
  });
}
