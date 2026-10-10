import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/per_diem_payment_plan.dart';

void main() {
  test('55 restanță reportată + diurnă nouă', () {
    final p = PerDiemPaymentPlan(dueBani: 10000, confirmedPaidBani: 7000, pendingBani: 0, newEntitlementBani: 5000, proposedPaymentBani: 0);
    expect(p.recommendedPaymentBani, 8000);
  });
  test('56 avans compensează automat dreptul nou', () {
    final p = PerDiemPaymentPlan(dueBani: 10000, confirmedPaidBani: 15000, pendingBani: 0, newEntitlementBani: 5000, proposedPaymentBani: 0);
    expect(p.recommendedPaymentBani, 0);
    expect(p.expectedAdvanceBani, 0);
  });
  test('57 avans parțial acoperă dreptul nou', () {
    final p = PerDiemPaymentPlan(dueBani: 10000, confirmedPaidBani: 13000, pendingBani: 0, newEntitlementBani: 5000, proposedPaymentBani: 0);
    expect(p.recommendedPaymentBani, 2000);
  });
  test('58 promisiunile neconfirmate nu sunt încasări', () {
    final p = PerDiemPaymentPlan(dueBani: 10000, confirmedPaidBani: 0, pendingBani: 10000, newEntitlementBani: 0, proposedPaymentBani: 0);
    expect(p.currentOutstandingBani, 10000);
  });
  test('59 plată parțială propusă ar lăsa restanță', () {
    final p = PerDiemPaymentPlan(dueBani: 10000, confirmedPaidBani: 0, pendingBani: 0, newEntitlementBani: 0, proposedPaymentBani: 7000);
    expect(p.expectedOutstandingBani, 3000);
    expect(p.currentOutstandingBani, 10000);
  });
  test('60 supraplată propusă ar produce avans doar după confirmare', () {
    final p = PerDiemPaymentPlan(dueBani: 10000, confirmedPaidBani: 0, pendingBani: 0, newEntitlementBani: 0, proposedPaymentBani: 15000);
    expect(p.expectedAdvanceBani, 5000);
    expect(p.currentAdvanceBani, 0);
  });
  test('61 refuzul zero nu modifică soldul', () {
    final p = PerDiemPaymentPlan(dueBani: 10000, confirmedPaidBani: 0, pendingBani: 0, newEntitlementBani: 0, proposedPaymentBani: 0);
    expect(p.expectedOutstandingBani, 10000);
  });
  test('62 valori negative respinse', () {
    final p = PerDiemPaymentPlan(dueBani: -1, confirmedPaidBani: 0, pendingBani: 0, newEntitlementBani: 0, proposedPaymentBani: 0);
    expect(() => p.recommendedPaymentBani, throwsArgumentError);
  });
}
