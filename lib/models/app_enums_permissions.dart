import 'package:flutter/material.dart';

enum LocationType { magic, million, horeca, other }
enum LocationStatus { open, temporarilyClosed, permanentlyClosed }

enum UserRole { member, director }
enum UserFunction { driver, worker, developer, director }
enum FunctionPermission {
  viewDashboard,
  viewProgram,
  editProgram,
  startStopProgram,
  recalculateProgram,
  transferProgramLocations,
  viewMap,
  addLocations,
  editLocations,
  relocateLocations,
  deleteLocations,
  viewCentralizer,
  editCentralizer,
  exportCentralizer,
  viewOwnDecont,
  viewOtherDecont,
  addExpenses,
  editExpenses,
  deleteExpenses,
  managePerDiems,
  viewGeneralFinance,
  exportFinance,
  viewContacts,
  editContacts,
  manageMessageTemplates,
  viewMembers,
  manageMembers,
  manageTeams,
  manageCars,
  viewDocuments,
  manageDocuments,
  manageFunctions,
  viewAudit,
  manageNotifications,
  viewSettings,
  manageSettings,
  manageLearning,
  manageAccounts,
  openAdminPanel,
}
enum PerDiemStatus { notGranted, awaitingConfirmation, confirmed }
enum PerDiemPaymentMethod { cash, bankTransfer }
enum ExpenseDocumentType { fiscalReceipt, invoice }
enum WorkAttemptStatus { waitingAccess, running, completed, refused, notCompleted }

enum LearningMode { manualApproval, automatic }

enum AppThemeChoice { light, dark, system }

extension LocationTypeX on LocationType {
  String get label => switch (this) {
        LocationType.magic => 'MAGIC',
        LocationType.million => 'Million',
        LocationType.horeca => 'HoReCa',
        LocationType.other => 'Altele',
      };
  Color get color => switch (this) {
        LocationType.magic => Colors.black87,
        LocationType.million => Colors.red,
        LocationType.horeca => Colors.amber,
        LocationType.other => Colors.blueGrey,
      };
}

extension UserRoleX on UserRole {
  String get label => this == UserRole.director ? 'Director' : 'Membru echipă';
}

extension UserFunctionX on UserFunction {
  String get label => switch (this) {
    UserFunction.driver => 'Șofer',
    UserFunction.worker => 'Lucrător',
    UserFunction.developer => 'Developer',
    UserFunction.director => 'Director',
  };
  IconData get icon => switch (this) {
    UserFunction.driver => Icons.directions_car,
    UserFunction.worker => Icons.cleaning_services,
    UserFunction.developer => Icons.computer,
    UserFunction.director => Icons.star,
  };
}

extension FunctionPermissionX on FunctionPermission {
  String get label => switch (this) {
    FunctionPermission.viewDashboard => 'Poate vedea Acasă / Dashboard',
    FunctionPermission.viewProgram => 'Poate vedea Graficul de lucru',
    FunctionPermission.editProgram => 'Poate modifica graficul de lucru',
    FunctionPermission.startStopProgram => 'Poate porni / opri programul',
    FunctionPermission.recalculateProgram => 'Poate recalcula traseul / programul',
    FunctionPermission.transferProgramLocations => 'Poate transfera locații între zile / grafice',
    FunctionPermission.viewMap => 'Poate vedea Hartă',
    FunctionPermission.addLocations => 'Poate adăuga locații noi',
    FunctionPermission.editLocations => 'Poate edita datele locațiilor',
    FunctionPermission.relocateLocations => 'Poate ajusta / reloca poziția GPS',
    FunctionPermission.deleteLocations => 'Poate șterge locații',
    FunctionPermission.viewCentralizer => 'Poate vedea Centralizator',
    FunctionPermission.editCentralizer => 'Poate modifica execuții / centralizator',
    FunctionPermission.exportCentralizer => 'Poate exporta PDF-uri / centralizatoare',
    FunctionPermission.viewOwnDecont => 'Poate vedea propriul Decont',
    FunctionPermission.viewOtherDecont => 'Poate vedea Decontul altor echipe',
    FunctionPermission.addExpenses => 'Poate adăuga cheltuieli / bonuri / facturi',
    FunctionPermission.editExpenses => 'Poate edita cheltuieli / bonuri / facturi',
    FunctionPermission.deleteExpenses => 'Poate șterge cheltuieli / bonuri / facturi',
    FunctionPermission.managePerDiems => 'Poate gestiona diurne',
    FunctionPermission.viewGeneralFinance => 'Poate vedea calculele generale financiare',
    FunctionPermission.exportFinance => 'Poate exporta PDF-uri financiare',
    FunctionPermission.viewContacts => 'Poate vedea Mesaje / Contacte locații',
    FunctionPermission.editContacts => 'Poate edita telefoanele locațiilor',
    FunctionPermission.manageMessageTemplates => 'Poate modifica șabloanele mesajelor automate',
    FunctionPermission.viewMembers => 'Poate vedea Membrii / profilurile',
    FunctionPermission.manageMembers => 'Poate administra Membri / Conturi',
    FunctionPermission.manageTeams => 'Poate administra Echipe',
    FunctionPermission.manageCars => 'Poate administra Mașini',
    FunctionPermission.viewDocuments => 'Poate vedea Documente',
    FunctionPermission.manageDocuments => 'Poate administra Documente',
    FunctionPermission.manageFunctions => 'Poate administra Funcții / drepturi',
    FunctionPermission.viewAudit => 'Poate vedea Audit / Istoric',
    FunctionPermission.manageNotifications => 'Poate trimite notificări de sistem',
    FunctionPermission.viewSettings => 'Poate vedea Setări',
    FunctionPermission.manageSettings => 'Poate administra Setări',
    FunctionPermission.manageLearning => 'Poate administra Learning',
    FunctionPermission.manageAccounts => 'Poate administra Conturi',
    FunctionPermission.openAdminPanel => 'Poate deschide Admin Panel',
  };
}

