/// Pure financial ledger. Amounts are integer bani.
enum PerDiemLedgerKind { entitlement, payment, reversal }

class PerDiemLedgerEntry {
  final String id;
  final String distributorId;
  final String beneficiaryId;
  final PerDiemLedgerKind kind;
  final int amountBani;
  final bool confirmed;
  final String? reversesId;
  final DateTime occurredAt;

  const PerDiemLedgerEntry({
    required this.id,
    required this.distributorId,
    required this.beneficiaryId,
    required this.kind,
    required this.amountBani,
    required this.confirmed,
    required this.occurredAt,
    this.reversesId,
  });
}

class PerDiemBalance {
  final int dueBani;
  final int paidBani;
  final int pendingPaymentBani;
  const PerDiemBalance(this.dueBani, this.paidBani, this.pendingPaymentBani);
  int get netBani => dueBani - paidBani;
  int get outstandingBani => netBani > 0 ? netBani : 0;
  int get advanceBani => netBani < 0 ? -netBani : 0;
}

/// Pending and confirmed payment must share the same entry ID.
/// Persistence must update that document atomically (not append another ID).
void _validateEntries(List<PerDiemLedgerEntry> entries) {
  final byId = <String, PerDiemLedgerEntry>{};
  for (final e in entries) {
    if (e.id.trim().isEmpty || e.distributorId.trim().isEmpty ||
        e.beneficiaryId.trim().isEmpty || e.distributorId == e.beneficiaryId) {
      throw StateError('Identificator/pereche invalidă: ${e.id}');
    }
    if (e.amountBani <= 0 || e.amountBani > 100000000) {
      throw StateError('Sumă invalidă: ${e.id}');
    }
    if (!byId.containsKey(e.id)) {
      byId[e.id] = e;
    } else {
      throw StateError('ID duplicat: ${e.id}');
    }
    if (e.kind == PerDiemLedgerKind.reversal) {
      if (e.reversesId == null || e.reversesId!.trim().isEmpty) {
        throw StateError('Corecție fără referință: ${e.id}');
      }
    } else if (e.reversesId != null) {
      throw StateError('Referință de corecție nepermisă: ${e.id}');
    }
  }
  final reversed = <String>{};
  for (final e in entries.where((e) => e.kind == PerDiemLedgerKind.reversal)) {
    final original = byId[e.reversesId];
    if (original == null || original.kind == PerDiemLedgerKind.reversal ||
        original.distributorId != e.distributorId ||
        original.beneficiaryId != e.beneficiaryId ||
        original.amountBani != e.amountBani ||
        e.occurredAt.isBefore(original.occurredAt)) {
      throw StateError('Corecție invalidă: ${e.id}');
    }
    if (e.confirmed && (!original.confirmed || !reversed.add(original.id))) {
      throw StateError('Corecție confirmată invalidă: ${e.id}');
    }
  }
}

PerDiemBalance _calculateValidated(
  List<PerDiemLedgerEntry> entries,
  String distributorId,
  String beneficiaryId,
) {
  final pair = entries.where((e) =>
      e.distributorId == distributorId && e.beneficiaryId == beneficiaryId).toList();
  final reversed = pair.where((e) =>
      e.kind == PerDiemLedgerKind.reversal && e.confirmed)
      .map((e) => e.reversesId!).toSet();
  var due = 0, paid = 0, pending = 0;
  for (final e in pair) {
    if (e.kind == PerDiemLedgerKind.reversal || reversed.contains(e.id)) continue;
    if (e.kind == PerDiemLedgerKind.entitlement) {
      if (e.confirmed) due += e.amountBani;
    } else if (e.confirmed) {
      paid += e.amountBani;
    } else {
      pending += e.amountBani;
    }
  }
  return PerDiemBalance(due, paid, pending);
}

PerDiemBalance calculatePerDiemBalance(
  Iterable<PerDiemLedgerEntry> entries, {
  required String distributorId,
  required String beneficiaryId,
}) {
  final snapshot = entries.toList(growable: false);
  _validateEntries(snapshot);
  return _calculateValidated(snapshot, distributorId, beneficiaryId);
}

Map<String, PerDiemBalance> calculateAllPerDiemBalances(
  Iterable<PerDiemLedgerEntry> entries,
) {
  final snapshot = entries.toList(growable: false);
  _validateEntries(snapshot);
  final pairs = <String, (String, String)>{};
  for (final e in snapshot) {
    final key = '${e.distributorId.length}:${e.distributorId}'
        '${e.beneficiaryId.length}:${e.beneficiaryId}';
    pairs[key] = (e.distributorId, e.beneficiaryId);
  }
  return {
    for (final p in pairs.entries)
      p.key: _calculateValidated(snapshot, p.value.$1, p.value.$2),
  };
}
