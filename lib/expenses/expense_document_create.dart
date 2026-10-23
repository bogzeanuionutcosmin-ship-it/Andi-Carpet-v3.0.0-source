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
    // Confirmation may have advanced after the original creation committed but
    // before its lost acknowledgement was recovered. Retire that create intent
    // without reverting the server's confirmed state.
    if (key == 'confirmed' && incoming[key] == false && current[key] == true) continue;
    if (!_sameValue(current[key], incoming[key])) {
      throw StateError('ID-ul cheltuielii există cu un payload diferit.');
    }
  }
  return null;
}

/// Confirms an existing expense without turning create replay into an update.
/// The caller authorizes the manager and invokes this in a Firestore transaction.
/// `incoming` is the expense the manager reviewed, with confirmed=true. Changed
/// financial/identity fields fail closed; unknown server metadata is preserved
/// because only the confirmation fields are returned for transaction.update.
Map<String, dynamic>? expenseDocumentConfirmationWrite({
  required Map<String, dynamic> incoming,
  required Map<String, dynamic> current,
  required bool exists,
}) {
  if (!exists) throw StateError('Cheltuiala nu mai există; confirmarea a fost oprită.');
  if (incoming['confirmed'] != true || !incoming.containsKey('updatedAt') ||
      (current.containsKey('confirmed') && current['confirmed'] is! bool)) {
    throw StateError('Starea confirmării cheltuielii este invalidă.');
  }
  const originalFields = {
    'teamId', 'settlementId', 'category', 'description', 'amount', 'date',
    'documentType', 'documentNumber', 'supplier', 'liters', 'pricePerLiter',
    'documentImageBase64', 'imageFingerprint', 'ocrRawText', 'ocrConfidence',
  };
  if (!incoming.keys.toSet().containsAll(originalFields) ||
      !current.containsKey('teamId') || !current.containsKey('amount') ||
      !current.containsKey('date')) {
    throw StateError('Datele originale ale cheltuielii sunt incomplete.');
  }
  // These defaults match the existing Expense decoder. They allow a sparse
  // legacy document to be confirmed without writing its defaulted fields back.
  const defaults = <String, dynamic>{
    'settlementId': null, 'category': 'Alte cheltuieli', 'description': '',
    'documentType': 'fiscalReceipt', 'documentNumber': '', 'supplier': '',
    'liters': null, 'pricePerLiter': null, 'documentImageBase64': '',
    'imageFingerprint': '', 'ocrRawText': '', 'ocrConfidence': 0,
  };
  for (final key in incoming.keys.where((key) => key != 'confirmed' && key != 'updatedAt')) {
    final stored = current.containsKey(key) ? current[key] : defaults[key];
    if (!_sameValue(stored, incoming[key])) {
      throw StateError('Cheltuiala s-a modificat; recitește documentul înainte de confirmare.');
    }
  }
  if (current['confirmed'] != false) return null; // Confirmed or legacy-confirmed.
  return {'confirmed': true, 'updatedAt': incoming['updatedAt']};
}

bool _sameValue(Object? left, Object? right) {
  if (left is Timestamp) left = left.toDate();
  if (right is Timestamp) right = right.toDate();
  if (left is DateTime && right is DateTime) return left.isAtSameMomentAs(right);
  if (left is num && right is num) return left == right;
  if (left is Map && right is Map) {
    final leftMap = left;
    final rightMap = right;
    return leftMap.length == rightMap.length &&
        leftMap.keys.every((key) => rightMap.containsKey(key) && _sameValue(leftMap[key], rightMap[key]));
  }
  if (left is List && right is List) {
    final leftList = left;
    final rightList = right;
    return leftList.length == rightList.length &&
        List.generate(leftList.length, (index) => index)
            .every((index) => _sameValue(leftList[index], rightList[index]));
  }
  return left == right;
}
