import 'package:cloud_firestore/cloud_firestore.dart';

const restoreCollections = <String>{
  'teams', 'cars', 'locations', 'locationCategories', 'functions', 'schedules',
  'records', 'expenses', 'perDiems', 'finance', 'settlements', 'documents',
  'notifications', 'audit',
};

/// Bounded, all-or-nothing restore. Larger backups fail before any write.
/// Reads are not a database-wide snapshot: use a maintenance window to avoid
/// concurrent editors creating new documents during inventory.
Future<void> restoreAtomically(FirebaseFirestore db,
    Map<String, Map<String, dynamic>> collections,
    {Map<String, dynamic>? settings, required String source}) async {
  if (collections.isEmpty && settings == null) throw const FormatException('Backup fără date restaurabile.');
  final writes = <String, Map<String, dynamic>?>{};
  for (final entry in collections.entries) {
    if (!restoreCollections.contains(entry.key)) throw const FormatException('Colecție nepermisă.');
    for (final document in entry.value.entries) {
      if (document.key.isEmpty || document.key.contains('/') || document.value is! Map) {
        throw const FormatException('Document backup invalid.');
      }
      writes['${entry.key}/${document.key}'] = Map<String, dynamic>.from(document.value as Map);
    }
    final current = await db.collection(entry.key).get(const GetOptions(source: Source.server));
    for (final doc in current.docs) {
      writes.putIfAbsent('${entry.key}/${doc.id}', () => null);
    }
  }
  if (settings != null) writes['meta/uiSettings'] = settings;
  writes['meta/backup'] = {'lastRestoreAt': FieldValue.serverTimestamp(), 'restoredSource': source};
  if (writes.length > 400) throw StateError('Backup prea mare pentru restaurare atomică (maxim 400 scrieri). Nu s-au modificat date.');
  final batch = db.batch();
  for (final entry in writes.entries) {
    final ref = db.doc(entry.key);
    if (entry.value == null) {
      batch.delete(ref);
    } else if (entry.key == 'meta/backup') {
      batch.set(ref, entry.value!, SetOptions(merge: true));
    } else {
      batch.set(ref, entry.value!);
    }
  }
  await batch.commit();
}
