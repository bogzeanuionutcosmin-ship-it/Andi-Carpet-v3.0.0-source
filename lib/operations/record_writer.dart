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

/// Existing records are updates, never upserts. Retrying the same ID and
/// payload after a lost response is harmless. Distinct IDs remain distinct
/// legitimate attempts; this is not a cross-device START reservation protocol.
Future<void> saveRecordCompared(FirebaseFirestore db, String id,
    Map<String, dynamic> desired, {Map<String, dynamic>? expected}) async {
  final ref = db.collection('records').doc(id);
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
      if (current != null && recordPayloadMatches(current, desired)) return;
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
    });
  } on FirebaseException catch (error, stackTrace) {
    // The Android Firestore bridge can surface a transaction conflict as a
    // platform FirebaseException instead of the StateError thrown in the
    // transaction callback. Resolve that ambiguity from server state only.
    try {
      final observed = await ref.get(const GetOptions(source: Source.server));
      final current = observed.data();
      if (current != null && recordPayloadMatches(current, desired)) return;
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
      !confirmed.exists || !recordPayloadMatches(confirmed.data()!, desired)) {
    throw StateError('Salvarea nu a putut fi confirmată. Reîncarcă înainte de retry.');
  }
}
