import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('enum serialized names and ordinal positions retain their legacy contract', () {
    expect(LocationType.values.map((value) => value.name).toList(), <String>['magic', 'million', 'horeca', 'other']);
    expect(LocationType.values.map((value) => value.index).toList(), List<int>.generate(4, (index) => index));
    expect(app.LocationType.values, LocationType.values);
    expect(LocationStatus.values.map((value) => value.name).toList(), <String>['open', 'temporarilyClosed', 'permanentlyClosed']);
    expect(LocationStatus.values.map((value) => value.index).toList(), List<int>.generate(3, (index) => index));
    expect(app.LocationStatus.values, LocationStatus.values);
    expect(UserRole.values.map((value) => value.name).toList(), <String>['member', 'director']);
    expect(UserRole.values.map((value) => value.index).toList(), List<int>.generate(2, (index) => index));
    expect(app.UserRole.values, UserRole.values);
    expect(UserFunction.values.map((value) => value.name).toList(), <String>['driver', 'worker', 'developer', 'director']);
    expect(UserFunction.values.map((value) => value.index).toList(), List<int>.generate(4, (index) => index));
    expect(app.UserFunction.values, UserFunction.values);
    expect(FunctionPermission.values.map((value) => value.name).toList(), <String>[
      'viewDashboard',
      'viewProgram',
      'editProgram',
      'startStopProgram',
      'recalculateProgram',
      'transferProgramLocations',
      'viewMap',
      'addLocations',
      'editLocations',
      'relocateLocations',
      'deleteLocations',
      'viewCentralizer',
      'editCentralizer',
      'exportCentralizer',
      'viewOwnDecont',
      'viewOtherDecont',
      'addExpenses',
      'editExpenses',
      'deleteExpenses',
      'managePerDiems',
      'viewGeneralFinance',
      'exportFinance',
      'viewContacts',
      'editContacts',
      'manageMessageTemplates',
      'viewMembers',
      'manageMembers',
      'manageTeams',
      'manageCars',
      'viewDocuments',
      'manageDocuments',
      'manageFunctions',
      'viewAudit',
      'manageNotifications',
      'viewSettings',
      'manageSettings',
      'manageLearning',
      'manageAccounts',
      'openAdminPanel',
    ]);
    expect(FunctionPermission.values.map((value) => value.index).toList(), List<int>.generate(39, (index) => index));
    expect(app.FunctionPermission.values, FunctionPermission.values);
    expect(PerDiemStatus.values.map((value) => value.name).toList(), <String>['notGranted', 'awaitingConfirmation', 'confirmed']);
    expect(PerDiemStatus.values.map((value) => value.index).toList(), List<int>.generate(3, (index) => index));
    expect(app.PerDiemStatus.values, PerDiemStatus.values);
    expect(PerDiemPaymentMethod.values.map((value) => value.name).toList(), <String>['cash', 'bankTransfer']);
    expect(PerDiemPaymentMethod.values.map((value) => value.index).toList(), List<int>.generate(2, (index) => index));
    expect(app.PerDiemPaymentMethod.values, PerDiemPaymentMethod.values);
    expect(ExpenseDocumentType.values.map((value) => value.name).toList(), <String>['fiscalReceipt', 'invoice']);
    expect(ExpenseDocumentType.values.map((value) => value.index).toList(), List<int>.generate(2, (index) => index));
    expect(app.ExpenseDocumentType.values, ExpenseDocumentType.values);
    expect(WorkAttemptStatus.values.map((value) => value.name).toList(), <String>[
      'waitingAccess',
      'running',
      'completed',
      'refused',
      'notCompleted',
    ]);
    expect(WorkAttemptStatus.values.map((value) => value.index).toList(), List<int>.generate(5, (index) => index));
    expect(app.WorkAttemptStatus.values, WorkAttemptStatus.values);
    expect(LearningMode.values.map((value) => value.name).toList(), <String>['manualApproval', 'automatic']);
    expect(LearningMode.values.map((value) => value.index).toList(), List<int>.generate(2, (index) => index));
    expect(app.LearningMode.values, LearningMode.values);
    expect(AppThemeChoice.values.map((value) => value.name).toList(), <String>['light', 'dark', 'system']);
    expect(AppThemeChoice.values.map((value) => value.index).toList(), List<int>.generate(3, (index) => index));
    expect(app.AppThemeChoice.values, AppThemeChoice.values);
  });

  test('all permission display labels retain exact approved spelling', () {
    const expected = <FunctionPermission, String>{
      FunctionPermission.viewDashboard: 'Poate vedea Acasă / Dashboard',
      FunctionPermission.viewProgram: 'Poate vedea Graficul de lucru',
      FunctionPermission.editProgram: 'Poate modifica graficul de lucru',
      FunctionPermission.startStopProgram: 'Poate porni / opri programul',
      FunctionPermission.recalculateProgram: 'Poate recalcula traseul / programul',
      FunctionPermission.transferProgramLocations: 'Poate transfera locații între zile / grafice',
      FunctionPermission.viewMap: 'Poate vedea Hartă',
      FunctionPermission.addLocations: 'Poate adăuga locații noi',
      FunctionPermission.editLocations: 'Poate edita datele locațiilor',
      FunctionPermission.relocateLocations: 'Poate ajusta / reloca poziția GPS',
      FunctionPermission.deleteLocations: 'Poate șterge locații',
      FunctionPermission.viewCentralizer: 'Poate vedea Centralizator',
      FunctionPermission.editCentralizer: 'Poate modifica execuții / centralizator',
      FunctionPermission.exportCentralizer: 'Poate exporta PDF-uri / centralizatoare',
      FunctionPermission.viewOwnDecont: 'Poate vedea propriul Decont',
      FunctionPermission.viewOtherDecont: 'Poate vedea Decontul altor echipe',
      FunctionPermission.addExpenses: 'Poate adăuga cheltuieli / bonuri / facturi',
      FunctionPermission.editExpenses: 'Poate edita cheltuieli / bonuri / facturi',
      FunctionPermission.deleteExpenses: 'Poate șterge cheltuieli / bonuri / facturi',
      FunctionPermission.managePerDiems: 'Poate gestiona diurne',
      FunctionPermission.viewGeneralFinance: 'Poate vedea calculele generale financiare',
      FunctionPermission.exportFinance: 'Poate exporta PDF-uri financiare',
      FunctionPermission.viewContacts: 'Poate vedea Mesaje / Contacte locații',
      FunctionPermission.editContacts: 'Poate edita telefoanele locațiilor',
      FunctionPermission.manageMessageTemplates: 'Poate modifica șabloanele mesajelor automate',
      FunctionPermission.viewMembers: 'Poate vedea Membrii / profilurile',
      FunctionPermission.manageMembers: 'Poate administra Membri / Conturi',
      FunctionPermission.manageTeams: 'Poate administra Echipe',
      FunctionPermission.manageCars: 'Poate administra Mașini',
      FunctionPermission.viewDocuments: 'Poate vedea Documente',
      FunctionPermission.manageDocuments: 'Poate administra Documente',
      FunctionPermission.manageFunctions: 'Poate administra Funcții / drepturi',
      FunctionPermission.viewAudit: 'Poate vedea Audit / Istoric',
      FunctionPermission.manageNotifications: 'Poate trimite notificări de sistem',
      FunctionPermission.viewSettings: 'Poate vedea Setări',
      FunctionPermission.manageSettings: 'Poate administra Setări',
      FunctionPermission.manageLearning: 'Poate administra Learning',
      FunctionPermission.manageAccounts: 'Poate administra Conturi',
      FunctionPermission.openAdminPanel: 'Poate deschide Admin Panel',
    };
    expect(expected.keys.toList(), FunctionPermission.values);
    for (final entry in expected.entries) {
      expect(entry.key.label, entry.value, reason: entry.key.name);
    }
  });

  test('role labels, function icons and location colors are unchanged', () {
    expect(UserRole.values.map((value) => value.label).toList(), <String>['Membru echipă', 'Director']);
    expect(UserFunction.values.map((value) => value.label).toList(), <String>['Șofer', 'Lucrător', 'Developer', 'Director']);
    expect(UserFunction.values.map((value) => value.icon).toList(), <IconData>[Icons.directions_car, Icons.cleaning_services, Icons.computer, Icons.star]);
    expect(LocationType.values.map((value) => value.label).toList(), <String>['MAGIC', 'Million', 'HoReCa', 'Altele']);
    expect(LocationType.values.map((value) => value.color).toList(), <Color>[Colors.black87, Colors.red, Colors.amber, Colors.blueGrey]);
  });

  test('main re-exports extensions and dependent status groups stay compatible', () {
    expect(app.UserRoleX(app.UserRole.director).label, 'Director');
    expect(app.UserFunctionX(app.UserFunction.driver).icon, Icons.directions_car);
    expect(app.LocationTypeX(app.LocationType.magic).color, Colors.black87);
    expect(app.FunctionPermissionX(app.FunctionPermission.viewProgram).label, 'Poate vedea Graficul de lucru');
    expect(app.functionPermissionGroup(FunctionPermission.startStopProgram), 'Grafic de lucru');
    expect(app.PerDiemStatusX(PerDiemStatus.confirmed).label, 'Confirmată');
    expect(app.PaymentMethodX(PerDiemPaymentMethod.bankTransfer).label, 'Transfer bancar');
  });
}
