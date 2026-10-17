import 'package:cloud_firestore/cloud_firestore.dart';

/// Compares the fields a Centralizator correction edits or relies on.
///
/// Some older records predate the optional facade fields. Their absent values
/// have the same meaning as the model defaults (`false`). Missing nullable
/// timestamps are equivalent to null. Everything else must match exactly so a
/// stale editor cannot overwrite a newer correction.
bool centralizerCorrectionSnapshotMatches(
  Map<String, dynamic> current,
  Map<String, Object?> expected,
) {
  const missingDefaults = <String, Object?>{
    'startedAt': null,
    'finishedAt': null,
    'facadeDone': false,
    'facadePlanned': false,
  };

  for (final entry in expected.entries) {
    final actual = current.containsKey(entry.key)
        ? current[entry.key]
        : missingDefaults.containsKey(entry.key)
            ? missingDefaults[entry.key]
            : _missing;
    if (actual == _missing ||
        _canonicalValue(actual) != _canonicalValue(entry.value)) {
      return false;
    }
  }
  return true;
}

const _missing = Object();

Object? _canonicalValue(Object? value) {
  if (value is Timestamp) return value.microsecondsSinceEpoch;
  if (value is DateTime) return value.toUtc().microsecondsSinceEpoch;
  return value;
}
