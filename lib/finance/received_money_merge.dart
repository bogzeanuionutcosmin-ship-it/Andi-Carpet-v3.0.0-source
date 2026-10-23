import 'package:cloud_firestore/cloud_firestore.dart';

/// Builds the financial fields to write from an incoming client snapshot and
/// the latest server snapshot. The caller must perform this inside a Firestore
/// transaction so the snapshot read participates in conflict detection.
Map<String, dynamic> mergeReceivedMoneyDocument({required Map<String, dynamic> incoming,
    required Map<String, dynamic> current, required bool exists}) {
  final incomingRaw = incoming['receivedEntries'];
  final currentRaw = current['receivedEntries'];
  if (incomingRaw is! List || (currentRaw != null && currentRaw is! List)) {
    throw StateError('Istoricul sumelor primite este invalid; operația a fost oprită.');
  }
  final proposed = _validatedEntries(incomingRaw);
  final persisted = currentRaw is List ? _validatedEntries(currentRaw) : <Map<String, dynamic>>[];
  final hasHistory = proposed.isNotEmpty || persisted.isNotEmpty;
  final currentDeparture = (current['receivedDeparture'] as num?)?.toDouble() ?? 0.0;
  final currentDuring = (current['receivedDuring'] as num?)?.toDouble() ?? 0.0;
  if (hasHistory && persisted.isEmpty && (currentDeparture != 0 || currentDuring != 0)) {
    throw StateError('Sumele legacy fără istoric necesită reconciliere înainte de salvare.');
  }
  final byId = <String, Map<String, dynamic>>{};
  for (final entry in [...persisted, ...proposed]) {
    final id = entry['id'] as String;
    final previous = byId[id];
    if (previous != null && !_sameEntry(previous, entry)) {
      throw StateError('ID-ul sumei primite există cu date diferite; operația a fost oprită.');
    }
    byId[id] = entry;
  }
  final merged = byId.values.toList()..sort((a, b) => _date(a).compareTo(_date(b)));
  final result = Map<String, dynamic>.of(incoming);
  if (hasHistory) {
    result['receivedEntries'] = merged;
    result['receivedDeparture'] = _total(merged, 'departure');
    result['receivedDuring'] = _total(merged, 'during');
  } else if (exists) {
    // Metadata edits do not reset aggregate-only legacy balances.
    result['receivedDeparture'] = currentDeparture;
    result['receivedDuring'] = currentDuring;
  }
  return result;
}

List<Map<String, dynamic>> _validatedEntries(List raw) => raw.map((value) {
  if (value is! Map) throw StateError('Istoricul sumelor primite este invalid.');
  final entry = Map<String, dynamic>.from(value);
  final id = entry['id'];
  final kind = entry['kind'];
  final amount = entry['amount'];
  if (id is! String || id.isEmpty || !['departure', 'during'].contains(kind) || amount is! num ||
      !amount.toDouble().isFinite || amount <= 0 || entry['method'] is! String ||
      entry['fromName'] is! String || (entry['date'] is! Timestamp && entry['date'] is! DateTime)) {
    throw StateError('Istoricul sumelor primite este invalid.');
  }
  return entry;
}).toList();

DateTime _date(Map<String, dynamic> entry) => entry['date'] is Timestamp
    ? (entry['date'] as Timestamp).toDate() : entry['date'] as DateTime;

bool _sameEntry(Map<String, dynamic> a, Map<String, dynamic> b) =>
    a['id'] == b['id'] && a['kind'] == b['kind'] && a['amount'] == b['amount'] &&
    a['method'] == b['method'] && a['fromName'] == b['fromName'] &&
    _date(a).isAtSameMomentAs(_date(b));

double _total(List<Map<String, dynamic>> entries, String kind) => entries
    .where((entry) => entry['kind'] == kind)
    .fold<double>(0, (sum, entry) => sum + (entry['amount'] as num).toDouble());
