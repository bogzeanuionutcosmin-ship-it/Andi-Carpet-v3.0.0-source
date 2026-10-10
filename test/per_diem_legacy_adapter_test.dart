import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/per_diem_legacy_adapter.dart';
import 'package:andi_carpeta/finance/per_diem_ledger.dart';

void main() {
  final date = DateTime.utc(2026, 10, 10);
  LegacyPerDiemSnapshot record(String id, String status, int? received) =>
    LegacyPerDiemSnapshot(id: id, beneficiaryId: 'beneficiary',
      distributorId: 'distributor', declaredBani: 10000,
      receivedBani: received, status: status, date: date);

  test('pending distributions are not received money', () {
    final result = reconcileLegacyPerDiems([record('a', 'awaitingConfirmation', null)]);
    expect(result.entries.single.confirmed, false);
    final balance = calculatePerDiemBalance(result.entries,
      distributorId: 'distributor', beneficiaryId: 'beneficiary');
    expect(balance.paidBani, 0);
    expect(balance.pendingPaymentBani, 10000);
  });
  test('confirmed partial payment counts only received amount', () {
    final result = reconcileLegacyPerDiems([record('a', 'confirmed', 7000)]);
    expect(result.entries.single.amountBani, 7000);
  });
  test('missing receipt amount cannot be silently assumed', () {
    final result = reconcileLegacyPerDiems([record('a', 'confirmed', null)]);
    expect(result.entries, isEmpty);
    expect(result.warnings, isNotEmpty);
  });
  test('migrated and duplicate legacy entries are excluded', () {
    final result = reconcileLegacyPerDiems([
      record('a', 'confirmed', 10000), record('a', 'confirmed', 10000),
      record('b', 'confirmed', 5000)], alreadyMigratedIds: {'b'});
    expect(result.entries.length, 1);
    expect(result.warnings, isNotEmpty);
  });
  test('refusal records zero receipt, not a confirmed payment', () {
    final result = reconcileLegacyPerDiems([record('a', 'confirmed', 0)]);
    expect(result.entries, isEmpty);
  });
}
