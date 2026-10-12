part of '../main.dart';

// Permission snapshots, initial data seeding and badge migration.
mixin _HomePermissionMaintenance on State<HomePage> {
  bool get isAdmin;
  List<FunctionDefinition> get functionDefinitions;
  bool get _permissionSyncInFlight;
  set _permissionSyncInFlight(bool value);
  String? get coreSyncError;
  set coreSyncError(String? value);
  Set<String> _effectivePermissionsForIds(List<String> ids);
  List<Location> _seedLocations();

  Future<void> _syncUserPermissionSnapshots() async {
    if (!isAdmin || _permissionSyncInFlight || functionDefinitions.isEmpty) return;
    _permissionSyncInFlight = true;
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db.collection('users').get();
      final batch = db.batch();
      var writes = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final role = (d['role'] ?? 'member').toString();
        final functionIds = d['functionIds'] is List
            ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
            : <String>[(role == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList();
        final effective = role == 'admin'
            ? FunctionPermission.values.map((e) => e.name).toSet()
            : _effectivePermissionsForIds(functionIds);
        final current = d['effectivePermissions'] is List
            ? (d['effectivePermissions'] as List).map((e) => e.toString()).toSet()
            : <String>{};
        if (current.length == effective.length && current.containsAll(effective)) continue;
        final sorted = effective.toList()..sort();
        batch.set(doc.reference, {
          'effectivePermissions': sorted,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        writes++;
      }
      if (writes > 0) await batch.commit();
    } catch (e) {
      if (mounted) setState(() => coreSyncError = 'Sincronizare drepturi: $e');
    } finally {
      _permissionSyncInFlight = false;
    }
  }

  Future<void> _seedLocationsIfNeeded() async {
    final col = FirebaseFirestore.instance.collection('locations');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final l in _seedLocations()) {
      batch.set(col.doc(l.id), _locationMap(l));
    }
    await batch.commit();
  }

  Future<void> _seedDefinitionsIfNeeded() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final categoriesCol = db.collection('locationCategories');
    final functionsCol = db.collection('functions');
    final existingCategories = await categoriesCol.limit(1).get();
    final existingFunctions = await functionsCol.limit(1).get();
    final batch = db.batch();
    var writes = 0;
    if (existingCategories.docs.isEmpty) {
      for (final c in defaultLocationCategories()) { batch.set(categoriesCol.doc(c.id), _categoryMap(c)); writes++; }
    }
    if (existingFunctions.docs.isEmpty) {
      for (final f in defaultFunctionDefinitions()) { batch.set(functionsCol.doc(f.id), _functionMap(f)); writes++; }
    }
    if (writes > 0) await batch.commit();
  }

  Future<void> _migrateFunctionBadgeSystemIfNeeded() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final metaRef = db.collection('meta').doc('uiSettings');
    final metaSnap = await metaRef.get();
    if ((metaSnap.data()?['functionSystemVersion'] ?? '').toString() == 'badge_v2') return;

    final usersSnap = await db.collection('users').get();
    final functionsSnap = await db.collection('functions').get();
    final adminFunction = defaultFunctionDefinitions().first;
    final allPermissions = FunctionPermission.values.map((e) => e.name).toList()..sort();

    WriteBatch batch = db.batch();
    var writes = 0;
    Future<void> flush() async {
      if (writes == 0) return;
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }

    for (final doc in functionsSnap.docs) {
      batch.delete(doc.reference);
      writes++;
      if (writes >= 350) await flush();
    }
    batch.set(db.collection('functions').doc(adminFunction.id), _functionMap(adminFunction));
    writes++;
    if (writes >= 350) await flush();

    for (final doc in usersSnap.docs) {
      final role = (doc.data()['role'] ?? 'member').toString();
      final isDocAdmin = role == 'admin';
      batch.set(doc.reference, {
        'function': isDocAdmin ? 'admin' : '',
        'functionIds': isDocAdmin ? <String>['admin'] : <String>[],
        'effectivePermissions': isDocAdmin ? allPermissions : <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      writes++;
      if (writes >= 350) await flush();
    }

    batch.set(metaRef, {'functionSystemVersion': 'badge_v2', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    writes++;
    await flush();
  }

}
