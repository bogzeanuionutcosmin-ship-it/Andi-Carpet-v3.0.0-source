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
