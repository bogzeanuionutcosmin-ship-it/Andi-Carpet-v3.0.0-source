import 'dart:async';
import 'dart:typed_data';
import '../lib/admin/admin_backup_files.dart';
// Run with `dart run scripts/verify_pure_models.dart`, without a Flutter engine.
import '../lib/models/app_data_models.dart';
import '../lib/admin/admin_account_projections.dart';
import '../lib/models/app_enums.dart';
import '../lib/models/location_type_mapping.dart';
import '../lib/utils/graph_names.dart';
import '../lib/utils/operational_dates.dart';
import '../lib/learning/duration_estimates.dart';

void check(bool condition, String contract) {
  if (!condition) throw StateError(contract);
}

Future<void> main() async {
  final schedule = WorkSchedule(
    id: 'schedule', teamId: 'team', date: DateTime(2027, 1, 1), items: [],
  );
  check(schedule.graphName == graphDefaultName(schedule.date), 'Default graph name');
  check(defaultCategoryIdForType(LocationType.magic) == 'magic', 'Legacy category mapping');
  check(operationalWorkDate(DateTime(2026, 12, 31, 23, 30)) == DateTime(2027, 1, 1), 'Year boundary');
  final records = List.generate(3, (index) {
    final start = DateTime(2026, 10, index + 1, 1);
    return CentralizerRecord(
      id: 'record-$index', teamId: 'team', locationId: 'location', type: LocationType.magic,
      locationNameSnapshot: 'Synthetic', addressSnapshot: 'Synthetic', startedAt: start,
      finishedAt: start.add(const Duration(minutes: 30)), status: WorkAttemptStatus.completed,
    );
  });
  final estimate = learnedDurationEstimate(records, 'location', AppSettings(), targetDate: DateTime(2026, 10, 31));
  check(estimate?.duration == const Duration(minutes: 30), 'Duration learning');
  check(compareAdminAccountData({'status': 'pending', 'name': 'Z'}, {'name': 'A'}) < 0,
      'Admin pending-first projection without Flutter engine');
  check(adminAssignedFunctionIds({'functionIds': [], 'function': 'admin'}).isEmpty,
      'Empty-list assignment precedence without Flutter engine');
  final bytes = Completer<Uint8List>();
  var reads = 0;
  final backupFile = AdminBackupFile(name: 'synthetic.json', readAsBytes: () {
    reads++; return bytes.future;
  });
  check(reads == 0, 'Backup file construction does not read bytes');
  final pendingRead = backupFile.readAsBytes();
  check(reads == 1, 'Backup byte read starts only on request');
  bytes.complete(Uint8List.fromList([1, 2]));
  check((await pendingRead).length == 2, 'Backup file port without Flutter engine');
  print('PURE_MODEL_SMOKE PASS: defaults, mapping, operational boundary, duration learning, admin account projections, admin file port');
}
