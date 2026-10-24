import 'app_enums_permissions.dart';
import 'category_identity.dart';
import '../utils/date_formatters.dart' show graphDefaultName;

class AppUser {
  final String id;
  String name;
  UserRole role; // păstrat intern pentru compatibilitate cu prototipul vechi
  UserFunction function;
  List<String> functionIds;
  String? teamId;
  String email;
  bool active;
  bool hiddenFromMembers;
  String photoBase64;
  AppUser({required this.id, required this.name, required this.role, UserFunction? function, List<String>? functionIds, this.teamId, this.email = '', this.active = true, this.hiddenFromMembers = false, this.photoBase64 = ''})
      : function = function ?? (role == UserRole.director ? UserFunction.director : UserFunction.worker),
        functionIds = functionIds ?? <String>[(role == UserRole.director ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList();
}

class Team {
  final String id;
  String name;
  List<String> members;
  String? carId;
  String? financialManagerId;
  bool active;
  Team({required this.id, required this.name, required this.members, this.carId, this.financialManagerId, this.active = true});
}

class Car {
  final String id;
  String plate;
  String makeModel;
  bool active;
  DateTime? rcaUntil;
  DateTime? itpUntil;
  DateTime? rovinietaUntil;
  double averageConsumption;
  double fuelPricePerLiter;
  String fuelType;
  Car({required this.id, required this.plate, this.makeModel = '', this.active = true, this.rcaUntil, this.itpUntil, this.rovinietaUntil, this.averageConsumption = 0, this.fuelPricePerLiter = 0, this.fuelType = 'Motorină'});
}

class LocationContact {
  String name;
  String phone;
  String role;
  bool smsEnabled;
  LocationContact({required this.name, required this.phone, this.role = 'Manager', this.smsEnabled = true});
}

class Location {
  final String id;
  String name;
  String address;
  double? latitude;
  double? longitude;
  LocationType type;
  String categoryId;
  LocationStatus status;
  String? phone;
  List<LocationContact> contacts;
  double surfaceM2;
  double facadeM2;
  String notes;
  bool active;
  Location({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    String? categoryId,
    this.status = LocationStatus.open,
    this.latitude,
    this.longitude,
    this.phone,
    List<LocationContact>? contacts,
    this.surfaceM2 = 0,
    this.facadeM2 = 0,
    this.notes = '',
    this.active = true,
  }) : categoryId = categoryId ?? defaultCategoryIdForType(type), contacts = contacts ?? [];

  bool get selectableForProgram => active && status == LocationStatus.open;
}

class ScheduleItem {
  final String interventionId;
  final String locationId;
  final String locationNameSnapshot;
  final String addressSnapshot;
  final LocationType typeSnapshot;
  final String categoryIdSnapshot;
  int order;
  bool transferred;
  bool facadePlanned;
  ScheduleItem({this.interventionId = '', required this.locationId, required this.locationNameSnapshot, required this.addressSnapshot, required this.typeSnapshot, String? categoryIdSnapshot, required this.order, this.transferred = false, this.facadePlanned = false}) : categoryIdSnapshot = categoryIdSnapshot ?? defaultCategoryIdForType(typeSnapshot);
}

class WorkSchedule {
  final String id;
  final String teamId;
  String graphId;
  String graphName;
  DateTime date;
  List<ScheduleItem> items;
  bool active;
  bool closed;
  bool started;
  bool paused;
  bool postponed;
  bool autoProposed;
  DateTime? planAlertAt;
  String planAlertReason;
  DateTime? lastRecalculatedAt;
  int recalculationCount;
  String learningExplanation;
  double learningConfidence;
  int learningSamples;
  String departureName;
  double? departureLatitude;
  double? departureLongitude;
  String returnName;
  double? returnLatitude;
  double? returnLongitude;
  DateTime? updatedAt;
  String? writeToken;
  // Local provenance; never serialized. Legacy documents may have no revision.
  bool persisted;
  WorkSchedule({required this.id, required this.teamId, String? graphId, String? graphName, required this.date, required this.items, this.active = true, this.closed = false, this.started = false, this.paused = false, this.postponed = false, this.autoProposed = false, this.planAlertAt, this.planAlertReason = '', this.lastRecalculatedAt, this.recalculationCount = 0, this.learningExplanation = '', this.learningConfidence = 0, this.learningSamples = 0, this.departureName = '', this.departureLatitude, this.departureLongitude, this.returnName = '', this.returnLatitude, this.returnLongitude, this.updatedAt, this.writeToken, this.persisted = false})
      : graphId = graphId ?? id,
        graphName = graphName ?? graphDefaultName(date);
}

class CentralizerRecord {
  // Local compare-and-swap baseline, never persisted as a field.
  Map<String, dynamic>? writeBaseline;
  final String id;
  final String teamId;
  final String locationId;
  final String graphId;
  final String scheduleId;
  final String interventionId;
  final LocationType type;
  String locationNameSnapshot;
  String addressSnapshot;
  DateTime? waitingStartedAt;
  DateTime? waitingEndedAt;
  DateTime? startedAt;
  DateTime? finishedAt;
  WorkAttemptStatus status;
  String? refusalReason;
  bool keptForLearning;
  bool facadePlanned;
  bool facadeDone;
  CentralizerRecord({
    required this.id,
    required this.teamId,
    required this.locationId,
    this.graphId = '',
    this.scheduleId = '',
    this.interventionId = '',
    required this.type,
    required this.locationNameSnapshot,
    required this.addressSnapshot,
    this.writeBaseline,
    this.waitingStartedAt,
    this.waitingEndedAt,
    this.startedAt,
    this.finishedAt,
    this.status = WorkAttemptStatus.waitingAccess,
    this.refusalReason,
    this.keptForLearning = true,
    this.facadePlanned = false,
    this.facadeDone = false,
  });
  bool get completed => status == WorkAttemptStatus.completed && startedAt != null && finishedAt != null;
  Duration? get duration => completed ? finishedAt!.difference(startedAt!) : null;
  Duration? get waitingDuration => waitingStartedAt != null && waitingEndedAt != null ? waitingEndedAt!.difference(waitingStartedAt!) : null;
}

class Expense {
  final String id;
  final String teamId;
  String? settlementId;
  String category;
  String description;
  double amount;
  DateTime date;
  ExpenseDocumentType documentType;
  String documentNumber;
  String supplier;
  double? liters;
  double? pricePerLiter;
  String documentImageBase64;
  String imageFingerprint;
  String ocrRawText;
  double ocrConfidence;
  bool confirmed;
  Expense({
    required this.id,
    required this.teamId,
    this.settlementId,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.documentType = ExpenseDocumentType.fiscalReceipt,
    this.documentNumber = '',
    this.supplier = '',
    this.liters,
    this.pricePerLiter,
    this.documentImageBase64 = '',
    this.imageFingerprint = '',
    this.ocrRawText = '',
    this.ocrConfidence = 0,
    this.confirmed = true,
  });
  bool get hasImage => documentImageBase64.isNotEmpty;
}



class PerDiemEntry {
  final String id;
  final String teamId;
  final String memberId;
  final DateTime date;
  String? settlementId;
  double amount;
  PerDiemStatus status;
  PerDiemPaymentMethod? method;
  String? distributedBy;
  DateTime? distributedAt;
  DateTime? confirmedAt;
  bool? received;
  double? actualReceivedAmount;
  String? supplementaryFor; // Payment-only, never a second entitlement.
  PerDiemEntry({required this.id, required this.teamId, required this.memberId, required this.date, this.settlementId, required this.amount, this.status = PerDiemStatus.notGranted, this.method, this.distributedBy, this.distributedAt, this.confirmedAt, this.received, this.actualReceivedAmount, this.supplementaryFor});
}

class ReceivedMoneyEntry {
  final String id;
  final String kind; // departure / during
  final double amount;
  final String method; // Cash / Transfer
  final String fromName;
  final DateTime date;
  const ReceivedMoneyEntry({required this.id, required this.kind, required this.amount, required this.method, required this.fromName, required this.date});
}

class TravelSettlement {
  final String id;
  final String teamId;
  String name;
  DateTime startDate;
  DateTime? endDate;
  String? managerId;
  double receivedDeparture;
  double receivedDuring;
  List<ReceivedMoneyEntry> receivedEntries;
  double perDiemRate;
  bool closed;
  final DateTime createdAt;
  TravelSettlement({
    required this.id,
    required this.teamId,
    required this.name,
    required this.startDate,
    this.endDate,
    this.managerId,
    this.receivedDeparture = 0,
    this.receivedDuring = 0,
    List<ReceivedMoneyEntry>? receivedEntries,
    this.perDiemRate = 50,
    this.closed = false,
    DateTime? createdAt,
  }) : receivedEntries = receivedEntries ?? <ReceivedMoneyEntry>[], createdAt = createdAt ?? DateTime.now();
  double get departureTotal => receivedEntries.isEmpty ? receivedDeparture : receivedEntries.where((e)=>e.kind=='departure').fold<double>(0,(a,b)=>a+b.amount);
  double get duringTotal => receivedEntries.isEmpty ? receivedDuring : receivedEntries.where((e)=>e.kind=='during').fold<double>(0,(a,b)=>a+b.amount);
  double get totalReceived => departureTotal + duringTotal;
}

class TeamFinance {
  final String teamId;
  String? managerId;
  double receivedDeparture;
  double receivedDuring;
  List<ReceivedMoneyEntry> receivedEntries;
  double perDiemRate;
  TeamFinance({required this.teamId, this.managerId, this.receivedDeparture = 0, this.receivedDuring = 0, List<ReceivedMoneyEntry>? receivedEntries, this.perDiemRate = 50}) : receivedEntries = receivedEntries ?? <ReceivedMoneyEntry>[];
  double get departureTotal => receivedEntries.isEmpty ? receivedDeparture : receivedEntries.where((e)=>e.kind=='departure').fold<double>(0,(a,b)=>a+b.amount);
  double get duringTotal => receivedEntries.isEmpty ? receivedDuring : receivedEntries.where((e)=>e.kind=='during').fold<double>(0,(a,b)=>a+b.amount);
  double get totalReceived => departureTotal + duringTotal;
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime createdAt;
  bool read;
  AppNotification({required this.id, required this.userId, required this.title, required this.message, required this.createdAt, this.read = false});
}

class AuditEntry {
  final String id;
  final String actor;
  final String action;
  final String target;
  final DateTime at;
  AuditEntry({required this.id, required this.actor, required this.action, required this.target, required this.at});
}

class LearningSetting {
  final String key;
  final String title;
  bool enabled;
  LearningMode mode;
  LearningSetting(this.key, this.title, {this.enabled = true, this.mode = LearningMode.manualApproval});
}

class AppSettings {
  AppThemeChoice theme = AppThemeChoice.light;
  String background = 'Fundal 1'; // compatibilitate cu setările vechi
  String brandingBackgroundId = 'default';
  String brandingLogoId = 'standard';
  double backgroundOpacity = 0.42;
  String personalBackgroundId = 'global'; // păstrat doar pentru migrarea profilurilor vechi
  String fontFamily = 'System';
  String androidDownloadUrl = '';
  String smsPreviousDayTime = '10:00';
  final Map<String, String> smsTemplates = <String, String>{
    'initial': 'Bună ziua! Echipa Andi Carpet va ajunge în locația dvs. în data de [data exactă], pentru efectuarea serviciului de curățare a mochetei. Vă mulțumim!',
    'rescheduled': 'Bună ziua! Vizita echipei Andi Carpet în locația dvs. a fost reprogramată pentru data de [data exactă]. Vă mulțumim!',
    'postponed': 'Bună ziua! Vizita echipei Andi Carpet în locația dvs., programată pentru data de [data exactă], a fost amânată. Vom reveni cu noua dată de sosire. Vă mulțumim!',
  };
  final Map<String, Map<String, String>> customBackgrounds = <String, Map<String, String>>{};
  final Map<UserFunction, Set<FunctionPermission>> functionPermissions = {
    UserFunction.driver: {FunctionPermission.viewDashboard, FunctionPermission.viewProgram, FunctionPermission.editProgram, FunctionPermission.viewMap, FunctionPermission.viewCentralizer, FunctionPermission.viewOwnDecont, FunctionPermission.viewContacts},
    UserFunction.worker: {FunctionPermission.viewDashboard, FunctionPermission.viewProgram, FunctionPermission.editProgram, FunctionPermission.viewMap, FunctionPermission.viewCentralizer, FunctionPermission.viewOwnDecont, FunctionPermission.viewContacts},
    UserFunction.developer: {FunctionPermission.viewDashboard, FunctionPermission.viewProgram, FunctionPermission.viewMap, FunctionPermission.viewCentralizer, FunctionPermission.viewOwnDecont, FunctionPermission.viewContacts},
    UserFunction.director: {...FunctionPermission.values},
  };
  double defaultPerDiem = 50;
  int notificationHistoryDays = 30;
  int backupRetentionDays = 30;
  bool automaticBackup = true;
  bool allowUndo = true;
  bool autoStart = true;
  bool autoFinish = true;
  bool autoCloseWhenAllDone = true;
  bool pushNotifications = true;
  final Map<String, LearningSetting> learning = {
    'duration': LearningSetting('duration', 'Estimări durată'),
    'routing': LearningSetting('routing', 'Rutare și ordine'),
    'access': LearningSetting('access', 'Acces și așteptare'),
    'program': LearningSetting('program', 'Modificări de grafic de lucru'),
    'ocr': LearningSetting('ocr', 'OCR financiar'),
    'finance': LearningSetting('finance', 'Decont și financiar'),
    'operations': LearningSetting('operations', 'Evenimente operaționale'),
    'conflicts': LearningSetting('conflicts', 'Conflicte offline'),
  };
}

