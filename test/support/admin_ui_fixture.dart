import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Every attempted Firebase singleton access is counted even if a UI catch
// swallows its error. These cancel-only tests do not initialize a Firebase app.
class NoFirebaseAccess extends FirebasePlatform {
  final attempts = <String>[];
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    attempts.add(name);
    throw StateError('Firebase access forbidden in cancel-only fixture');
  }
}

class AdminUiFixture {
  final List<AppUser> users;
  final List<FunctionDefinition> functions;
  final logs = <String>[];
  int changes = 0;
  AdminUiFixture({this.users = const [], this.functions = const []});
  AdminPanelPage page({FirebaseFirestore? backupFirestore, AdminBackupFiles? backupFiles}) => AdminPanelPage(
    backupFirestore: backupFirestore, backupFiles: backupFiles,
    users: users, teams: [], cars: [], locations: [], categories: [],
    functionDefinitions: functions, schedules: [], records: [], expenses: [],
    perDiems: [], finances: [], settlements: [], notifications: [], audit: [],
    settings: AppSettings(), userName: (id) => id,
    onChanged: () { changes++; }, log: (a, b) => logs.add('$a:$b'),
    saveLocation: (_) async { fail('Unexpected location write'); },
    deleteLocation: (_) async { fail('Unexpected location delete'); },
  );
  Future<void> mount(WidgetTester tester, int section, {FirebaseFirestore? backupFirestore, AdminBackupFiles? backupFiles}) async {
    await tester.pumpWidget(MaterialApp(home: page(backupFirestore: backupFirestore, backupFiles: backupFiles)));
    final dynamic state = tester.state(find.byType(AdminPanelPage));
    state.setState(() { state.section = section; });
    await tester.pumpAndSettle();
  }
}
