import 'per_diem_ledger.dart';

/// PATCH 21–23: adapts old per-diem records for READ-ONLY reconciliation.
/// It does not write/migrate documents. Do not count these alongside the
/// equivalent v2 settlement entries: use [sourceId] for deduplication.
class LegacyPerDiemSnapshot {
  final String id, beneficiaryId;
  final String? distributorId;
  final int declaredBani;
  final int? receivedBani;
  final String status;
  final DateTime date;
  const LegacyPerDiemSnapshot({required this.id, required this.beneficiaryId,
    required this.distributorId, required this.declaredBani,
    required this.receivedBani, required this.status, required this.date});
}

class LegacyReconciliation {
  final List<PerDiemLedgerEntry> entries;
  final List<String> warnings;
  const LegacyReconciliation(this.entries, this.warnings);
}

/// Do not infer receipt from `confirmed` unless an actual amount is recorded
/// or the legacy record explicitly confirms full receipt. `awaitingConfirmation`
/// is NEVER treated as cash received.
LegacyReconciliation reconcileLegacyPerDiems(
  Iterable<LegacyPerDiemSnapshot> records, {
  Set<String> alreadyMigratedIds = const {},
}) {
  final entries = <PerDiemLedgerEntry>[];
  final warnings = <String>[];
  final seen = <String>{};
  for (final r in records) {
    if (!seen.add(r.id)) { warnings.add('${r.id}: duplicate legacy id'); continue; }
    if (alreadyMigratedIds.contains(r.id)) continue;
    if (r.id.isEmpty || r.beneficiaryId.isEmpty || r.distributorId == null ||
        r.distributorId!.isEmpty || r.distributorId == r.beneficiaryId ||
        r.declaredBani <= 0 || (r.receivedBani != null && r.receivedBani! < 0)) {
      warnings.add('${r.id}: invalid or incomplete legacy record'); continue;
    }
    final distributor = r.distributorId!;
    // Legacy distribution is not proof of entitlement; due amounts must be
    // supplied separately by the actual per-diem entitlement calculation.
    if (r.status == 'awaitingConfirmation') {
      entries.add(PerDiemLedgerEntry(id: 'legacy-pending:${r.id}',
        distributorId: distributor, beneficiaryId: r.beneficiaryId,
        kind: PerDiemLedgerKind.payment, amountBani: r.declaredBani,
        confirmed: false, occurredAt: r.date));
    } else if (r.status == 'confirmed') {
      if (r.receivedBani == null) {
        warnings.add('${r.id}: confirmed without verifiable received amount');
        continue;
      }
      if (r.receivedBani! > 0) {
        entries.add(PerDiemLedgerEntry(id: 'legacy-paid:${r.id}',
          distributorId: distributor, beneficiaryId: r.beneficiaryId,
          kind: PerDiemLedgerKind.payment, amountBani: r.receivedBani!,
          confirmed: true, occurredAt: r.date));
      }
    } else if (r.status == 'notGranted') {
      continue;
    } else {
      warnings.add('${r.id}: unknown status ${r.status}');
    }
  }
  return LegacyReconciliation(List.unmodifiable(entries), List.unmodifiable(warnings));
}
