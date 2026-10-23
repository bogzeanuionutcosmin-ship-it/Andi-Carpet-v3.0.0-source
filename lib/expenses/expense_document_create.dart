import 'package:cloud_firestore/cloud_firestore.dart';

/// Decides whether a create-only Expense write is new, an exact replay, or an
/// ID collision. The caller must invoke this inside a Firestore transaction.
/// Returns null for an exact replay so it cannot update `updatedAt` or emit a
/// second learning event.
Map<String, dynamic>? expenseDocumentCreateWrite({
  required Map<String, dynamic> incoming,
  required Map<String, dynamic> current,
  required bool exists,
}) {
  if (incoming['documentImageBase64'] != '' || incoming['ocrRawText'] != '') {
    throw StateError('Fotografia și textul OCR brut nu pot fi salvate în documentul de cheltuială.');
  }
  if (!exists) return Map<String, dynamic>.of(incoming);
  if (current['documentImageBase64'] != null && current['documentImageBase64'] != '' ||
      current['ocrRawText'] != null && current['ocrRawText'] != '') {
    throw StateError('ID-ul cheltuielii există cu date private; salvarea a fost oprită.');
  }
  final incomingKeys = incoming.keys.where((key) => key != 'updatedAt').toSet();
  final currentKeys = current.keys.where((key) => key != 'updatedAt').toSet();
  if (!incomingKeys.containsAll(currentKeys) || !currentKeys.containsAll(incomingKeys)) {
    throw StateError('ID-ul cheltuielii există cu un payload diferit.');
  }
  for (final key in incomingKeys) {
    if (!_sameValue(current[key], incoming[key])) {
      throw StateError('ID-ul cheltuielii există cu un payload diferit.');
    }
  }
  return null;
}

bool _sameValue(Object? left, Object? right) {
  if (left is Timestamp) left = left.toDate();
  if (right is Timestamp) right = right.toDate();
  if (left is DateTime && right is DateTime) return left.isAtSameMomentAs(right);
  if (left is num && right is num) return left == right;
  if (left is Map && right is Map) {
    return left.length == right.length && left.keys.every((key) => right.containsKey(key) && _sameValue(left[key], right[key]));
  }
  if (left is List && right is List) {
    return left.length == right.length && List.generate(left.length, (index) => index).every((index) => _sameValue(left[index], right[index]));
  }
  return left == right;
}
