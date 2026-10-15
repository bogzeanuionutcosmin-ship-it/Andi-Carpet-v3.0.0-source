import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

enum FinanceIntentKind { create, edit, close, receipt }
enum FinanceIntentStatus { confirmed, rejectedBeforeWrite, uncertain, conflict }

// Deep immutable request, created once BEFORE persistence/network submission.
// DateTime survives restart as a tagged value; no model/list references escape.
Object? freezeFinanceValue(Object? value) {
  if (value == null || value is String || value is bool || value is DateTime) return value;
  if (value is num) {
    if (!value.isFinite) throw const FormatException('finance_nonfinite');
    return value;
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(freezeFinanceValue));
  if (value is Map<String, Object?>) return Map<String, Object?>.unmodifiable(
    value.map((key, value) => MapEntry(key, freezeFinanceValue(value))));
  throw const FormatException('finance_unsupported_value');
}
Object? _jsonValue(Object? value) {
  if (value is DateTime) return {'@date': value.toUtc().toIso8601String()};
  if (value is List) return value.map(_jsonValue).toList();
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _jsonValue(value[key])};
  }
  return value;
}
Object? _fromJson(Object? value) {
  if (value is Map<String, dynamic>) {
    if (value.length == 1 && value['@date'] is String) return DateTime.parse(value['@date'] as String).toUtc();
    return value.map((key, value) => MapEntry(key, _fromJson(value)));
  }
  if (value is List) return value.map(_fromJson).toList();
  return value;
}
String canonicalFinanceJson(Object? value) => jsonEncode(_jsonValue(value));
bool sameFinanceValue(Object? a, Object? b) => canonicalFinanceJson(a) == canonicalFinanceJson(b);

class FinanceIntent {
  final String operationId, actorUid, teamId, collection, documentId;
  final int baseRevision;
  final FinanceIntentKind kind;
  final Map<String, Object?> changes;
  FinanceIntent({required this.operationId, required this.actorUid, required this.teamId,
    required this.collection, required this.documentId, required this.baseRevision,
    required this.kind, required Map<String, Object?> changes})
      : changes = freezeFinanceValue(changes) as Map<String, Object?> {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(operationId)) throw const FormatException('finance_invalid_operation_id');
    for (final id in [actorUid, teamId, documentId]) {
      if (id.isEmpty || id.length > 128 || id.contains('/')) throw const FormatException('finance_invalid_binding');
    }
    if (!['settlements', 'finance'].contains(collection) || baseRevision < 0 || baseRevision > 9007199254740990) {
      throw const FormatException('finance_invalid_target_revision');
    }
    if (collection == 'finance' && documentId != teamId) throw const FormatException('finance_invalid_legacy_target');
    if (collection == 'finance' && kind != FinanceIntentKind.receipt) throw const FormatException('finance_legacy_kind_unsupported');
    // A bounded local envelope is a storage guard, never rounding/capping money.
    if (utf8.encode(encode()).length > 16384) throw const FormatException('finance_intent_too_large');
  }
  static String newOperationId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
  String get targetPath => '$collection/$documentId';
  String get markerPath => '$targetPath/financialIntents/$operationId';
  Map<String, Object?> toMap() => {'version': 1, 'operationId': operationId,
    'actorUid': actorUid, 'teamId': teamId, 'collection': collection,
    'documentId': documentId, 'baseRevision': baseRevision, 'kind': kind.name, 'changes': changes};
  String encode() => canonicalFinanceJson(toMap());
  String get digest => sha256.convert(utf8.encode(encode())).toString();
  factory FinanceIntent.decode(String encoded) {
    final raw = _fromJson(jsonDecode(encoded)) as Map<String, Object?>;
    if (raw['version'] != 1 || raw.length != 9) throw const FormatException('finance_intent_version');
    return FinanceIntent(operationId: raw['operationId'] as String, actorUid: raw['actorUid'] as String,
      teamId: raw['teamId'] as String, collection: raw['collection'] as String,
      documentId: raw['documentId'] as String, baseRevision: raw['baseRevision'] as int,
      kind: FinanceIntentKind.values.byName(raw['kind'] as String), changes: raw['changes'] as Map<String, Object?>);
  }
  // Deliberately excludes IDs, money and payload from accidental interpolation.
  @override String toString() => 'FinanceIntent(${kind.name})';
}

class FinanceIntentResult {
  final FinanceIntentStatus status;
  final int? revision;
  final bool replayed;
  final String code;
  const FinanceIntentResult(this.status, this.code, {this.revision, this.replayed = false});
  @override String toString() => 'FinanceIntentResult(${status.name}, $code)';
}
