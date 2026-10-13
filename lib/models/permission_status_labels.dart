import 'app_enums_permissions.dart';

String functionPermissionGroup(FunctionPermission permission) {
  switch (permission) {
    case FunctionPermission.viewDashboard:
      return 'General';
    case FunctionPermission.viewProgram:
    case FunctionPermission.editProgram:
    case FunctionPermission.startStopProgram:
    case FunctionPermission.recalculateProgram:
    case FunctionPermission.transferProgramLocations:
      return 'Grafic de lucru';
    case FunctionPermission.viewMap:
    case FunctionPermission.addLocations:
    case FunctionPermission.editLocations:
    case FunctionPermission.relocateLocations:
    case FunctionPermission.deleteLocations:
      return 'Hartă / Locații';
    case FunctionPermission.viewCentralizer:
    case FunctionPermission.editCentralizer:
    case FunctionPermission.exportCentralizer:
      return 'Centralizator';
    case FunctionPermission.viewOwnDecont:
    case FunctionPermission.viewOtherDecont:
    case FunctionPermission.addExpenses:
    case FunctionPermission.editExpenses:
    case FunctionPermission.deleteExpenses:
    case FunctionPermission.managePerDiems:
    case FunctionPermission.viewGeneralFinance:
    case FunctionPermission.exportFinance:
      return 'Decont / Financiar';
    case FunctionPermission.viewContacts:
    case FunctionPermission.editContacts:
    case FunctionPermission.manageMessageTemplates:
      return 'Mesaje / Contacte locații';
    case FunctionPermission.viewMembers:
    case FunctionPermission.manageMembers:
    case FunctionPermission.manageTeams:
    case FunctionPermission.manageCars:
      return 'Membri / Echipe / Mașini';
    case FunctionPermission.viewDocuments:
    case FunctionPermission.manageDocuments:
      return 'Documente';
    case FunctionPermission.manageFunctions:
    case FunctionPermission.viewAudit:
    case FunctionPermission.manageNotifications:
    case FunctionPermission.viewSettings:
    case FunctionPermission.manageSettings:
    case FunctionPermission.manageLearning:
    case FunctionPermission.manageAccounts:
    case FunctionPermission.openAdminPanel:
      return 'Administrare';
  }
}


extension PerDiemStatusX on PerDiemStatus {
  String get label => switch (this) {
        PerDiemStatus.notGranted => 'Neacordată',
        PerDiemStatus.awaitingConfirmation => 'În așteptare confirmare',
        PerDiemStatus.confirmed => 'Confirmată',
      };
}

extension PaymentMethodX on PerDiemPaymentMethod {
  String get label => this == PerDiemPaymentMethod.cash ? 'Numerar' : 'Transfer bancar';
}

