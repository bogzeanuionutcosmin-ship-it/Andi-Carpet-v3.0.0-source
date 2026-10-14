import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'home_sync_fixture.dart';

class MaintenanceWrite {
  final String operation;
  final String path;
  final Map<String, dynamic>? data;
  final bool merge;
  MaintenanceWrite(this.operation, this.path, this.data, this.merge);
}

class MaintenanceDoc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  MaintenanceDoc(HomeMaintenanceFixture db, String path, this.value)
      : id = path.split('/').last, reference = _MaintenanceDocument(db, path);
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
}

// Every read is explicitly scripted. Unexpected SDK calls are recorded even if
// runtime catches their errors, so a swallowed exception cannot produce a pass.
class HomeMaintenanceFixture extends Fake implements FirebaseFirestore {
  final trace = <String>[];
  final unexpected = <String>[];
  final commits = <List<MaintenanceWrite>>[];
  final commitAttempts = <List<MaintenanceWrite>>[];
  Future<void> Function(List<MaintenanceWrite>)? beforeCommit;
  final directWrites = <MaintenanceWrite>[];
  final queryReads = <String, Future<QuerySnapshot<Map<String, dynamic>>> Function()>{};
  final documentReads = <String, Future<DocumentSnapshot<Map<String, dynamic>>> Function()>{};
  Never reject(String operation) {
    unexpected.add(operation);
    throw StateError('Unscripted maintenance operation: $operation');
  }
  void setQuery(String key, List<MaintenanceDoc> docs) =>
      queryReads[key] = () async => HomeFixtureSnapshot(docs);
  void setDocument(String path, Map<String, dynamic> data) =>
      documentReads[path] = () async => MaintenanceDoc(this, path, data);
  void primeExisting({bool migrated = true}) {
    setQuery('locations[limit:1]', [MaintenanceDoc(this, 'locations/room', {'name': 'Synthetic'})]);
    setQuery('locationCategories[limit:1]', [MaintenanceDoc(this, 'locationCategories/category', {'name': 'Synthetic'})]);
    setQuery('functions[limit:1]', [MaintenanceDoc(this, 'functions/custom', {'name': 'Synthetic'})]);
    setDocument('meta/uiSettings', {'functionSystemVersion': migrated ? 'badge_v2' : 'legacy'});
  }
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _MaintenanceQuery(this, path);
  @override
  WriteBatch batch() { trace.add('batch'); return _MaintenanceBatch(this); }
}

class _MaintenanceQuery extends Fake implements CollectionReference<Map<String, dynamic>> {
  final HomeMaintenanceFixture db;
  final String key;
  _MaintenanceQuery(this.db, this.key);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    if (invocation.memberName == #limit) return _MaintenanceQuery(db, '$key[limit:${args.first}]');
    if (invocation.memberName == #doc) return _MaintenanceDocument(db, '$key/${args.first}');
    if (invocation.memberName == #where) {
      final cutoff = invocation.namedArguments[#isLessThan];
      if (args.single != 'createdAt' || cutoff is! Timestamp) return db.reject('where:$key');
      return _MaintenanceQuery(db, '$key[before:createdAt]');
    }
    if (invocation.memberName == #get) {
      db.trace.add('get:$key');
      return db.queryReads[key]?.call() ?? db.reject('get:$key');
    }
    return db.reject('$key:${invocation.memberName}');
  }
}

class _MaintenanceDocument extends Fake implements DocumentReference<Map<String, dynamic>> {
  final HomeMaintenanceFixture db;
  @override
  final String path;
  _MaintenanceDocument(this.db, this.path);
  @override
  String get id => path.split('/').last;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    if (invocation.memberName == #collection) return _MaintenanceQuery(db, '$path/${args.first}');
    if (invocation.memberName == #get) {
      db.trace.add('get:$path');
      return db.documentReads[path]?.call() ?? db.reject('get:$path');
    }
    if (invocation.memberName == #delete) {
      db.trace.add('delete:$path');
      db.directWrites.add(MaintenanceWrite('delete', path, null, false));
      return Future<void>.value();
    }
    if (invocation.memberName == #set) {
      db.trace.add('set:$path');
      db.directWrites.add(MaintenanceWrite('set', path, Map<String, dynamic>.from(args.first as Map),
        args.length > 1 && args[1] is SetOptions && (args[1] as SetOptions).merge == true));
      return Future<void>.value();
    }
    return db.reject('$path:${invocation.memberName}');
  }
}

class _MaintenanceBatch extends Fake implements WriteBatch {
  final HomeMaintenanceFixture db;
  final writes = <MaintenanceWrite>[];
  _MaintenanceBatch(this.db);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    if (invocation.memberName == #set || invocation.memberName == #delete) {
      final ref = args.first as DocumentReference;
      final deleting = invocation.memberName == #delete;
      writes.add(MaintenanceWrite(deleting ? 'delete' : 'set', ref.path,
        deleting ? null : Map<String, dynamic>.from(args[1] as Map),
        !deleting && args.length > 2 && args[2] is SetOptions && (args[2] as SetOptions).merge == true));
      return this;
    }
    if (invocation.memberName == #commit) {
      db.trace.add('commit:${writes.length}');
      final attempt = List<MaintenanceWrite>.from(writes);
      db.commitAttempts.add(attempt);
      return (() async {
        final hook = db.beforeCommit;
        if (hook != null) await hook(attempt);
        db.commits.add(attempt);
      })();
    }
    return db.reject('batch:${invocation.memberName}');
  }
}
