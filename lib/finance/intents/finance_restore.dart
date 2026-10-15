import 'dart:convert';
import 'finance_intent.dart';
import 'finance_repository.dart';

Map<String,Object?> _freezeManifest(Map<String,Object?> value) {
  Object? normalize(Object? item) {
    if(item is Map) {
      if(item.keys.any((key)=>key is! String))throw const FormatException();
      return <String,Object?>{for(final entry in item.entries) entry.key as String:normalize(entry.value)};
    }
    if(item is List)return item.map(normalize).toList();
    return item;
  }
  try {
    return freezeFinanceValue(normalize(value)) as Map<String,Object?>;
  } on FormatException {
    throw const FinanceRefusal('finance_restore_invalid_manifest');
  }
}

// Bounded, targeted DEMO restore, not collection replacement or migration.
// Financial targets and immutable evidence are guards ONLY, never writes.
class FinanceRestorePlan {
  static const maxDocuments = 20, maxBytes = 256 * 1024;
  final Map<String,Object?> expected, replacements;
  FinanceRestorePlan({required Map<String,Object?> expected,
    required Map<String,Object?> replacements})
    : expected = _freezeManifest(expected),
      replacements = _freezeManifest(replacements) {
    if (expected.isEmpty || expected.length > maxDocuments || replacements.isEmpty ||
        !expected.keys.toSet().containsAll(replacements.keys) ||
        !expected.keys.any(_financialPath)) {
      throw const FinanceRefusal('finance_restore_invalid_manifest');
    }
    for (final entry in this.expected.entries) {
      if ((!_financialPath(entry.key) && !_operationalPath(entry.key)) ||
          (entry.value != null && entry.value is! Map<String,Object?>)) {
        throw const FinanceRefusal('finance_restore_invalid_manifest');
      }
    }
    for (final entry in this.replacements.entries) {
      if (!_operationalPath(entry.key) || entry.value is! Map<String,Object?>) {
        throw const FinanceRefusal('finance_restore_financial_write_forbidden');
      }
    }
    final targets=this.expected.entries.where((entry)=>_financialPath(entry.key) &&
      !entry.key.contains('/financialIntents/'));
    if(targets.isEmpty)throw const FinanceRefusal('finance_restore_missing_target');
    for(final target in targets) {
      if(target.value is! Map<String,Object?>)throw const FinanceRefusal('finance_restore_missing_target');
      final data=target.value as Map<String,Object?>,revision=data['revision']??0;
      if(revision is! int || revision<0)throw const FinanceRefusal('finance_restore_invalid_revision');
      if(revision>0) {
        final id=data['lastOperationId'];
        final marker=this.expected['${target.key}/financialIntents/$id'];
        if(id is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
            marker is! Map<String,Object?> || marker['revision']!=revision || marker['operationId']!=id) {
          throw const FinanceRefusal('finance_restore_missing_evidence');
        }
      }
    }
    for(final path in this.expected.keys.where((path)=>path.contains('/financialIntents/'))) {
      if(!this.expected.containsKey(path.split('/financialIntents/').first)) {
        throw const FinanceRefusal('finance_restore_missing_target');
      }
    }
    if (utf8.encode(encode()).length > maxBytes) {
      throw const FinanceRefusal('finance_restore_capacity');
    }
  }
  static bool _financialPath(String path) => RegExp(
    r'^(finance|settlements)/[^/]{1,128}(/financialIntents/[a-f0-9]{32})?$').hasMatch(path);
  static bool _operationalPath(String path) => RegExp(
    r'^(locations|cars|documents)/[^/]{1,128}$').hasMatch(path);
  String encode() => canonicalFinanceJson({
    'format':'AndiFinanceTargetedRestoreDemoV1',
    'expected':expected,'replacements':replacements,
  });
  factory FinanceRestorePlan.decode(String encoded) {
    if (utf8.encode(encoded).length > maxBytes) {
      throw const FinanceRefusal('finance_restore_capacity');
    }
    final raw = decodeCanonicalFinanceJson(encoded);
    if (raw is! Map<String,Object?> || raw.length != 3 ||
        raw['format'] != 'AndiFinanceTargetedRestoreDemoV1' ||
        raw['expected'] is! Map<String,Object?> ||
        raw['replacements'] is! Map<String,Object?>) {
      throw const FinanceRefusal('finance_restore_invalid_manifest');
    }
    return FinanceRestorePlan(expected:raw['expected'] as Map<String,Object?>,
      replacements:raw['replacements'] as Map<String,Object?>);
  }
}

abstract interface class FinanceRestoreTransaction {
  Future<Map<String,Object?>?> read(String path);
  void write(String path, Map<String,Object?> data);
}
abstract interface class FinanceRestorePort {
  Future<void> atomic(Future<void> Function(FinanceRestoreTransaction) action);
}

class FinanceDemoRestore {
  final FinanceRestorePort port;
  final bool Function() sessionIsCurrent;
  FinanceDemoRestore({required this.port,required this.sessionIsCurrent});
  Future<FinanceIntentResult> executeExplicitly(FinanceRestorePlan plan) async {
    void guard() {
      if (!sessionIsCurrent()) throw const FinanceRefusal('finance_session_expired');
    }
    try {
      guard();
      await port.atomic((tx) async {
        guard();
        // GLOBAL preflight in the SAME transaction. No batch, deletion, audit,
        // marker write or other side effect can precede any of these checks.
        for (final entry in plan.expected.entries) {
          final current = await tx.read(entry.key);
          guard();
          if (!sameFinanceValue(current,entry.value)) {
            throw const FinanceRevisionConflict();
          }
        }
        guard();
        for (final entry in plan.replacements.entries) {
          tx.write(entry.key,entry.value as Map<String,Object?>);
        }
      });
      if (!sessionIsCurrent()) {
        return const FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_session_expired');
      }
      return const FinanceIntentResult(FinanceIntentStatus.confirmed,'finance_restore_confirmed');
    } on FinanceRevisionConflict {
      return const FinanceIntentResult(FinanceIntentStatus.conflict,'finance_restore_stale');
    } on FinanceRefusal catch (error) {
      return FinanceIntentResult(FinanceIntentStatus.rejectedBeforeWrite,error.code);
    } catch (_) {
      // No rollback/retry/financial replay after an ambiguous SDK outcome.
      return const FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_restore_uncertain');
    }
  }
}
