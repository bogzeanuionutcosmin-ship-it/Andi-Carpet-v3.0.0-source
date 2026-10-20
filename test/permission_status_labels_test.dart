import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/models/permission_status_labels.dart';

void main() {
  group('functionPermissionGroup', () {
    test('assigns every permission to its existing group', () {
      const expected = <String, List<FunctionPermission>>{
        'General': [FunctionPermission.viewDashboard],
        'Grafic de lucru': [
          FunctionPermission.viewProgram,
          FunctionPermission.editProgram,
          FunctionPermission.startStopProgram,
          FunctionPermission.recalculateProgram,
          FunctionPermission.transferProgramLocations,
        ],
        'Hartă / Locații': [
          FunctionPermission.viewMap,
          FunctionPermission.addLocations,
          FunctionPermission.editLocations,
          FunctionPermission.relocateLocations,
          FunctionPermission.deleteLocations,
        ],
        'Centralizator': [
          FunctionPermission.viewCentralizer,
          FunctionPermission.editCentralizer,
          FunctionPermission.exportCentralizer,
        ],
        'Decont / Financiar': [
          FunctionPermission.viewOwnDecont,
          FunctionPermission.viewOtherDecont,
          FunctionPermission.addExpenses,
          FunctionPermission.editExpenses,
          FunctionPermission.deleteExpenses,
          FunctionPermission.managePerDiems,
          FunctionPermission.viewGeneralFinance,
          FunctionPermission.exportFinance,
        ],
        'Mesaje / Contacte locații': [
          FunctionPermission.viewContacts,
          FunctionPermission.editContacts,
          FunctionPermission.manageMessageTemplates,
        ],
        'Membri / Echipe / Mașini': [
          FunctionPermission.viewMembers,
          FunctionPermission.manageMembers,
          FunctionPermission.manageTeams,
          FunctionPermission.manageCars,
        ],
        'Documente': [
          FunctionPermission.viewDocuments,
          FunctionPermission.manageDocuments,
        ],
        'Administrare': [
          FunctionPermission.manageFunctions,
          FunctionPermission.viewAudit,
          FunctionPermission.manageNotifications,
          FunctionPermission.viewSettings,
          FunctionPermission.manageSettings,
          FunctionPermission.manageLearning,
          FunctionPermission.manageAccounts,
          FunctionPermission.openAdminPanel,
        ],
      };

      final mapped = <FunctionPermission, String>{};
      for (final entry in expected.entries) {
        for (final permission in entry.value) {
          expect(mapped.containsKey(permission), isFalse, reason: '$permission appears once');
          mapped[permission] = entry.key;
        }
      }

      expect(mapped.keys.toSet(), FunctionPermission.values.toSet());
      for (final permission in FunctionPermission.values) {
        expect(functionPermissionGroup(permission), mapped[permission]);
      }
    });
  });

  test('keeps per-diem and payment labels unchanged', () {
    expect(PerDiemStatus.notGranted.label, 'Neacordată');
    expect(PerDiemStatus.awaitingConfirmation.label, 'În așteptare confirmare');
    expect(PerDiemStatus.confirmed.label, 'Confirmată');
    expect(PerDiemPaymentMethod.cash.label, 'Numerar');
    expect(PerDiemPaymentMethod.bankTransfer.label, 'Transfer bancar');
  });
}
