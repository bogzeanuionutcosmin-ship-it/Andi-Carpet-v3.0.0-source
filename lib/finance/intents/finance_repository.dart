import 'finance_intent.dart';

abstract interface class FinanceTransaction {
  Future<Map<String, Object?>?> read(String path);
  void write(String path, Map<String, Object?> value);
}
class FinanceServerObservation {
  final Map<String, Object?>? data;
  final bool fromCache, pendingWrites;
  const FinanceServerObservation(this.data, {required this.fromCache, required this.pendingWrites});
}
abstract interface class FinanceAtomicPort {
  Future<T> atomic<T>(Future<T> Function(FinanceTransaction tx) action);
  Future<FinanceServerObservation> readServer(String path);
}
class FinanceRefusal implements Exception {
  final String code;
  const FinanceRefusal(this.code);
  @override String toString() => code;
}
class FinanceRevisionConflict implements Exception {
  const FinanceRevisionConflict();
}
Map<String, Object?> _map(Object? value) => Map<String, Object?>.from(value as Map);
double _number(Object? value) {
  if (value is! num || !value.isFinite || value < 0) throw const FinanceRefusal('finance_invalid_history');
  return value.toDouble();
}
void _keys(Map<String, Object?> changes, Set<String> allowed, {Set<String> required = const {}}) {
  if (changes.isEmpty || changes.keys.any((key) => !allowed.contains(key)) ||
      !changes.keys.toSet().containsAll(required)) throw const FinanceRefusal('finance_invalid_changes');
}

// Pure transition: never mutates the loaded snapshot or user-owned models.
Map<String, Object?> applyFinanceIntent(FinanceIntent intent, Map<String, Object?>? previous) {
  final data = previous == null ? <String, Object?>{} : _map(freezeFinanceValue(previous));
  final revision = previous?['revision'] ?? 0;
  if (revision is! int || revision != intent.baseRevision) throw const FinanceRevisionConflict();
  if (intent.kind == FinanceIntentKind.create) {
    if (previous != null) throw const FinanceRevisionConflict();
    _keys(intent.changes, {'name','startDate','endDate','managerId','perDiemRate','createdAt'}, required: {'name','startDate','managerId','perDiemRate','createdAt'});
    if (intent.changes['managerId'] is! String || intent.changes['createdAt'] is! DateTime) throw const FinanceRefusal('finance_invalid_creation');
    _number(intent.changes['perDiemRate']);
    data.addAll(intent.changes);
    data.addAll({'teamId':intent.teamId,'closed':false,'receivedEntries':<Object?>[],
      'receivedDeparture':0.0,'receivedDuring':0.0,
      'receivedOpeningDeparture':0.0,'receivedOpeningDuring':0.0});
  } else {
    if (previous == null || previous['teamId'] != intent.teamId) throw const FinanceRefusal('finance_missing_or_wrong_team');
    switch (intent.kind) {
      case FinanceIntentKind.receipt:
        if (data['closed'] == true) throw const FinanceRefusal('finance_closed');
        _keys(intent.changes, {'kind','amount','method','fromName','date'}, required: {'kind','amount','method','fromName','date'});
        final amount = _number(intent.changes['amount']);
        if (amount <= 0 || !['departure','during'].contains(intent.changes['kind']) ||
            !['Cash','Transfer'].contains(intent.changes['method']) ||
            intent.changes['fromName'] is! String || (intent.changes['fromName'] as String).trim().isEmpty ||
            intent.changes['date'] is! DateTime) throw const FinanceRefusal('finance_invalid_receipt');
        final entries = (data['receivedEntries'] as List? ?? []).map(_map).toList();
        var sumDeparture = 0.0, sumDuring = 0.0;
        for (final entry in entries) {
          if (entry['id'] == intent.operationId) throw const FinanceRefusal('finance_marker_missing_for_existing_entry');
          if (!['departure','during'].contains(entry['kind'])) throw const FinanceRefusal('finance_invalid_history');
          if (entry['kind'] == 'departure') { sumDeparture += _number(entry['amount']); }
          else { sumDuring += _number(entry['amount']); }
        }
        final oldDeparture = _number(data['receivedDeparture'] ?? 0);
        final oldDuring = _number(data['receivedDuring'] ?? 0);
        final openingDeparture = _number(data['receivedOpeningDeparture'] ?? (entries.isEmpty ? oldDeparture : 0));
        final openingDuring = _number(data['receivedOpeningDuring'] ?? (entries.isEmpty ? oldDuring : 0));
        // Do not silently repair historical disagreements or invent transfers.
        if ((sumDeparture + openingDeparture - oldDeparture).abs() > 0.0000001 ||
            (sumDuring + openingDuring - oldDuring).abs() > 0.0000001) throw const FinanceRefusal('finance_history_requires_review');
        final departure = oldDeparture + (intent.changes['kind'] == 'departure' ? amount : 0);
        final during = oldDuring + (intent.changes['kind'] == 'during' ? amount : 0);
        if (!departure.isFinite || !during.isFinite) throw const FinanceRefusal('finance_aggregate_overflow');
        if ((intent.changes['kind'] == 'departure' ? departure <= oldDeparture : during <= oldDuring)) {
          throw const FinanceRefusal('finance_increment_lost_to_precision');
        }
        entries.add({'id':intent.operationId,...intent.changes});
        data.addAll({'receivedEntries':entries,'receivedDeparture':departure,'receivedDuring':during,
          'receivedOpeningDeparture':openingDeparture,'receivedOpeningDuring':openingDuring});
      case FinanceIntentKind.edit:
        _keys(intent.changes, {'name','startDate','endDate'});
        data.addAll(intent.changes);
      case FinanceIntentKind.close:
        _keys(intent.changes, {'closed','endDate'}, required: {'closed','endDate'});
        if (intent.changes['closed'] is! bool) throw const FinanceRefusal('finance_invalid_close');
        data.addAll(intent.changes);
      case FinanceIntentKind.create:
        throw const FinanceRefusal('finance_invalid_kind');
    }
  }
  if (data.containsKey('name') && (data['name'] is! String || (data['name'] as String).trim().isEmpty)) throw const FinanceRefusal('finance_invalid_name');
  for (final field in ['startDate','endDate']) {
    if (data[field] != null && data[field] is! DateTime && data[field] is! FinanceTimestamp) throw const FinanceRefusal('finance_invalid_date');
  }
  data.addAll({'revision':intent.baseRevision+1,'lastOperationId':intent.operationId});
  return data;
}

class FinanceRepository {
  final FinanceAtomicPort port;
  final String ownerUid;
  final bool Function() sessionIsCurrent;
  FinanceRepository({required this.port, required this.ownerUid, required this.sessionIsCurrent});
  bool _owns(FinanceIntent intent) => sessionIsCurrent() && intent.actorUid == ownerUid;
  bool _matches(FinanceIntent intent, Map<String, Object?> marker) =>
    marker['operationId'] == intent.operationId && marker['actorUid'] == intent.actorUid &&
    marker['teamId'] == intent.teamId && marker['targetPath'] == intent.targetPath &&
    marker['baseRevision'] == intent.baseRevision && marker['revision'] == intent.baseRevision+1 &&
    marker['kind'] == intent.kind.name && marker['digest'] == intent.digest;

  Future<FinanceIntentResult> execute(FinanceIntent intent) async {
    if (!_owns(intent)) return const FinanceIntentResult(FinanceIntentStatus.rejectedBeforeWrite,'finance_session_expired');
    try {
      final result = await port.atomic((tx) async {
        if (!_owns(intent)) throw const FinanceRefusal('finance_session_expired');
        final marker = await tx.read(intent.markerPath);
        if (!_owns(intent)) throw const FinanceRefusal('finance_session_expired');
        if (marker != null) {
          if (!_matches(intent, marker)) throw const FinanceRevisionConflict();
          return FinanceIntentResult(FinanceIntentStatus.confirmed,'finance_confirmed',revision: intent.baseRevision+1,replayed:true);
        }
        final previous = await tx.read(intent.targetPath);
        if (!_owns(intent)) throw const FinanceRefusal('finance_session_expired');
        final next = applyFinanceIntent(intent, previous);
        if (!_owns(intent)) throw const FinanceRefusal('finance_session_expired');
        tx.write(intent.targetPath, next);
        tx.write(intent.markerPath, {'operationId':intent.operationId,'actorUid':intent.actorUid,
          'teamId':intent.teamId,'targetPath':intent.targetPath,'baseRevision':intent.baseRevision,
          'revision':intent.baseRevision+1,'kind':intent.kind.name,'digest':intent.digest});
        return FinanceIntentResult(FinanceIntentStatus.confirmed,'finance_confirmed',revision:intent.baseRevision+1);
      });
      if (!_owns(intent)) return const FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_session_expired');
      return result;
    } on FinanceRevisionConflict {
      return const FinanceIntentResult(FinanceIntentStatus.conflict,'finance_revision_conflict');
    } on FinanceRefusal catch (failure) {
      return FinanceIntentResult(FinanceIntentStatus.rejectedBeforeWrite,failure.code);
    } catch (_) {
      // SDK errors do not prove absence of a committed write. Never retry here.
      return const FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_result_uncertain');
    }
  }
  Future<FinanceIntentResult> reconcile(FinanceIntent intent) async {
    if (!_owns(intent)) return const FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_session_expired');
    try {
      final observation = await port.readServer(intent.markerPath);
      if (!_owns(intent) || observation.fromCache || observation.pendingWrites || observation.data == null) {
        return const FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_result_uncertain');
      }
      if (!_matches(intent, observation.data!)) return const FinanceIntentResult(FinanceIntentStatus.conflict,'finance_evidence_mismatch');
      return FinanceIntentResult(FinanceIntentStatus.confirmed,'finance_confirmed',revision:intent.baseRevision+1,replayed:true);
    } catch (_) {
      return const FinanceIntentResult(FinanceIntentStatus.uncertain,'finance_result_uncertain');
    }
  }
}
