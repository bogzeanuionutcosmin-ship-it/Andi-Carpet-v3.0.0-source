import 'package:cloud_firestore/cloud_firestore.dart';

const _defaults = <String, dynamic>{
  'waitingStartedAt': null, 'waitingEndedAt': null, 'startedAt': null,
  'finishedAt': null, 'status': 'waitingAccess', 'refusalReason': null,
  'keptForLearning': true, 'facadePlanned': false, 'facadeDone': false,
  'locationNameSnapshot': '', 'addressSnapshot': '',
};

bool recordPayloadMatches(Map<String, dynamic> current, Map<String, dynamic> expected) {
  for (final key in {...expected.keys, ..._defaults.keys}) {
    if (key == 'updatedAt') continue;
    final a = current.containsKey(key) ? current[key] : _defaults[key];
    final b = expected.containsKey(key) ? expected[key] : _defaults[key];
    if (!_sameValue(a, b)) return false;
  }
  return true;
}

bool _sameValue(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((key) => b.containsKey(key) && _sameValue(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length && List.generate(a.length, (i) => i).every((i) => _sameValue(a[i], b[i]));
  }
  return a == b;
}

/// Existing records are updates, never upserts. Team-level reservation docs
/// serialize START operations from separate clients and are released atomically
/// with the transition out of the running state.
bool _isRunningRecord(Map<String, dynamic> data) =>
    data['status'] == 'running' && data['finishedAt'] == null;

bool _lockMatches(Map<String, dynamic>? data, String recordId) =>
    data != null && data['recordId'] == recordId;

Future<void> saveRecordCompared(FirebaseFirestore db, String id,
    Map<String, dynamic> desired, {Map<String, dynamic>? expected}) async {
  final ref = db.collection('records').doc(id);
  final teamId = (desired['teamId'] ?? expected?['teamId'] ?? '').toString();
  final lockRef = teamId.isEmpty ? null : db.collection('activeRecordLocks').doc(teamId);
  // A native offline transaction completion is not a server acknowledgement.
  // Fail closed before preparing a write and confirm authoritative state after it.
  final available = await ref.get(const GetOptions(source: Source.server));
  if (available.metadata.isFromCache || available.metadata.hasPendingWrites) {
    throw StateError('Există o salvare neconfirmată. Reconectează și reîncarcă înainte de retry.');
  }
  try {
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.data();
      final lockSnapshot = lockRef == null ? null : await tx.get(lockRef);
      final lock = lockSnapshot?.data();
      final wantsRunning = _isRunningRecord(desired);
      if (wantsRunning && lockRef == null) {
        throw StateError('Intervenția nu are o echipă validă pentru rezervarea START.');
      }

      // The fixed team document is the serialization point. Firestore retries
      // the losing transaction after another device claims the same team.
      if (wantsRunning && lockSnapshot?.exists == true && !_lockMatches(lock, id)) {
        throw StateError('Echipa are deja o intervenție pornită pe alt dispozitiv. Reîncarcă înainte de retry.');
      }

      final samePayload = current != null && recordPayloadMatches(current, desired);
      if (!samePayload) {
        if (expected == null) {
          if (snap.exists) throw StateError('ID ocupat. Reîncarcă înainte de salvare.');
          tx.set(ref, desired);
        } else {
          if (current == null) throw StateError('Intervenția a fost ștearsă. Reîncarcă Centralizatorul.');
          if (!recordPayloadMatches(current, expected)) {
            throw StateError('Intervenția a fost modificată pe alt dispozitiv. Reîncarcă înainte de salvare.');
          }
          tx.update(ref, desired);
        }
      }

      if (wantsRunning) {
        if (lockSnapshot?.exists != true) {
          tx.set(lockRef!, {
            'teamId': teamId,
            'recordId': id,
            'locationId': desired['locationId'],
            'startedAt': desired['startedAt'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else if (current != null && _isRunningRecord(current) &&
          _lockMatches(lock, id)) {
        tx.delete(lockRef!);
      }
    });
  } on FirebaseException catch (error, stackTrace) {
    // The Android Firestore bridge can surface a transaction conflict as a
    // platform FirebaseException instead of the StateError thrown in the
    // transaction callback. Resolve that ambiguity from server state only.
    try {
      final observed = await ref.get(const GetOptions(source: Source.server));
      // Source.server can still contain latency-compensated local writes.
      // Such a snapshot cannot confirm a commit or classify a stale baseline.
      if (observed.metadata.isFromCache || observed.metadata.hasPendingWrites) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final current = observed.data();
      if (_isRunningRecord(desired) && lockRef != null) {
        final observedLock = await lockRef.get(const GetOptions(source: Source.server));
        if (!observedLock.metadata.isFromCache && !observedLock.metadata.hasPendingWrites &&
            observedLock.exists && !_lockMatches(observedLock.data(), id)) {
          throw StateError('Echipa are deja o intervenție pornită pe alt dispozitiv. Reîncarcă înainte de retry.');
        }
      }
      if (current != null && recordPayloadMatches(current, desired)) {
        if (!_isRunningRecord(desired) || await _serverLockMatches(lockRef, id)) return;
      }
      if (expected == null && observed.exists) {
        throw StateError('ID ocupat. Reîncarcă înainte de salvare.');
      }
      if (expected != null) {
        if (current == null) {
          throw StateError('Intervenția a fost ștearsă. Reîncarcă Centralizatorul.');
        }
        if (!recordPayloadMatches(current, expected)) {
          throw StateError('Intervenția a fost modificată pe alt dispozitiv. Reîncarcă înainte de salvare.');
        }
      }
    } on StateError {
      rethrow;
    } catch (_) {
      // Preserve permission, connectivity, and other backend errors when a
      // server read cannot establish the committed state.
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
  final confirmed = await ref.get(const GetOptions(source: Source.server));
  if (confirmed.metadata.isFromCache || confirmed.metadata.hasPendingWrites ||
      !confirmed.exists || !recordPayloadMatches(confirmed.data()!, desired) ||
      (_isRunningRecord(desired) && !await _serverLockMatches(lockRef, id))) {
    throw StateError('Salvarea nu a putut fi confirmată. Reîncarcă înainte de retry.');
  }
}

Future<bool> _serverLockMatches(DocumentReference<Map<String, dynamic>>? lockRef,
    String recordId) async {
  if (lockRef == null) return false;
  final snapshot = await lockRef.get(const GetOptions(source: Source.server));
  return !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites &&
      _lockMatches(snapshot.data(), recordId);
}
