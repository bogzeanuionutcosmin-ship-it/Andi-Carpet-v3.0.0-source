import 'dart:convert';
import 'dart:typed_data';
import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'home_maintenance_fixture.dart';
import 'home_sync_fixture.dart';
import 'auth_gate_fixture.dart';
import 'admin_ui_fixture.dart';

class BackupFilesFixture implements AdminBackupFiles {
  AdminBackupFile? selected;
  int picks = 0, reads = 0;
  final exports = <({String name, Uint8List bytes})>[];
  Object? saveResult;
  @override
  Future<AdminBackupFile?> pickJson() async { picks++; return selected; }
  @override
  Future<Object?> saveJson({required String fileName, required Uint8List bytes}) async {
    exports.add((name: fileName, bytes: Uint8List.fromList(bytes)));
    return saveResult;
  }
  void file(Object? payload, {String name = 'synthetic.json'}) {
    raw(jsonEncode(payload), name: name);
  }
  void raw(String text, {String name = 'synthetic.json'}) {
    selected = AdminBackupFile(name: name, readAsBytes: () async {
      reads++; return Uint8List.fromList(utf8.encode(text));
    });
  }
}

// Uses the existing strict read/write fixture and tracked subscription fixture.
// No default Firebase singleton or FilePicker is reached by these actions.
class AdminBackupDbFixture extends HomeMaintenanceFixture {
  final streams = HomeSyncFixture();
  CollectionReference<Map<String, dynamic>> baseCollection(String path) => super.collection(path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _BackupCollection(this, path, streams.collection(path));
  Future<void> close() => streams.close();
  void emitPanel({Map<String, dynamic>? latest, String id = 'snapshot'}) {
    streams.document('meta/backup').add(GateFixtureSnapshot({}));
    streams.query('backups[order:createdAt:desc][limit:1]').add(HomeFixtureSnapshot(
      latest == null ? [] : [MaintenanceDoc(this, 'backups/$id', latest)]));
  }
}
class _BackupCollection extends Fake implements CollectionReference<Map<String, dynamic>> {
  final AdminBackupDbFixture db;
  final String path;
  final Query<Map<String, dynamic>> streamQuery;
  _BackupCollection(this.db, this.path, this.streamQuery);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) {
    if (id == null) return db.reject('auto-id:$path');
    return _BackupDocument(db, path, id);
  }
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) => db.baseCollection(path).get();
  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) =>
      _BackupCollection(db, path, streamQuery.orderBy(field, descending: descending));
  @override
  Query<Map<String, dynamic>> limit(int count) => _BackupCollection(db, path, streamQuery.limit(count));
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({bool includeMetadataChanges = false, ListenSource source = ListenSource.defaultSource}) =>
      streamQuery.snapshots(includeMetadataChanges: includeMetadataChanges, source: source);
  @override
  dynamic noSuchMethod(Invocation i) => db.reject('$path:${i.memberName}');
}
class _BackupDocument extends Fake implements DocumentReference<Map<String, dynamic>> {
  final AdminBackupDbFixture db;
  final String parentPath;
  @override
  final String id;
  _BackupDocument(this.db, this.parentPath, this.id);
  @override
  String get path => '$parentPath/$id';
  DocumentReference<Map<String, dynamic>> get base => db.baseCollection(parentPath).doc(id);
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) => db.collection('$path/$name');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) => base.get();
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) => base.set(data, options);
  @override
  Future<void> delete() => base.delete();
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({bool includeMetadataChanges = false, ListenSource source = ListenSource.defaultSource}) =>
      db.streams.collection(parentPath).doc(id).snapshots(includeMetadataChanges: includeMetadataChanges, source: source);
  @override
  dynamic noSuchMethod(Invocation i) => db.reject('$path:${i.memberName}');
}

class AdminBackupHarness {
  final ui = AdminUiFixture();
  final db = AdminBackupDbFixture();
  final files = BackupFilesFixture();
  Future<void> mount(WidgetTester tester, {Map<String, dynamic>? latest}) async {
    await ui.mount(tester, 16, backupFirestore: db, backupFiles: files);
    db.emitPanel(latest: latest);
    await tester.pumpAndSettle();
  }
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    expect(db.streams.activeCount, 0);
    expect(db.unexpected, isEmpty);
    expect(tester.takeException(), isNull);
    await db.close();
  }
  void expectNoCommand() {
    expect(db.trace, isEmpty); expect(db.commitAttempts, isEmpty);
    expect(db.commits, isEmpty); expect(db.directWrites, isEmpty);
    expect(ui.logs, isEmpty); expect(ui.changes, 0);
  }
}
