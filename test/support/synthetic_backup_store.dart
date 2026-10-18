import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'admin_backup_fixture.dart';
import 'home_maintenance_fixture.dart';
import 'home_sync_fixture.dart';

// Test-only durable command model. Commit rejection is BEFORE applying the
// whole batch. It does not simulate network ambiguity, SDK cache or rules.
class SyntheticBackupStore {
  final AdminBackupDbFixture db;
  final data = <String, Map<String, dynamic>>{};
  Future<void> Function(List<MaintenanceWrite>)? gate;
  SyntheticBackupStore(this.db) {
    db.beforeCommit = (writes) async {
      await gate?.call(writes);
      for (final write in writes) {
        if (write.operation == 'delete') {
          data.remove(write.path);
        } else {
          final value = clone(write.data!);
          data[write.path] = write.merge ? {...?data[write.path], ...value} : value;
        }
      }
    };
  }
  static Map<String, dynamic> clone(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  void seed(String path, Map<String, dynamic> value) => data[path] = clone(value);
  void allowRead(String collection) {
    db.queryReads[collection] = () async => HomeFixtureSnapshot([
      for (final e in data.entries)
        if (e.key.startsWith('$collection/') && !e.key.substring(collection.length + 1).contains('/'))
          MaintenanceDoc(db, e.key, clone(e.value)),
    ]);
  }
  void expectUnchanged(String path, Map<String, dynamic> original) => expect(data[path], original);
}
