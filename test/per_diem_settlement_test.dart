import 'package:flutter_test/flutter_test.dart';
import '../lib/finance/per_diem_settlement.dart';

void main() {
  const original = Settlement(id: 's1', distributorId: 'd', beneficiaryId: 'b', declaredBani: 10000);
  test('Beneficiarul poate confirma o plată parțială', () {
    final s = original.acknowledge(actorId: 'b', received: 7000);
    expect(s.status, SettlementStatus.partiallyReceived);
    expect(s.toConfirmedPayment(DateTime(2026))!.amountBani, 7000);
  });
  test('Refuzul nu creează încasare', () {
    final s = original.acknowledge(actorId: 'b', received: 0);
    expect(s.status, SettlementStatus.refused);
    expect(s.toConfirmedPayment(DateTime(2026)), isNull);
  });
  test('Refuzul poate fi urmat de confirmare', () {
    final s = original.acknowledge(actorId: 'b', received: 0)
      .acknowledge(actorId: 'b', received: 10000);
    expect(s.status, SettlementStatus.received);
  });
  test('Distribuitorul poate contesta diferența motivat', () {
    final s = original.acknowledge(actorId: 'b', received: 7000)
      .dispute(actorId: 'd', reason: 'Am predat integral');
    expect(s.status, SettlementStatus.disputed);
  });
  test('Nu permite confirmarea de către alt utilizator', () {
    expect(() => original.acknowledge(actorId: 'd', received: 10000), throwsStateError);
  });
  test('Nu permite confirmarea repetată', () {
    final s = original.acknowledge(actorId: 'b', received: 10000);
    expect(() => s.acknowledge(actorId: 'b', received: 10000), throwsStateError);
  });
  test('Nu permite sume negative', () {
    expect(() => original.acknowledge(actorId: 'b', received: -1), throwsRangeError);
  });
}
