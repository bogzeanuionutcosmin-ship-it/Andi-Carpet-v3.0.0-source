part of '../main.dart';

// Automatic Firestore backup snapshots and retention management.
mixin _HomeBackupMaintenance on State<HomePage> {
  FirebaseFirestore get _maintenanceDb;
  String get currentUserId;
  AppSettings get settings;

  Future<void> _createAutomaticBackup() async {
    const collectionNames = <String>[
      'users','teams','cars','locations','locationCategories','functions',
      'schedules','records','expenses','perDiems','finance','settlements',
      'documents','notifications','audit',
    ];
    final db = _maintenanceDb;
    final now = DateTime.now();
    final backupId = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final backupRef = db.collection('backups').doc(backupId);
    final uiSettingsSnapshot=await db.collection('meta').doc('uiSettings').get();
    await backupRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUserId,
      'type': 'automatic',
      'status': 'running',
      'collections': collectionNames,
      'documentCount': 0,
      'uiSettings': uiSettingsSnapshot.data(),
    });
    var total = 0;
    try {
      WriteBatch batch = db.batch();
      var batchCount = 0;
      Future<void> flush() async {
        if (batchCount == 0) return;
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
      for (final collectionName in collectionNames) {
        final snapshot = await db.collection(collectionName).get();
        for (final doc in snapshot.docs) {
          final safeId = '${collectionName}__${doc.id}';
          batch.set(backupRef.collection('items').doc(safeId), {
            'collection': collectionName,
            'documentId': doc.id,
            'data': doc.data(),
          });
          batchCount++;
          total++;
          // Documentele cu poze pot fi mari; loturi mici evită depășirea limitei de request.
          if (batchCount >= 8) await flush();
        }
      }
      await flush();
      await backupRef.set({
        'status': 'complete',
        'completedAt': FieldValue.serverTimestamp(),
        'documentCount': total,
      }, SetOptions(merge: true));
    } catch (e) {
      await backupRef.set({
        'status': 'failed',
        'error': e.toString().length > 500 ? e.toString().substring(0, 500) : e.toString(),
        'completedAt': FieldValue.serverTimestamp(),
        'documentCount': total,
      }, SetOptions(merge: true));
      rethrow;
    }
  }

  Future<void> _pruneAutomaticBackups() async {
    final db = _maintenanceDb;
    final cutoff = DateTime.now().subtract(Duration(days: settings.backupRetentionDays.clamp(1, 365)));
    final old = await HomeRetentionQueries.fromFirestore(db).backupsBefore(Timestamp.fromDate(cutoff)).get();
    for (final backup in old.docs) {
      final items = await backup.reference.collection('items').get();
      WriteBatch batch = db.batch();
      var count = 0;
      for (final item in items.docs) {
        batch.delete(item.reference);
        count++;
        if (count >= 300) { await batch.commit(); batch = db.batch(); count = 0; }
      }
      if (count > 0) await batch.commit();
      await backup.reference.delete();
    }
  }

  Future<void> _pruneOldNotifications() async {
    final db = _maintenanceDb;
    final cutoff = DateTime.now().subtract(Duration(days: settings.notificationHistoryDays.clamp(1, 365)));
    final old = await HomeRetentionQueries.fromFirestore(db).notificationsBefore(Timestamp.fromDate(cutoff)).get();
    WriteBatch batch = db.batch();
    var count = 0;
    for (final doc in old.docs) {
      batch.delete(doc.reference);
      count++;
      if (count >= 300) { await batch.commit(); batch = db.batch(); count = 0; }
    }
    if (count > 0) await batch.commit();
  }


}
