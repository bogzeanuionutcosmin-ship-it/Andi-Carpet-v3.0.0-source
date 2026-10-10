/// Calcul financiar pentru diurne, independent de interfață și Firebase.
/// Toate sumele sunt exprimate în bani (int) pentru a evita erorile double.
/// O tranzacție confirmată este contabilizată o singură dată, după id.
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
  /// Pozitiv: distribuitorul datorează; negativ: avans al beneficiarului.
  int get netBani => dueBani - paidBani;
  int get outstandingBani => netBani > 0 ? netBani : 0;
  int get advanceBani => netBani < 0 ? -netBani : 0;
}

PerDiemBalance calculatePerDiemBalance(
  Iterable<PerDiemLedgerEntry> entries, {
  required String distributorId,
  required String beneficiaryId,
}) {
  final seen = <String>{};
  final filtered = <PerDiemLedgerEntry>[];
  for (final e in entries) {
    if (e.distributorId != distributorId ||
        e.beneficiaryId != beneficiaryId) continue;
    if (e.amountBani <= 0) throw StateError('Sumă invalidă: ${e.id}');
    if (!seen.add(e.id)) throw StateError('ID duplicat: ${e.id}');
    filtered.add(e);
  }
  final originals = {for (final e in filtered) e.id: e};
  final reversed = <String>{};
  for (final e in filtered.where((e) => e.kind == PerDiemLedgerKind.reversal && e.confirmed)) {
    final original = originals[e.reversesId];
    if (original == null || original.kind == PerDiemLedgerKind.reversal ||
        !original.confirmed || original.amountBani != e.amountBani ||
        !reversed.add(original.id)) {
      throw StateError('Corecție invalidă: ${e.id}');
    }
  }
  var due = 0, paid = 0, pending = 0;
  for (final e in filtered) {
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

/// Rezumat pentru toate perechile, inclusiv cele fără sold net.
/// Nu amestecă soldurile dintre distribuitori diferiți.
Map<String, PerDiemBalance> calculateAllPerDiemBalances(
  Iterable<PerDiemLedgerEntry> entries,
) {
  final snapshot = entries.toList(growable: false);
  final pairs = <String, (String, String)>{};
  for (final entry in snapshot) {
    if (entry.distributorId.isEmpty || entry.beneficiaryId.isEmpty ||
        entry.distributorId == entry.beneficiaryId) {
      throw StateError('Pereche financiară invalidă: ${entry.id}');
    }
    // Cheie fără coliziuni pentru ID-uri ce conțin separatori.
    final key = '${entry.distributorId.length}:${entry.distributorId}'
        '${entry.beneficiaryId.length}:${entry.beneficiaryId}';
    pairs[key] = (entry.distributorId, entry.beneficiaryId);
  }
  return {
    for (final pair in pairs.entries)
      pair.key: calculatePerDiemBalance(
        snapshot,
        distributorId: pair.value.$1,
        beneficiaryId: pair.value.$2,
      ),
  };
}
