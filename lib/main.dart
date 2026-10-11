import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'download_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ocr_service.dart';
import 'ocr_parser.dart';
import 'mapbox_services.dart';

const MethodChannel _smsGatewayChannel = MethodChannel('andi_carpeta/sms_gateway');
const String _registerSmsGatewayUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/registerSmsGateway';
const String _disableSmsGatewayUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/disableSmsGateway';
const String _geocodeRomaniaPlaceUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/geocodeRomaniaPlace';
const String _appVersionLabel = '3.0.0+32';

const FlutterSecureStorage _quickAccountStorage = FlutterSecureStorage();
const String _quickAccountsStorageKey = 'andi_carpeta_quick_accounts_v1';

class _QuickAccount {
  final String email;
  final String password;
  const _QuickAccount({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
  static _QuickAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final email = (raw['email'] ?? '').toString().trim();
    final password = (raw['password'] ?? '').toString();
    if (email.isEmpty || password.isEmpty) return null;
    return _QuickAccount(email: email, password: password);
  }
}

Future<List<_QuickAccount>> _loadQuickAccounts() async {
  final raw = await _quickAccountStorage.read(key: _quickAccountsStorageKey);
  if (raw == null || raw.trim().isEmpty) return <_QuickAccount>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <_QuickAccount>[];
    return decoded.map(_QuickAccount.fromJson).whereType<_QuickAccount>().toList();
  } catch (_) {
    return <_QuickAccount>[];
  }
}

Future<void> _saveQuickAccounts(List<_QuickAccount> accounts) async {
  final normalized = <String, _QuickAccount>{};
  for (final account in accounts) {
    normalized[account.email.trim().toLowerCase()] = account;
  }
  final values = normalized.values.take(2).map((e) => e.toJson()).toList();
  if (values.isEmpty) {
    await _quickAccountStorage.delete(key: _quickAccountsStorageKey);
  } else {
    await _quickAccountStorage.write(key: _quickAccountsStorageKey, value: jsonEncode(values));
  }
}

String _normalizeFontChoice(String? raw) {
  final value = (raw ?? 'System').trim();
  if (value == 'Georgia' || value == 'Serif') return 'Serif';
  if (value == 'Monospace') return 'Monospace';
  if (value == 'Condensed' || value == 'Cursive') return 'Cursive';
  if (const {'Roboto','Arial','Verdana','Tahoma','Sans'}.contains(value)) return 'Sans';
  return 'System';
}

String? _resolvedFontFamily(String choice) => switch (_normalizeFontChoice(choice)) {
  // Pe Web folosim familii Windows/browser reale; numele generice CSS nu sunt
  // interpretate mereu ca fontFamily de motorul Flutter Web.
  'Sans' => kIsWeb ? 'Arial' : 'sans-serif',
  'Serif' => kIsWeb ? 'Georgia' : 'serif',
  'Monospace' => kIsWeb ? 'Courier New' : 'monospace',
  'Cursive' => kIsWeb ? 'Comic Sans MS' : 'cursive',
  _ => null,
};

const Map<String, String> _bundledBackgroundAssets = <String, String>{
  'default': 'assets/themes/fundal_1.jpg',
  'salarii_intarziate': 'assets/themes/salarii_intarziate.jpg',
  'zi_de_salariu': 'assets/themes/zi_de_salariu.jpg',
  'christmas_village': 'assets/themes/christmas_village.jpg',
  'foam_party': 'assets/themes/foam_party.jpg',
  'neon_night': 'assets/themes/neon_night.jpg',
  'easter_garden': 'assets/themes/easter_garden.jpg',
};

const Map<String, String> _bundledBackgroundLabels = <String, String>{
  'default': 'Default',
  'salarii_intarziate': 'Salarii întârziate',
  'zi_de_salariu': 'Zi de salariu',
  'christmas_village': 'Christmas Village',
  'foam_party': 'Foam Party',
  'neon_night': 'Neon Night',
  'easter_garden': 'Easter Garden',
};

const Map<String, String> _bundledLogoAssets = <String, String>{
  'standard': 'assets/logos/standard.jpg',
  'rain': 'assets/logos/rain.jpg',
  'winter': 'assets/logos/winter.jpg',
  'easter': 'assets/logos/easter.jpg',
  'christmas': 'assets/logos/christmas.jpg',
};

const Map<String, String> _bundledLogoLabels = <String, String>{
  'standard': 'Standard',
  'rain': 'Rain / Sad',
  'winter': 'Winter',
  'easter': 'Easter',
  'christmas': 'Christmas',
};

String _activeLogoAsset(AppSettings settings) =>
    _bundledLogoAssets[settings.brandingLogoId] ?? _bundledLogoAssets['standard']!;

Widget appBrandLogo(AppSettings settings, {double width = 520, double height = 130}) =>
    Image.asset(_activeLogoAsset(settings), width: width, height: height, fit: BoxFit.contain);

Future<void> _showAndroidInstallFlow(BuildContext context, AppSettings settings) async {
  final proceed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Row(children:[Icon(Icons.android),SizedBox(width:10),Expanded(child:Text('Instalare Android'))]),
    content: const Text(
      'Instalarea APK-ului Andi Carpet din afara magazinului poate necesita dezactivarea temporară a funcției Auto Blocker pe unele telefoane Samsung. '
      'De regulă: Setări → Securitate și confidențialitate → Auto Blocker. După instalare, recomandăm activarea lui din nou. '
      'Android poate cere și permisiunea de instalare pentru browserul sau aplicația din care deschizi fișierul.'
    ),
    actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:()=>Navigator.pop(c,true),icon:const Icon(Icons.download),label:const Text('Continuă la descărcare'))],
  )) ?? false;
  if (!proceed || !context.mounted) return;
  final raw=settings.androidDownloadUrl.trim();
  if(raw.isEmpty){showErrorMessage(context,'Linkul APK nu este încă publicat. Adminul îl poate adăuga din Admin Panel → Setări sistem.');return;}
  final uri=Uri.tryParse(raw);
  if(uri==null || !await launchUrl(uri,mode:LaunchMode.externalApplication)){
    if(context.mounted)showErrorMessage(context,'Linkul pentru APK nu a putut fi deschis.');
  }
}

Future<void> _showAppleInstallFlow(BuildContext context) async {
  await showDialog<void>(context:context,builder:(c)=>AlertDialog(
    title:const Row(children:[Icon(Icons.apple),SizedBox(width:10),Expanded(child:Text('Instalare pe iPhone / iPad'))]),
    content:const Text(
      'Pentru versiunea Andi Carpet disponibilă acum pe iPhone/iPad folosește varianta web instalată din Safari. '
      'Deschide aplicația în Safari → Partajare → Adaugă pe ecranul principal. Dacă opțiunea nu apare imediat, apasă „Mai multe” în meniul de partajare și caută „Adaugă pe ecranul principal”. '
      'După adăugare, aplicația se deschide din pictograma de pe ecranul principal.'
    ),
    actions:[FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Am înțeles'))],
  ));
}

class _InstallAppButtons extends StatelessWidget {
  final AppSettings settings;
  final bool compact;
  const _InstallAppButtons({required this.settings,this.compact=false});
  @override Widget build(BuildContext context)=>Wrap(
    spacing:8,runSpacing:8,alignment:WrapAlignment.center,
    children:[
      FilledButton.tonalIcon(onPressed:()=>_showAndroidInstallFlow(context,settings),icon:const Icon(Icons.android),label:Text(compact?'Android':'Instalează aplicația · Android')),
      OutlinedButton.icon(onPressed:()=>_showAppleInstallFlow(context),icon:const Icon(Icons.apple),label:Text(compact?'Apple':'Instalează aplicația · Apple')),
    ],
  );
}

const String _webPushVapidKey = String.fromEnvironment(
  'FCM_WEB_VAPID_KEY',
  defaultValue: 'BMJikC3fON4-4uwRuMOzZRXYjQCbp2ftRsSt_PcBOpf9sTCv4VkwEkzxerxSZCMd5dyooMtHhU6hvLDeqWUkFHw',
);

Future<void> _initializeFirebaseForPlatform() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && !DefaultFirebaseOptions.hasIosDartConfig) {
    // Pe iOS acceptăm configurația nativă standard GoogleService-Info.plist.
    await Firebase.initializeApp();
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await _initializeFirebaseForPlatform();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _initializeFirebaseForPlatform();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
    runApp(const AndiCarpetaApp());
  } catch (e) {
    runApp(_FirebaseBootstrapErrorApp(message: e.toString()));
  }
}

class _FirebaseBootstrapErrorApp extends StatelessWidget {
  final String message;
  const _FirebaseBootstrapErrorApp({required this.message});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_outlined, size: 58),
                const SizedBox(height: 16),
                const Text('Firebase nu este configurat pentru această platformă', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Pe iOS adaugă GoogleService-Info.plist sau construiește aplicația cu valorile FIREBASE_IOS_API_KEY și FIREBASE_IOS_APP_ID. Web și Android folosesc configurația inclusă în proiect.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                SelectableText(message, textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

// ============================================================
// ANDI CARPETĂ - aplicație operațională Flutter + Firebase
// ============================================================
// Datele operaționale sunt sincronizate prin Firestore. Harta, GPS-ul,
// PDF-urile, funcțiile dinamice și administrarea sunt integrate aici.
// ============================================================

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

String two(int n) => n.toString().padLeft(2, '0');
String formatDate(DateTime d) {
  const days = ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'];
  const months = ['ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'];
  return '${days[d.weekday - 1]}-${d.day}-${months[d.month - 1]}-${d.year}';
}
String formatMonth(DateTime d) {
  const months = ['ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'];
  return '${months[d.month - 1]}-${d.year}';
}
String timeText(DateTime? d) => d == null ? '--:--' : '${two(d.hour)}:${two(d.minute)}';
String durationText(Duration? d) {
  if (d == null) return '--';
  final mins = d.inMinutes.abs();
  return '${mins ~/ 60}h ${two(mins % 60)} min';
}
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime operationalWorkDate(DateTime now) {
  final startTonight = DateTime(now.year, now.month, now.day, 23, 30);
  if (!now.isBefore(startTonight)) {
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }
  return DateTime(now.year, now.month, now.day);
}

DateTime workWindowStart(DateTime workDate) => DateTime(workDate.year, workDate.month, workDate.day).subtract(const Duration(days: 1)).add(const Duration(hours: 23, minutes: 30));
DateTime workWindowEnd(DateTime workDate) => DateTime(workDate.year, workDate.month, workDate.day, 9, 30);
bool isInsideWorkWindow(DateTime now, DateTime workDate) => !now.isBefore(workWindowStart(workDate)) && !now.isAfter(workWindowEnd(workDate));
bool recordBelongsToWorkDate(CentralizerRecord r, DateTime workDate) {
  final t = r.startedAt ?? r.waitingStartedAt ?? r.finishedAt ?? r.waitingEndedAt;
  if (t == null) return false;
  final start = workWindowStart(workDate);
  final end = workWindowEnd(workDate).add(const Duration(hours: 3));
  return !t.isBefore(start) && !t.isAfter(end);
}

DateTime recordEventTime(CentralizerRecord r) =>
    r.finishedAt ?? r.startedAt ?? r.waitingStartedAt ?? r.waitingEndedAt ?? DateTime(1900);

class LearnedDurationEstimate {
  final Duration duration;
  final String explanation;
  final double confidence;
  final int samples;
  final String basis;
  const LearnedDurationEstimate({required this.duration, required this.explanation, required this.confidence, required this.samples, required this.basis});
}

LearnedDurationEstimate? learnedDurationEstimate(List<CentralizerRecord> records, String locationId, AppSettings settings, {DateTime? targetDate}) {
  final learning = settings.learning['duration'];
  if (learning?.enabled != true) return null;
  final target = targetDate ?? DateTime.now();
  // Folosim doar execuții efective, anterioare zilei estimate.
  // Excludem duratele imposibile și datele lipsă pentru a evita
  // contaminarea Learning-ului cu înregistrări incomplete/viitoare.
  final history = records.where((r) {
    if (r.locationId != locationId || !r.completed || !r.keptForLearning) return false;
    final duration = r.duration;
    if (duration == null || duration.inSeconds <= 0 || duration > const Duration(hours: 24)) return false;
    final event = recordEventTime(r);
    if (event.year <= 1900 || event.isAfter(target)) return false;
    return true;
  }).toList()..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
  if (history.length < 3) return null;
  final sameMonth = history.where((r) => recordEventTime(r).month == target.month).toList();
  final sameWeekday = history.where((r) => recordEventTime(r).weekday == target.weekday).toList();
  List<CentralizerRecord> selected;
  String basis;
  if (sameMonth.length >= 3) {
    selected = sameMonth;
    basis = 'aceeași lună';
  } else if (sameWeekday.length >= 3) {
    selected = sameWeekday;
    basis = 'aceeași zi a săptămânii';
  } else {
    selected = history.length > 12 ? history.sublist(history.length - 12) : history;
    basis = 'istoric recent';
  }

  var seconds = selected.map((r) => r.duration!.inSeconds).where((v) => v > 0).toList()..sort();
  if (seconds.length < 3) return null;
  if (learning!.mode == LearningMode.automatic && seconds.length >= 5) {
    // taie câte o extremă; modelul temporal rămâne stabil la seri atipice
    seconds = seconds.sublist(1, seconds.length - 1);
  }
  final total = seconds.fold<int>(0, (acc, value) => acc + value);
  final average = Duration(seconds: total ~/ seconds.length);
  final spread = seconds.length <= 1 ? 0.0 : (seconds.last - seconds.first) / average.inSeconds.clamp(1, 1 << 30);
  final sampleScore = (seconds.length / 8).clamp(0.0, 1.0).toDouble();
  final stabilityScore = (1.0 - spread.clamp(0.0, 1.0)).toDouble();
  final confidence = (sampleScore * .65 + stabilityScore * .35).clamp(0.0, 1.0).toDouble();
  final explanation = 'Estimare ${durationText(average)} din ${seconds.length} execuții ($basis). '
      '${sameMonth.length >= 3 ? 'Modelul a preferat luna ${target.month}.' : sameWeekday.length >= 3 ? 'Nu au fost 3 mostre în luna curentă; s-a folosit aceeași zi a săptămânii.' : 'Nu au fost suficiente mostre sezoniere; s-a folosit istoricul recent.'}';
  return LearnedDurationEstimate(duration: average, explanation: explanation, confidence: confidence, samples: seconds.length, basis: basis);
}

Duration? learnedAverageDuration(List<CentralizerRecord> records, String locationId, AppSettings settings, {DateTime? targetDate}) =>
    learnedDurationEstimate(records, locationId, settings, targetDate: targetDate)?.duration;

String graphDefaultName(DateTime d) => 'Grafic ${d.month.toString().padLeft(2, '0')}/${d.year}';

String idNow() => DateTime.now().microsecondsSinceEpoch.toString();

Color sectionAccent(String label) {
  final t = label.toLowerCase();
  if (t.contains('acas') || t.contains('dashboard')) return const Color(0xff2F6BFF);
  if (t.contains('program') || t.contains('grafic')) return const Color(0xff7C4DFF);
  if (t.contains('hart') || t.contains('loca')) return const Color(0xff00A884);
  if (t.contains('centraliz')) return const Color(0xffFF8A00);
  if (t.contains('decont') || t.contains('financ')) return const Color(0xff00A86B);
  if (t.contains('document')) return const Color(0xff536DFE);
  if (t.contains('profil') || t.contains('membri') || t.contains('cont')) return const Color(0xffD14D8B);
  if (t.contains('echip')) return const Color(0xff1565C0);
  if (t.contains('maș') || t.contains('mas')) return const Color(0xff546E7A);
  if (t.contains('categorie')) return const Color(0xff00897B);
  if (t.contains('func') || t.contains('drept')) return const Color(0xff8E44AD);
  if (t.contains('learning')) return const Color(0xff6D4C41);
  if (t.contains('raport')) return const Color(0xffEF6C00);
  if (t.contains('audit') || t.contains('istoric')) return const Color(0xff455A64);
  if (t.contains('backup')) return const Color(0xff3949AB);
  if (t.contains('set') || t.contains('tem')) return const Color(0xffC47B16);
  return const Color(0xff315EA8);
}

void showSuccessMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: const Color(0xff087F5B),
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
      duration: const Duration(seconds: 3),
    ));
}

void showErrorMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: const Color(0xffB42318),
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
      duration: const Duration(seconds: 4),
    ));
}

Color _plainBackgroundColor(AppSettings settings, Brightness brightness) {
  if (brightness == Brightness.dark) return const Color(0xff111318);
  return switch (settings.background) {
    'Alb simplu' => Colors.white,
    'Gri deschis' => const Color(0xffeef0f3),
    'Albastru discret' => const Color(0xffeef5fb),
    'Imagine / logo' => const Color(0xfffffbf3),
    _ => const Color(0xfff5f6f8),
  };
}

class _AppBackdrop extends StatelessWidget {
  final AppSettings settings;
  final Widget child;
  const _AppBackdrop({required this.settings, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final selected = settings.brandingBackgroundId;
    final bundledAsset = _bundledBackgroundAssets[selected];
    final customId = selected.startsWith('custom:') ? selected.substring('custom:'.length) : '';
    final customData = customId.isEmpty ? null : settings.customBackgrounds[customId];
    Uint8List? customBytes;
    if (customData != null) {
      try { customBytes = base64Decode(customData['imageBase64'] ?? ''); } catch (_) {}
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _plainBackgroundColor(settings, brightness)),
        if (bundledAsset != null)
          Positioned.fill(
            child: Opacity(
              opacity: settings.backgroundOpacity.clamp(0.0, 0.70).toDouble(),
              child: Image.asset(bundledAsset, fit: BoxFit.cover, alignment: Alignment.center),
            ),
          ),
        if (customBytes != null)
          Positioned.fill(
            child: Opacity(
              opacity: settings.backgroundOpacity.clamp(0.0, 0.70).toDouble(),
              child: Image.memory(customBytes, fit: BoxFit.cover, alignment: Alignment.center),
            ),
          ),
        // Strat subtil de contrast. Ajută textele/cardurile pe fundaluri foarte luminoase.
        if (brightness == Brightness.light)
          Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: .10))),
        Positioned.fill(child: child),
      ],
    );
  }
}

extension LocationStatusX on LocationStatus {
  String get label => switch (this) {
        LocationStatus.open => 'Locație deschisă',
        LocationStatus.temporarilyClosed => 'Închisă temporar',
        LocationStatus.permanentlyClosed => 'Închisă definitiv',
      };
  IconData get icon => switch (this) {
        LocationStatus.open => Icons.check_circle_outline,
        LocationStatus.temporarilyClosed => Icons.pause_circle_outline,
        LocationStatus.permanentlyClosed => Icons.cancel_outlined,
      };
  Color get color => switch (this) {
        LocationStatus.open => Colors.green,
        LocationStatus.temporarilyClosed => Colors.orange,
        LocationStatus.permanentlyClosed => Colors.redAccent,
      };
}

class LocationCategory {
  final String id;
  String name;
  int colorValue;
  bool active;
  LocationCategory({required this.id, required this.name, required this.colorValue, this.active = true});
  Color get color => Color(colorValue);
}

class FunctionDefinition {
  final String id;
  String name;
  String iconKey; // compatibilitate cu versiunea veche; primul ecuson devine iconKey
  List<String> badgeKeys;
  int colorValue;
  Set<String> permissions;
  bool active;
  FunctionDefinition({
    required this.id,
    required this.name,
    required this.iconKey,
    List<String>? badgeKeys,
    required this.colorValue,
    Set<String>? permissions,
    this.active = true,
  })  : badgeKeys = (badgeKeys == null || badgeKeys.isEmpty
            ? <String>[iconKey]
            : badgeKeys.where((e) => e.trim().isNotEmpty).take(3).toList()),
        permissions = permissions ?? <String>{} {
    if (this.badgeKeys.isNotEmpty) {
      iconKey = this.badgeKeys.first;
    }
  }
  Color get color => Color(colorValue);
}

const Map<String, IconData> appIconChoices = {
  'car': Icons.directions_car,
  'cleaning': Icons.cleaning_services,
  'computer': Icons.computer,
  'star': Icons.star,
  'hotel': Icons.hotel,
  'restaurant': Icons.restaurant,
  'security': Icons.security,
  'route': Icons.route,
  'payments': Icons.payments_outlined,
  'map': Icons.map_outlined,
  'person': Icons.person_outline,
  'build': Icons.build_outlined,
  'warehouse': Icons.warehouse_outlined,
};
IconData iconForKey(String key) => appIconChoices[key] ?? Icons.badge_outlined;
String iconLabel(String key) => switch (key) {
  'car' => 'Mașină', 'cleaning' => 'Aspirator / curățenie', 'computer' => 'PC', 'star' => 'Stea',
  'hotel' => 'Cazare', 'restaurant' => 'Restaurant', 'security' => 'Securitate', 'route' => 'Traseu',
  'payments' => 'Plăți', 'map' => 'Hartă', 'person' => 'Persoană', 'build' => 'Unelte', 'warehouse' => 'Depozit',
  _ => key,
};

const Map<String, String> badgeAssetChoices = {
  'badge_admin': 'assets/badges/badge_admin.png',
  'badge_ceo': 'assets/badges/badge_ceo.png',
  'badge_developer': 'assets/badges/badge_developer.png',
  'badge_driver': 'assets/badges/badge_driver.png',
  'badge_worker': 'assets/badges/badge_worker.png',
  // Alias pentru funcțiile create în pachetul anterior.
  'badge_machine': 'assets/badges/badge_worker.png',
  'badge_finance': 'assets/badges/badge_finance.png',
  'badge_documents': 'assets/badges/badge_documents.png',
  'badge_vip': 'assets/badges/badge_vip.png',
  'badge_heart': 'assets/badges/badge_heart.png',
  'badge_xyz': 'assets/badges/badge_xyz.png',
};

String badgeLabel(String key) => switch (key) {
  'badge_admin' => 'Admin',
  'badge_ceo' => 'CEO',
  'badge_developer' => '<DEV/>',
  'badge_driver' => 'Șofer',
  'badge_worker' => 'Lucrător',
  'badge_machine' => 'Lucrător',
  'badge_finance' => 'Financiar',
  'badge_documents' => 'Documente / Acte',
  'badge_vip' => 'VIP Premium',
  'badge_heart' => 'Inimă verde',
  'badge_xyz' => 'XYZ',
  _ => key,
};

const List<String> availableBadgeKeys = <String>[
  'badge_admin',
  'badge_ceo',
  'badge_developer',
  'badge_driver',
  'badge_worker',
  'badge_finance',
  'badge_documents',
  'badge_vip',
  'badge_heart',
  'badge_xyz',
];

const Map<String, String> categoryBrandAssets = {
  'million': 'assets/ui/cat_million.png',
  'magic': 'assets/ui/cat_magic.png',
  'horeca': 'assets/ui/cat_horeca.png',
  'cazari': 'assets/ui/cat_cazari.png',
};

String? sectionAssetForLabel(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized == 'acasă' || normalized == 'acasa' || normalized.contains('dashboard')) return 'assets/ui/tab_dashboard.png';
  if (normalized.contains('echipe')) return 'assets/ui/teams.png';
  if (normalized.contains('membri')) return 'assets/ui/members.png';
  if (normalized.contains('chat')) return 'assets/ui/chat_live.png';
  if (normalized == 'mesaje' || normalized.contains('contact')) return 'assets/ui/chat_live.png';
  if (normalized.contains('grafic')) return 'assets/ui/tab_grafic.png';
  if (normalized.contains('hart') || normalized.contains('loca')) return 'assets/ui/tab_harta.png';
  if (normalized.contains('centralizator') || normalized.contains('execuții') || normalized.contains('executii')) return 'assets/ui/tab_centralizator.png';
  if (normalized.contains('decont') || normalized.contains('financ')) return 'assets/ui/tab_decont.png';
  if (normalized.contains('document')) return 'assets/ui/tab_documente.png';
  if (normalized.contains('rapoarte')) return 'assets/ui/tab_centralizator.png';
  if (normalized.contains('funcții') || normalized.contains('functii') || normalized.contains('drepturi') || normalized.contains('securit')) return 'assets/ui/security.png';
  return null;
}

Widget appAssetIcon(String asset, {double size = 26, Color? accent, bool selected = false}) => Container(
  width: size + 8,
  height: size + 8,
  padding: const EdgeInsets.all(3),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: (accent ?? Colors.black12).withValues(alpha: selected ? .9 : .28), width: selected ? 1.8 : 1),
  ),
  child: Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
);

Widget sectionAssetWidget(String label, {double size = 24, Color? accent, bool selected = false, IconData? fallbackIcon}) {
  final asset = sectionAssetForLabel(label);
  if (asset != null) return appAssetIcon(asset, size: size, accent: accent, selected: selected);
  return Icon(fallbackIcon ?? Icons.apps_outlined, size: size, color: accent);
}

Widget categoryBrandWidget(String categoryId, {double size = 28, Color? fallbackColor}) {
  final asset = categoryBrandAssets[categoryId];
  if (asset != null) return appAssetIcon(asset, size: size, accent: fallbackColor);
  return CircleAvatar(radius: size / 2, backgroundColor: fallbackColor ?? Colors.blueGrey, child: const Icon(Icons.category_outlined, color: Colors.white, size: 16));
}

Widget _badgeGraphic(String asset, {required double size, Color? color}) {
  final outline = color ?? Colors.white;
  final inner = size * .88;
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.scale(
          scale: 1.08,
          child: Opacity(
            opacity: .72,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(outline, BlendMode.srcIn),
              child: Image.asset(asset, width: inner, height: inner, fit: BoxFit.contain),
            ),
          ),
        ),
        Image.asset(asset, width: inner, height: inner, fit: BoxFit.contain),
      ],
    ),
  );
}

class _InteractiveBadgeIcon extends StatefulWidget {
  final String asset;
  final double size;
  final Color? color;
  const _InteractiveBadgeIcon({required this.asset, required this.size, this.color});

  @override
  State<_InteractiveBadgeIcon> createState() => _InteractiveBadgeIconState();
}

class _InteractiveBadgeIconState extends State<_InteractiveBadgeIcon> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _pinned = false;

  double get _previewSize => math.max(74, widget.size * 2.15);

  void _showPreview({required bool pinned}) {
    _pinned = pinned;
    if (_entry == null) {
      _entry = OverlayEntry(builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              if (_pinned)
                GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hidePreview),
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topCenter,
                followerAnchor: Alignment.bottomCenter,
                offset: const Offset(0, -10),
                child: Material(
                  color: Colors.transparent,
                  child: IgnorePointer(
                    ignoring: !_pinned,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: 1,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .84),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: (widget.color ?? Colors.white).withValues(alpha: .32), width: 1.2),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 1)],
                        ),
                        child: _badgeGraphic(widget.asset, size: _previewSize, color: widget.color),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      });
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _hidePreview() {
    _pinned = false;
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hidePreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showPreview(pinned: false),
      onExit: (_) {
        if (!_pinned) _hidePreview();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_entry == null) {
            _showPreview(pinned: true);
          } else {
            _hidePreview();
          }
        },
        child: CompositedTransformTarget(
          link: _link,
          child: _badgeGraphic(widget.asset, size: widget.size, color: widget.color),
        ),
      ),
    );
  }
}

Widget functionKeyWidget(String key, {double size = 32, Color? color}) {
  final asset = badgeAssetChoices[key];
  if (asset != null) {
    return _InteractiveBadgeIcon(asset: asset, size: size, color: color ?? sectionAccent(badgeLabel(key)));
  }
  return Icon(iconForKey(key), size: size, color: color);
}

List<String> effectiveBadgeKeysForFunctionIds(List<FunctionDefinition> defs, Iterable<String> ids) {
  final out = <String>[];
  for (final id in ids) {
    final def = functionById(defs, id);
    if (def == null || !def.active) continue;
    for (final badge in def.badgeKeys) {
      if (!out.contains(badge)) out.add(badge);
      if (out.length >= 3) return out;
    }
  }
  return out;
}

Widget badgeStripWidget(Iterable<String> keys, {double size = 32, Color? color}) {
  final list = keys.where((e) => e.trim().isNotEmpty).take(3).toList();
  if (list.isEmpty) return const SizedBox.shrink();
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: list.map((key) => functionKeyWidget(key, size: size, color: color)).toList(),
  );
}

Widget memberBadgeStripWidget(List<FunctionDefinition> defs, Iterable<String> functionIds, {double size = 32}) {
  final widgets = <Widget>[];
  final seen = <String>{};
  for (final id in functionIds) {
    final def = functionById(defs, id);
    if (def == null || !def.active) continue;
    for (final badge in def.badgeKeys) {
      final normalized = badge == 'badge_machine' ? 'badge_worker' : badge;
      if (normalized == 'badge_coordinator' || !seen.add(normalized)) continue;
      widgets.add(functionKeyWidget(normalized, size: size, color: def.color));
      if (widgets.length >= 3) break;
    }
    if (widgets.length >= 3) break;
  }
  if (widgets.isEmpty) return const SizedBox.shrink();
  return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: widgets);
}

String defaultCategoryIdForType(LocationType type) => switch (type) {
  LocationType.magic => 'magic',
  LocationType.million => 'million',
  LocationType.horeca => 'horeca',
  LocationType.other => 'cazari',
};
LocationType legacyTypeForCategory(String categoryId) => switch (categoryId) {
  'magic' => LocationType.magic,
  'million' => LocationType.million,
  'horeca' => LocationType.horeca,
  _ => LocationType.other,
};
Color categoryColor(List<LocationCategory> categories, String categoryId, {LocationType? fallbackType}) {
  // Culorile de brand stabilite inițial rămân fixe peste tot în aplicație.
  if (categoryId == 'million') return Colors.red;
  if (categoryId == 'magic') return Colors.black87;
  for (final c in categories) { if (c.id == categoryId) return c.color; }
  return (fallbackType ?? legacyTypeForCategory(categoryId)).color;
}
String categoryName(List<LocationCategory> categories, String categoryId, {LocationType? fallbackType}) {
  for (final c in categories) { if (c.id == categoryId) return c.name; }
  return (fallbackType ?? legacyTypeForCategory(categoryId)).label;
}

String functionPermissionId(FunctionPermission p) => p.name;

List<LocationCategory> defaultLocationCategories() => <LocationCategory>[
  LocationCategory(id: 'million', name: 'Million', colorValue: Colors.red.value),
  LocationCategory(id: 'magic', name: 'Magic', colorValue: Colors.black87.value),
  LocationCategory(id: 'horeca', name: 'HoReCa', colorValue: Colors.amber.value),
  LocationCategory(id: 'cazari', name: 'Cazări', colorValue: Colors.indigo.value),
];

List<FunctionDefinition> defaultFunctionDefinitions() => <FunctionDefinition>[
  FunctionDefinition(
    id: 'admin',
    name: 'Admin',
    iconKey: 'badge_admin',
    badgeKeys: const <String>['badge_admin'],
    colorValue: Colors.red.value,
    permissions: FunctionPermission.values.map((e) => e.name).toSet(),
  ),
];

FunctionDefinition? functionById(List<FunctionDefinition> defs, String id) {
  for (final f in defs) { if (f.id == id) return f; }
  return null;
}

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
  final String locationId;
  final String locationNameSnapshot;
  final String addressSnapshot;
  final LocationType typeSnapshot;
  final String categoryIdSnapshot;
  int order;
  bool transferred;
  bool facadePlanned;
  ScheduleItem({required this.locationId, required this.locationNameSnapshot, required this.addressSnapshot, required this.typeSnapshot, String? categoryIdSnapshot, required this.order, this.transferred = false, this.facadePlanned = false}) : categoryIdSnapshot = categoryIdSnapshot ?? defaultCategoryIdForType(typeSnapshot);
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
  WorkSchedule({required this.id, required this.teamId, String? graphId, String? graphName, required this.date, required this.items, this.active = true, this.closed = false, this.started = false, this.paused = false, this.postponed = false, this.autoProposed = false, this.planAlertAt, this.planAlertReason = '', this.lastRecalculatedAt, this.recalculationCount = 0, this.learningExplanation = '', this.learningConfidence = 0, this.learningSamples = 0, this.departureName = '', this.departureLatitude, this.departureLongitude, this.returnName = '', this.returnLatitude, this.returnLongitude})
      : graphId = graphId ?? id,
        graphName = graphName ?? graphDefaultName(date);
}

class CentralizerRecord {
  final String id;
  final String teamId;
  final String locationId;
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
    required this.type,
    required this.locationNameSnapshot,
    required this.addressSnapshot,
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


// PATCH 63–70: validare exactă a sumelor monetare (maxim două zecimale).
// Evită rotunjirea implicită a unei sume introduse greșit.
int? parsePerDiemBani(String raw, {bool allowZero = true}) {
  final value = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final lei = int.tryParse(parts[0]);
  if (lei == null || lei > 100000000) return null;
  final bani = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final total = lei * 100 + bani;
  if (!allowZero && total == 0) return null;
  return total;
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

AppSettings? _activeAppSettingsForBranding;


Future<pw.ThemeData> _buildPdfTheme() async {
  final regular = await PdfGoogleFonts.openSansRegular();
  final bold = await PdfGoogleFonts.openSansBold();
  final italic = await PdfGoogleFonts.openSansItalic();
  return pw.ThemeData.withFont(base: regular, bold: bold, italic: italic);
}

String _safeFilePart(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _pdfDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';


/// Punctele reale ale deplasării; capetele nu sunt intervenții de lucru.
/// Un grafic incomplet GPS nu trebuie raportat ca traseu complet.
class GraphRoutePoints {
  final List<LatLng> points;
  final List<String> missingLocations;
  final bool missingDeparture;
  final bool missingDestination;
  const GraphRoutePoints(this.points, this.missingLocations,
      this.missingDeparture, this.missingDestination);
  bool get complete => !missingDeparture && !missingDestination && missingLocations.isEmpty;
}

GraphRoutePoints graphRoutePoints(List<WorkSchedule> days, List<Location> locations) {
  if (days.isEmpty) return const GraphRoutePoints([], [], true, true);
  final orderedDays = [...days]..sort((a, b) => a.date.compareTo(b.date));
  final head = orderedDays.first;
  final byId = {for (final l in locations) l.id: l};
  final points = <LatLng>[];
  final missing = <String>[];
  final missingStart = head.departureLatitude == null || head.departureLongitude == null;
  final missingEnd = head.returnLatitude == null || head.returnLongitude == null;
  if (!missingStart) points.add(LatLng(head.departureLatitude!, head.departureLongitude!));
  for (final day in orderedDays) {
    final items = [...day.items]..sort((a, b) => a.order.compareTo(b.order));
    for (final item in items) {
      final location = byId[item.locationId];
      if (location?.latitude == null || location?.longitude == null) {
        missing.add(location?.name ?? item.locationId);
        continue;
      }
      points.add(LatLng(location!.latitude!, location.longitude!));
    }
  }
  if (!missingEnd) points.add(LatLng(head.returnLatitude!, head.returnLongitude!));
  return GraphRoutePoints(points, missing, missingStart, missingEnd);
}

double estimateGraphDistanceKm(List<WorkSchedule> days, List<Location> locations) {
  final route = graphRoutePoints(days, locations);
  if (!route.complete || route.points.length < 2) return 0;
  var meters = 0.0;
  for (var i = 1; i < route.points.length; i++) {
    final a = route.points[i - 1];
    final b = route.points[i];
    meters += Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }
  return meters / 1000.0;
}

/// Distanța rutieră în kilometri, pe drumuri practicabile cu automobilul.
/// Null înseamnă că serviciul de rutare nu a putut confirma traseul.
/// Serviciul public OSRM este destinat utilizării moderate, nu garantează SLA.
/// Public Mapbox token supplied at build time. Never embed an sk.* secret here.
const String kMapboxPublicToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

String get kMapTileUrl => !kMapboxEnabled
    ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
    : 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$kMapboxPublicToken';

bool get kMapboxEnabled => kMapboxPublicToken.startsWith('pk.');
final MapboxServices _mapboxServices = MapboxServices(kMapboxPublicToken);


Future<double?> estimateGraphRoadDistanceKm(
    List<WorkSchedule> days, List<Location> locations) async {
  final route = graphRoutePoints(days, locations);
  if (!route.complete || route.points.length < 2 || route.points.length > 75) {
    return null;
  }
  // Mapbox Directions accepts up to 25 waypoints per request. Overlap
  // adjacent chunks at the boundary to preserve the entire road distance.
  if (kMapboxEnabled) {
    return _mapboxServices.drivingKm(route.points
        .map((p) => <double>[p.latitude, p.longitude]).toList());
  }

  // Development fallback when no public Mapbox token was supplied.
  final coordinates = route.points
      .map((p) => '${p.longitude},${p.latitude}')
      .join(';');
  final uri = Uri.https('router.project-osrm.org',
      '/route/v1/driving/$coordinates', {'overview': 'false', 'steps': 'false'});
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is! Map || data['code'] != 'Ok') return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final distance = routes.first['distance'];
    if (distance is! num || !distance.isFinite || distance < 0) return null;
    return distance.toDouble() / 1000.0;
  } catch (_) {
    return null;
  }
}

Future<void> downloadWorkGraphPdf({
  required Team team,
  required List<WorkSchedule> days,
  required List<Location> locations,
  required Car? car,
}) async {
  if (days.isEmpty) return;
  final theme = await _buildPdfTheme();
  final orderedDays = [...days]..sort((a, b) => a.date.compareTo(b.date));
  final first = orderedDays.first;
  final roadKm = await estimateGraphRoadDistanceKm(orderedDays, locations);
  final km = roadKm ?? estimateGraphDistanceKm(orderedDays, locations);
  final liters = car != null && car.averageConsumption > 0 ? km * car.averageConsumption / 100 : 0.0;
  final fuelCost = car != null && car.fuelPricePerLiter > 0 ? liters * car.fuelPricePerLiter : 0.0;
  final doc = pw.Document(theme: theme);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => [
      pw.Text(first.graphName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('Echipa: ${team.name}'),
      pw.Text('Perioada: ${_pdfDate(orderedDays.first.date)} - ${_pdfDate(orderedDays.last.date)}'),
      pw.SizedBox(height: 10),
      pw.Wrap(spacing: 16, runSpacing: 6, children: [
        pw.Text('Zile: ${orderedDays.length}'),
        pw.Text('Locatii: ${orderedDays.fold<int>(0, (a, b) => a + b.items.length)}'),
        if (first.departureName.isNotEmpty) pw.Text('Plecare: ${first.departureName}'),
        if (first.returnName.isNotEmpty) pw.Text('Intoarcere: ${first.returnName}'),
        pw.Text('Km traseu complet: ${!graphRoutePoints(orderedDays, locations).complete ? 'GPS incomplet' : roadKm != null ? '${km.toStringAsFixed(1)} km rutieri' : '${km.toStringAsFixed(1)} km in linie dreapta (rutare indisponibila)'}'),
        if (car != null) pw.Text('Masina: ${car.plate} ${car.makeModel}'),
        if (car != null && car.averageConsumption > 0) pw.Text('Consum: ${car.averageConsumption.toStringAsFixed(1)} l/100 km'),
        if (liters > 0) pw.Text('Carburant estimat: ${liters.toStringAsFixed(1)} l'),
        if (fuelCost > 0) pw.Text('Cost carburant estimat: ${fuelCost.toStringAsFixed(2)} lei'),
      ]),
      pw.SizedBox(height: 14),
      ...orderedDays.asMap().entries.expand((entry) {
        final dayIndex = entry.key;
        final day = entry.value;
        final orderedItems = [...day.items]..sort((a, b) => a.order.compareTo(b.order));
        return <pw.Widget>[
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text('Ziua ${dayIndex + 1} - ${_pdfDate(day.date)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          ...orderedItems.asMap().entries.map((x) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
            child: pw.Text('${x.key + 1}. ${x.value.locationNameSnapshot} - ${x.value.addressSnapshot}'),
          )),
        ];
      }),
      pw.SizedBox(height: 14),
      pw.Text('Nota: traseul include plecarea, toate locatiile si intoarcerea. Cand rutarea nu este disponibila, distanta este in linie dreapta si consumul/costul sunt doar valori minime orientative.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ],
  ));
  await downloadFile(await doc.save(), 'grafic_${_safeFilePart(first.graphName)}.pdf', mimeType: 'application/pdf');
}

Future<void> downloadCentralizerPdf({
  required LocationType type,
  required List<Location> locations,
  required List<Team> teams,
  required List<WorkSchedule> schedules,
  required List<CentralizerRecord> records,
  String? teamId,
  DateTime? from,
  DateTime? to,
  String search = '',
  WorkAttemptStatus? statusFilter,
  String? teamLabel,
}) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  final q = search.trim().toLowerCase();
  final start = from == null ? null : DateTime(from.year, from.month, from.day);
  final finish = to == null ? null : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
  bool dateAllowed(DateTime d) => (start == null || !d.isBefore(start)) && (finish == null || !d.isAfter(finish));
  bool textAllowed(String name, String address) => q.isEmpty || name.toLowerCase().contains(q) || address.toLowerCase().contains(q);

  final filteredRecords = records.where((r) {
    if (r.type != type) return false;
    if (teamId != null && teamId.isNotEmpty && r.teamId != teamId) return false;
    if (statusFilter != null && r.status != statusFilter) return false;
    final when = recordEventTime(r);
    if (!dateAllowed(when)) return false;
    if (!textAllowed(r.locationNameSnapshot, r.addressSnapshot)) return false;
    return true;
  }).toList()..sort((a,b)=>recordEventTime(a).compareTo(recordEventTime(b)));

  final rowsByLocation = <String,List<Map<String,dynamic>>>{};
  for (final r in filteredRecords) {
    rowsByLocation.putIfAbsent(r.locationId, () => <Map<String,dynamic>>[]).add({'record':r,'date':recordEventTime(r)});
  }

  // Fără filtru explicit de stare includem și toate sălile din grafice, chiar dacă nu există execuție.
  if (statusFilter == null) {
    for (final schedule in schedules) {
      if (teamId != null && teamId.isNotEmpty && schedule.teamId != teamId) continue;
      if (!dateAllowed(schedule.date)) continue;
      for (final item in schedule.items) {
        if (item.typeSnapshot != type || !textAllowed(item.locationNameSnapshot, item.addressSnapshot)) continue;
        final sameDayRecords = records.where((r) => r.locationId == item.locationId && r.teamId == schedule.teamId && recordBelongsToWorkDate(r, schedule.date)).toList();
        if (sameDayRecords.isNotEmpty) continue;
        Location? location;
        for (final l in locations) { if (l.id == item.locationId) { location = l; break; } }
        String state;
        if (item.transferred) {
          state = 'Transferată';
        } else if (location?.status == LocationStatus.temporarilyClosed) {
          state = 'Închisă temporar';
        } else if (location?.status == LocationStatus.permanentlyClosed) {
          state = 'Închisă permanent';
        } else if (schedule.date.isAfter(DateTime.now())) {
          state = 'Programată';
        } else {
          state = 'Neexecutată';
        }
        rowsByLocation.putIfAbsent(item.locationId, () => <Map<String,dynamic>>[]).add({
          'record': null,
          'date': schedule.date,
          'statusText': state,
          'teamId': schedule.teamId,
          'name': item.locationNameSnapshot,
          'address': item.addressSnapshot,
        });
      }
    }
  }

  final locationById = <String,Location>{for(final l in locations) l.id:l};
  final orderedIds = rowsByLocation.keys.toList()..sort((a,b){
    final an=locationById[a]?.name ?? rowsByLocation[a]!.first['name']?.toString() ?? a;
    final bn=locationById[b]?.name ?? rowsByLocation[b]!.first['name']?.toString() ?? b;
    return an.toLowerCase().compareTo(bn.toLowerCase());
  });
  final filters=<String>[];
  if(from!=null||to!=null)filters.add('Perioadă: ${from==null?'—':_pdfDate(from)} – ${to==null?'—':_pdfDate(to)}');
  if((teamLabel??'').isNotEmpty)filters.add('Echipă: $teamLabel');
  if(q.isNotEmpty)filters.add('Căutare: $search');
  if(statusFilter!=null)filters.add('Stare: ${statusFilter.name}');

  // PDF: distinguish planned facade work from work actually completed.
  // X = completed; P = planned but not completed; empty = not planned.
  pw.Widget facadeBox({required bool planned, required bool done}) => pw.Container(
    width: 12,
    height: 12,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: .7)),
    child: done || planned
        ? pw.Text(done ? 'X' : 'P', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))
        : null,
  );

  pw.Widget headerCell(String text, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    alignment: alignment,
    color: PdfColors.grey200,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget valueCell(String text, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    alignment: alignment,
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
  );

  pw.Widget interventionTable(List<Map<String,dynamic>> sourceRows, Location? location) {
    final rows=[...sourceRows]..sort((a,b)=>(a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: .45),
        verticalInside: const pw.BorderSide(color: PdfColors.grey300, width: .45),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(78),
        1: pw.FixedColumnWidth(50),
        2: pw.FixedColumnWidth(50),
        3: pw.FixedColumnWidth(72),
        4: pw.FixedColumnWidth(48),
      },
      children: rows.map((row) {
        final record=row['record'] is CentralizerRecord ? row['record'] as CentralizerRecord : null;
        final date=row['date'] as DateTime;
        final surface=location!=null && location.surfaceM2>0
            ? '${location.surfaceM2.toStringAsFixed(location.surfaceM2%1==0?0:1)} m²'
            : '—';
        return pw.TableRow(children:[
          valueCell(record==null ? '${_pdfDate(date)}\n${row['statusText'] ?? 'Neexecutată'}' : _pdfDate(date)),
          valueCell(record==null?'—':timeText(record.startedAt),alignment:pw.Alignment.center),
          valueCell(record==null?'—':timeText(record.finishedAt),alignment:pw.Alignment.center),
          valueCell(surface,alignment:pw.Alignment.centerRight),
          pw.Container(padding:const pw.EdgeInsets.symmetric(vertical:4),alignment:pw.Alignment.center,child:facadeBox(planned:record?.facadePlanned==true,done:record?.facadeDone==true)),
        ]);
      }).toList(),
    );
  }

  final tableHeader=pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500,width:.6),
    columnWidths: const {0: pw.FixedColumnWidth(190),1: pw.FlexColumnWidth()},
    children:[pw.TableRow(children:[
      headerCell('LOCAȚIE / ADRESĂ'),
      pw.Table(
        border: const pw.TableBorder(verticalInside: pw.BorderSide(color: PdfColors.grey500,width:.6)),
        columnWidths: const {
          0: pw.FixedColumnWidth(78),
          1: pw.FixedColumnWidth(50),
          2: pw.FixedColumnWidth(50),
          3: pw.FixedColumnWidth(72),
          4: pw.FixedColumnWidth(48),
        },
        children:[pw.TableRow(children:[
          headerCell('DATA'),
          headerCell('START',alignment:pw.Alignment.center),
          headerCell('FINAL',alignment:pw.Alignment.center),
          headerCell('SUPRAFAȚĂ',alignment:pw.Alignment.centerRight),
          headerCell('FAȚADĂ',alignment:pw.Alignment.center),
        ])],
      ),
    ])],
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children:[
        pw.Expanded(child:pw.Text('CENTRALIZATOR ${type.label.toUpperCase()}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generat: ${_pdfDate(DateTime.now())}',style:const pw.TextStyle(fontSize:8)),
      ]),
      if(filters.isNotEmpty)pw.Text(filters.join(' | '),style:const pw.TextStyle(fontSize:8)),
      pw.Text('Fațadă: X = realizată, P = planificată (nerealizată), gol = neplanificată', style: const pw.TextStyle(fontSize: 7)),
      pw.SizedBox(height:6),
      tableHeader,
      pw.SizedBox(height:3),
    ]),
    build: (_) => [
      if (orderedIds.isEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 20), child: pw.Text('Nu există săli pentru filtrele selectate.')),
      for(final id in orderedIds) ...[
        pw.Table(
          border: pw.TableBorder.all(color:PdfColors.grey500,width:.55),
          columnWidths: const {0: pw.FixedColumnWidth(190),1: pw.FlexColumnWidth()},
          children:[pw.TableRow(children:[
            pw.Container(
              padding:const pw.EdgeInsets.all(6),
              child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
                pw.Text(locationById[id]?.name ?? rowsByLocation[id]!.first['name']?.toString() ?? id,style:pw.TextStyle(fontSize:9,fontWeight:pw.FontWeight.bold)),
                pw.SizedBox(height:2),
                pw.Text(locationById[id]?.address ?? rowsByLocation[id]!.first['address']?.toString() ?? '',style:const pw.TextStyle(fontSize:7.5,color:PdfColors.grey700)),
              ]),
            ),
            interventionTable(rowsByLocation[id]!,locationById[id]),
          ])],
        ),
        pw.SizedBox(height:3),
      ],
    ],
  ));
  final bytes=await doc.save();
  final filename='centralizator_${_safeFilePart(type.label)}_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf';
  await downloadFile(bytes,filename,mimeType:'application/pdf');
}

Future<void> downloadDecontPdf({
  required Team team,
  required List<AppUser> users,
  required List<Expense> expenses,
  required List<PerDiemEntry> perDiems,
  required TeamFinance finance,
  TravelSettlement? settlement,
  bool legacyOnly = false,
}) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  bool matchesSettlement(String? id) {
    if (settlement != null) return id == settlement.id;
    if (legacyOnly) return id == null || id.isEmpty;
    return true;
  }

  // Reconcile by immutable document/transfer IDs before exporting totals.
  // A repeated Firestore snapshot must not duplicate an expense or payment.
  final expenseIds = <String>{};
  final confirmedExpenses = expenses.where((e) =>
      e.teamId == team.id && e.confirmed && e.amount.isFinite && e.amount >= 0 &&
      matchesSettlement(e.settlementId) && expenseIds.add(e.id)).toList()
    ..sort((a,b)=>a.date.compareTo(b.date));
  final paymentIds = <String>{};
  final confirmedPerDiems = perDiems.where((d) =>
      d.teamId == team.id && d.status == PerDiemStatus.confirmed &&
      d.received == true && d.actualReceivedAmount != null &&
      d.actualReceivedAmount!.isFinite && d.actualReceivedAmount! >= 0 &&
      matchesSettlement(d.settlementId) && paymentIds.add(d.id)).toList()
    ..sort((a,b)=>a.date.compareTo(b.date));
  String userName(String id) => users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: id, name: id, role: UserRole.member)).name;

  final fuelReceipts = confirmedExpenses.where((e) => e.category == 'Combustibil').toList();
  final invoices = confirmedExpenses.where((e) => e.category != 'Combustibil' && (e.documentType == ExpenseDocumentType.invoice || e.category == 'Facturi')).toList();
  final otherReceipts = confirmedExpenses.where((e) => e.category != 'Combustibil' && e.documentType != ExpenseDocumentType.invoice && e.category != 'Facturi').toList();
  final spentExpenses = confirmedExpenses.fold<double>(0, (a,b)=>a+b.amount);
  final spentPerDiem = confirmedPerDiems.fold<double>(0, (a,b)=>a+b.actualReceivedAmount!);
  final spent = spentExpenses + spentPerDiem;
  // Derive received totals from the same unique transfers shown in the PDF.
  // Legacy aggregate-only records retain their historical stored totals.
  final rawReceipts = settlement?.receivedEntries ?? finance.receivedEntries;
  final uniqueReceiptIds = <String>{};
  final uniqueReceipts = rawReceipts.where((e) => e.amount.isFinite && e.amount >= 0 &&
      uniqueReceiptIds.add(e.id)).toList();
  final receivedDeparture = rawReceipts.isEmpty
      ? (settlement?.departureTotal ?? finance.departureTotal)
      : uniqueReceipts.where((e)=>e.kind=='departure').fold<double>(0,(a,e)=>a+e.amount);
  final receivedDuring = rawReceipts.isEmpty
      ? (settlement?.duringTotal ?? finance.duringTotal)
      : uniqueReceipts.where((e)=>e.kind=='during').fold<double>(0,(a,e)=>a+e.amount);
  final totalReceived = receivedDeparture + receivedDuring;
  final budgetRemaining = math.max(0.0, totalReceived - spent).toDouble();
  final amountDue = math.max(0.0, spent - totalReceived).toDouble();
  final titleSuffix = settlement?.name ?? (legacyOnly ? 'Istoric anterior' : team.name);
  final rawEntries = settlement?.receivedEntries ?? finance.receivedEntries;
  final receiptIds = <String>{};
  final entries = rawEntries.where((e) => e.amount.isFinite && e.amount >= 0 &&
      receiptIds.add(e.id)).toList();
  final duringEntries = entries.where((e)=>e.kind=='during').toList()..sort((a,b)=>a.date.compareTo(b.date));

  String money(double value) => '${value.toStringAsFixed(2)} lei';
  String documentLabel(Expense e) => '${e.documentType == ExpenseDocumentType.invoice ? 'Factura' : 'Bon fiscal'} nr. ${e.documentNumber.trim().isEmpty ? '—' : e.documentNumber.trim()}';
  String duringSummary() {
    if (duringEntries.length <= 1) return money(receivedDuring);
    final parts = duringEntries.map((e)=>e.amount.toStringAsFixed(e.amount == e.amount.roundToDouble() ? 0 : 2)).toList();
    return '${parts.join(' + ')} = ${money(receivedDuring)}';
  }

  pw.Widget sectionTitle(String text) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 9, bottom: 3),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    color: PdfColors.grey200,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget documentTable(List<Expense> items) {
    final rows = <List<String>>[
      ['DOCUMENT', 'DATA', 'VALOARE'],
      ...items.map((e)=>[documentLabel(e), _pdfDate(e.date), money(e.amount)]),
    ];
    if (items.isEmpty) rows.add(['—', '—', '—']);
    final total = items.fold<double>(0,(a,b)=>a+b.amount);
    rows.add(['TOTAL', '', money(total)]);
    return pw.Table.fromTextArray(
      headers: null,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      cellStyle: const pw.TextStyle(fontSize: 8),
      columnWidths: const {0: pw.FlexColumnWidth(3.8), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.6)},
      cellAlignments: const {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerRight},
      rowDecoration: const pw.BoxDecoration(),
    );
  }

  final perMember = <String,List<PerDiemEntry>>{};
  for(final d in confirmedPerDiems) {
    (perMember[d.memberId] ??= <PerDiemEntry>[]).add(d);
  }
  final perDiemRows = <List<String>>[['MEMBRU', 'PLĂȚI', 'LEI / ZI', 'PRIMIT EFECTIV']];
  for(final entry in perMember.entries) {
    final list=entry.value;
    final total=list.fold<double>(0,(a,b)=>a+b.actualReceivedAmount!);
    final rate = settlement?.perDiemRate ?? finance.perDiemRate;
    perDiemRows.add([userName(entry.key), '${list.length}', money(rate), money(total)]);
  }
  if(perMember.isEmpty) perDiemRows.add(['—','—','—','—']);
  perDiemRows.add(['TOTAL DIURNE PRIMITE','','',money(spentPerDiem)]);

  final summaryRows=<List<String>>[
    ['Primit la plecare', money(receivedDeparture)],
    ['Primit în timpul deplasării', duringSummary()],
    ['Total primit', money(totalReceived)],
    ['Total cheltuit', money(spent)],
    ['Buget rămas', money(budgetRemaining)],
    ['Sumă de primit', money(amountDue)],
  ];

  final breakdownRows=<List<String>>[['TIP','DATA','DE LA CINE','METODĂ','VALOARE']];
  if(entries.isNotEmpty) {
    final sorted=[...entries]..sort((a,b)=>a.date.compareTo(b.date));
    for(final e in sorted) {
      breakdownRows.add([
        e.kind=='departure' ? 'La plecare' : 'În timpul deplasării',
        _pdfDate(e.date),
        e.fromName.trim().isEmpty ? '—' : e.fromName.trim(),
        e.method.trim().isEmpty ? '—' : e.method.trim(),
        money(e.amount),
      ]);
    }
  } else {
    if(receivedDeparture>0) breakdownRows.add(['La plecare','—','Date vechi','—',money(receivedDeparture)]);
    if(receivedDuring>0) breakdownRows.add(['În timpul deplasării','—','Date vechi','—',money(receivedDuring)]);
    if(receivedDeparture<=0 && receivedDuring<=0) breakdownRows.add(['—','—','—','—','—']);
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children:[
        pw.Expanded(child:pw.Text('DECONT · ${team.name}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generat: ${_pdfDate(DateTime.now())}',style:const pw.TextStyle(fontSize:8)),
      ]),
      pw.Text(titleSuffix, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      if (settlement != null) pw.Text('Perioada: ${_pdfDate(settlement.startDate)}${settlement.endDate == null ? '' : ' - ${_pdfDate(settlement.endDate!)}'}',style:const pw.TextStyle(fontSize:8)),
      pw.SizedBox(height:5),
    ]),
    build: (_) => [
      sectionTitle('1. BONURI COMBUSTIBIL'),
      documentTable(fuelReceipts),
      sectionTitle('2. FACTURI'),
      documentTable(invoices),
      sectionTitle('3. DIURNE'),
      pw.Table.fromTextArray(
        headers:null,
        data:perDiemRows,
        border:pw.TableBorder.all(color:PdfColors.grey400,width:.5),
        cellPadding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:3),
        cellStyle:const pw.TextStyle(fontSize:8),
        columnWidths:const {0:pw.FlexColumnWidth(3),1:pw.FlexColumnWidth(1.2),2:pw.FlexColumnWidth(1.4),3:pw.FlexColumnWidth(1.5)},
        cellAlignments:const {0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerRight,3:pw.Alignment.centerRight},
      ),
      sectionTitle('4. ALTE CHELTUIELI'),
      documentTable(otherReceipts),
      sectionTitle('REZUMAT'),
      pw.Table.fromTextArray(
        headers:null,
        data:summaryRows,
        border:pw.TableBorder.all(color:PdfColors.grey400,width:.5),
        cellPadding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:3.5),
        cellStyle:const pw.TextStyle(fontSize:8.5),
        columnWidths:const {0:pw.FlexColumnWidth(2.7),1:pw.FlexColumnWidth(3.3)},
        cellAlignments:const {0:pw.Alignment.centerLeft,1:pw.Alignment.centerRight},
      ),
      sectionTitle('DESFĂȘURĂTOR SUME PRIMITE'),
      pw.Table.fromTextArray(
        headers:null,
        data:breakdownRows,
        border:pw.TableBorder.all(color:PdfColors.grey400,width:.5),
        cellPadding:const pw.EdgeInsets.symmetric(horizontal:4,vertical:3),
        cellStyle:const pw.TextStyle(fontSize:7.5),
        columnWidths:const {0:pw.FlexColumnWidth(2),1:pw.FlexColumnWidth(1.3),2:pw.FlexColumnWidth(2.3),3:pw.FlexColumnWidth(1.3),4:pw.FlexColumnWidth(1.5)},
        cellAlignments:const {0:pw.Alignment.centerLeft,1:pw.Alignment.center,2:pw.Alignment.centerLeft,3:pw.Alignment.center,4:pw.Alignment.centerRight},
      ),
      pw.SizedBox(height:6),
      pw.Text('Notă: fotografiile bonurilor și facturilor nu sunt păstrate în decont; OCR-ul salvează numai datele structurate necesare.',style:const pw.TextStyle(fontSize:7,color:PdfColors.grey700)),
    ],
  ));
  final bytes = await doc.save();
  final filename = 'decont_${_safeFilePart(team.name)}_${_safeFilePart(titleSuffix)}_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf';
  await downloadFile(bytes, filename, mimeType: 'application/pdf');
}

Future<void> downloadAuditPdf(List<AuditEntry> audit) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('RAPORT AUDIT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Generat: ${_pdfDate(DateTime.now())}'),
      pw.Divider(),
    ]),
    build: (_) => [
      for (final a in audit)
        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5), child: pw.Text('${formatDate(a.at)} ${timeText(a.at)} · ${a.actor} · ${a.action} · ${a.target}', style: const pw.TextStyle(fontSize: 8))),
    ],
  ));
  await downloadFile(await doc.save(), 'audit_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf', mimeType: 'application/pdf');
}

Future<void> downloadFinancialSummaryPdf({
  required List<Team> teams,
  required List<Expense> expenses,
  required List<PerDiemEntry> perDiems,
  required List<TeamFinance> finances,
  required List<TravelSettlement> settlements,
}) async {
  final theme = await _buildPdfTheme();
  final doc = pw.Document();
  TeamFinance financeFor(String teamId) => finances.firstWhere((f) => f.teamId == teamId, orElse: () => TeamFinance(teamId: teamId));
  pw.Widget financeRow(Team team) {
    final ex = expenses.where((e) => e.teamId == team.id && e.confirmed).fold<double>(0, (a,b)=>a+b.amount);
    final di = perDiems.where((d) => d.teamId == team.id && d.status == PerDiemStatus.confirmed && d.received == true && d.actualReceivedAmount != null).fold<double>(0, (a,b)=>a+b.actualReceivedAmount!);
    final f = financeFor(team.id);
    final tripReceived = settlements.where((x) => x.teamId == team.id).fold<double>(0, (a,b) => a + b.totalReceived);
    final totalReceived = f.totalReceived + tripReceived;
    return pw.Text('Primit ${totalReceived.toStringAsFixed(2)} lei · Cheltuieli ${(ex+di).toStringAsFixed(2)} lei · Sold ${(totalReceived-ex-di).toStringAsFixed(2)} lei · ${settlements.where((x)=>x.teamId==team.id).length} deplasări', style: const pw.TextStyle(fontSize: 9));
  }
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('RAPORT FINANCIAR GENERAL', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Generat: ${_pdfDate(DateTime.now())}'),
      pw.Divider(),
    ]),
    build: (_) => [
      for (final team in teams) ...[
        pw.SizedBox(height: 10),
        pw.Text(team.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        financeRow(team),
      ],
    ],
  ));
  await downloadFile(await doc.save(), 'raport_financiar_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}.pdf', mimeType: 'application/pdf');
}

class AndiCarpetaApp extends StatefulWidget {
  const AndiCarpetaApp({super.key});
  @override State<AndiCarpetaApp> createState() => _AndiCarpetaAppState();
}

class _AndiCarpetaAppState extends State<AndiCarpetaApp> {
  final settings = AppSettings();
  @override
  Widget build(BuildContext context) {
    _activeAppSettingsForBranding = settings;
    final mode = switch (settings.theme) { AppThemeChoice.light => ThemeMode.light, AppThemeChoice.dark => ThemeMode.dark, AppThemeChoice.system => ThemeMode.system };
    return MaterialApp(
      title: 'Andi Carpetă',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: AuthGate(settings: settings, onSettingsChanged: () => setState(() {})),
    );
  }
  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xff315EA8), brightness: b);
    final dark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: _resolvedFontFamily(settings.fontFamily),
      scaffoldBackgroundColor: Colors.transparent,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          side: BorderSide(color: scheme.outline.withValues(alpha: .55)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surfaceContainerHighest.withValues(alpha: .92) : Colors.white.withValues(alpha: .99),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .75))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.error, width: 1.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface.withValues(alpha: .97),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      ),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface.withValues(alpha: .985),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outlineVariant),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outline),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface.withValues(alpha: .95),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: .55)),
    );
  }
}


class FirebaseUserProfile {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool active;
  final String status;
  final UserFunction function;
  final List<String> functionIds;

  const FirebaseUserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.status,
    required this.function,
    required this.functionIds,
  });

  bool get isAdmin => role == 'admin';

  static UserFunction _functionFrom(String? value, String role) {
    if (role == 'admin') return UserFunction.director;
    return switch (value) {
      'driver' => UserFunction.driver,
      'developer' => UserFunction.developer,
      'director' => UserFunction.director,
      _ => UserFunction.worker,
    };
  }

  factory FirebaseUserProfile.fromSnapshot(User authUser, DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    final role = (data['role'] ?? 'member').toString();
    final email = (data['email'] ?? authUser.email ?? '').toString();
    var name = (data['name'] ?? '').toString().trim();
    final nickname = (data['nickname'] ?? '').toString().trim();
    final useNickname = data['useNickname'] == true;
    if (useNickname && nickname.isNotEmpty) name = nickname;
    if (name.isEmpty) name = role == 'admin' ? 'Administrator' : (email.isEmpty ? 'Utilizator' : email.split('@').first);
    return FirebaseUserProfile(
      uid: authUser.uid,
      name: name,
      email: email,
      role: role,
      active: data['active'] == true,
      status: (data['status'] ?? (data['active'] == true ? 'approved' : 'pending')).toString(),
      function: _functionFrom(data['function']?.toString(), role),
      functionIds: data['functionIds'] is List
          ? (data['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : <String>[(role == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList(),
    );
  }
}

class AuthGate extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  const AuthGate({super.key, required this.settings, required this.onSettingsChanged});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _uiSettingsSubscription;

  User? _user;
  FirebaseUserProfile? _profile;
  String? _profileUid;
  String? _error;
  bool _authInitialized = false;
  bool _profileInitialized = false;

  @override
  void initState() {
    super.initState();

    _uiSettingsSubscription = FirebaseFirestore.instance.collection('meta').doc('uiSettings').snapshots().listen((snap) {
      final d = snap.data();
      if (d == null || !mounted) return;
      var changed = false;
      final bg = (d['brandingBackgroundId'] ?? widget.settings.brandingBackgroundId).toString();
      final logo = (d['brandingLogoId'] ?? widget.settings.brandingLogoId).toString();
      final apkUrl = (d['androidDownloadUrl'] ?? widget.settings.androidDownloadUrl).toString();
      final opacity = d['backgroundOpacity'] is num
          ? (d['backgroundOpacity'] as num).toDouble().clamp(0.0, .70).toDouble()
          : widget.settings.backgroundOpacity;
      if (bg != widget.settings.brandingBackgroundId) { widget.settings.brandingBackgroundId = bg; changed = true; }
      if (logo != widget.settings.brandingLogoId) { widget.settings.brandingLogoId = logo; changed = true; }
      if (apkUrl != widget.settings.androidDownloadUrl) { widget.settings.androidDownloadUrl = apkUrl; changed = true; }
      if (opacity != widget.settings.backgroundOpacity) { widget.settings.backgroundOpacity = opacity; changed = true; }
      if (changed) {
        widget.onSettingsChanged();
        setState(() {});
      }
    });

    // Folosim currentUser imediat, astfel încât Chrome/PWA să nu afișeze
    // splash-ul între refaceri de widget / reconectări scurte ale streamului.
    _user = FirebaseAuth.instance.currentUser;
    _authInitialized = true;
    if (_user != null) {
      _listenProfile(_user!);
    }

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = 'Autentificare: $e');
      },
    );
  }

  void _handleAuthChange(User? eventUser) {
    if (!mounted) return;

    // Unele versiuni Chrome/PWA pot emite o stare intermediară în timp ce
    // Firebase își reface persistența. Dacă Firebase încă are currentUser,
    // păstrăm sesiunea activă și NU revenim la splash/login.
    final effectiveUser = eventUser ?? FirebaseAuth.instance.currentUser;

    if (effectiveUser == null) {
      _profileSubscription?.cancel();
      _profileSubscription = null;
      setState(() {
        _authInitialized = true;
        _user = null;
        _profile = null;
        _profileUid = null;
        _profileInitialized = false;
        _error = null;
      });
      return;
    }

    final changedUser = _user?.uid != effectiveUser.uid;
    _user = effectiveUser;
    _authInitialized = true;
    _error = null;

    if (changedUser || _profileUid != effectiveUser.uid || _profileSubscription == null) {
      _listenProfile(effectiveUser);
    } else {
      // Nu chemăm setState inutil dacă avem deja profilul activ.
      if (_profile == null && mounted) setState(() {});
    }
  }

  void _listenProfile(User user) {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _profileUid = user.uid;
    _profileInitialized = false;

    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      if (!mounted || _user?.uid != user.uid) return;

      // Snapshot-urile din cache sunt perfect valide pentru UI. Nu revenim
      // la ecranul de încărcare cât timp avem deja un profil bun memorat.
      if (!snap.exists) {
        setState(() {
          _profileInitialized = true;
          _profile = null;
          _error = null;
        });
        return;
      }

      final next = FirebaseUserProfile.fromSnapshot(user, snap);
      setState(() {
        _profileInitialized = true;
        _profile = next;
        _error = null;
      });
    }, onError: (Object e) {
      if (!mounted || _user?.uid != user.uid) return;
      // Dacă aveam deja profil valid, păstrăm interfața și nu pâlpâim spre
      // pagina de eroare la o reconectare scurtă. Arătăm eroarea doar la
      // încărcarea inițială când nu avem nimic utilizabil.
      if (_profile != null) return;
      setState(() {
        _profileInitialized = true;
        _error = 'Nu am putut citi profilul: $e';
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _uiSettingsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authInitialized) {
      return _FirebaseLoading(text: 'Se verifică autentificarea...', settings: widget.settings);
    }

    final user = _user ?? FirebaseAuth.instance.currentUser;
    if (user == null) return LoginPage(settings: widget.settings);

    if (_error != null && _profile == null) {
      return _FirebaseError(message: _error!);
    }

    // Profilul este singura încărcare pentru care acceptăm splash, și doar
    // la prima deschidere reală a sesiunii. După aceea UI-ul rămâne montat.
    if (!_profileInitialized && _profile == null) {
      return _FirebaseLoading(text: 'Se încarcă profilul...', settings: widget.settings);
    }

    final profile = _profile;
    if (profile == null) {
      return MissingProfilePage(email: user.email ?? '');
    }
    if (!profile.active) return PendingApprovalPage(profile: profile, settings: widget.settings);

    return HomePage(
      key: ValueKey(profile.uid),
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
      profile: profile,
    );
  }
}

class _FirebaseLoading extends StatelessWidget {
  final String text;
  final AppSettings settings;
  const _FirebaseLoading({required this.text, required this.settings});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    appBrandLogo(settings, width: 520, height: 130),
    const SizedBox(height: 24),
    const CircularProgressIndicator(),
    const SizedBox(height: 12),
    Text(text),
  ])));
}

class _FirebaseError extends StatelessWidget {
  final String message;
  const _FirebaseError({required this.message});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 48),
    const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center),
    const SizedBox(height: 12),
    FilledButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Ieși din cont')),
  ]))));
}

class LoginPage extends StatefulWidget {
  final AppSettings settings;
  const LoginPage({super.key, required this.settings});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final name = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  bool createMode = false;
  bool busy = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); confirmPassword.dispose(); name.dispose(); username.dispose(); phone.dispose(); super.dispose(); }

  String _friendly(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-credential' => 'Emailul sau parola nu sunt corecte.',
        'user-not-found' => 'Nu există un cont cu acest email.',
        'wrong-password' => 'Parola nu este corectă.',
        'email-already-in-use' => 'Există deja un cont cu acest email.',
        'weak-password' => 'Parola este prea slabă. Folosește minimum 6 caractere.',
        'invalid-email' => 'Adresa de email nu este validă.',
        'too-many-requests' => 'Prea multe încercări. Încearcă din nou puțin mai târziu.',
        _ => e.message ?? 'A apărut o eroare de autentificare.',
      };
    }
    return e.toString();
  }

  String _normalizePhone(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  Future<String> _resolveLoginIdentifier(String identifier, String pass) async {
    if (identifier.contains('@')) return identifier.trim();
    final uri = Uri.parse('https://europe-central2-andicarpet-e777e.cloudfunctions.net/resolveLoginAlias');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier.trim(), 'password': pass}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw FirebaseAuthException(code: 'invalid-credential', message: 'Date de autentificare incorecte.');
    }
    final data = jsonDecode(response.body);
    final resolved = data is Map ? (data['email'] ?? '').toString().trim() : '';
    if (resolved.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential', message: 'Date de autentificare incorecte.');
    }
    return resolved;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final identifier = email.text.trim();
    final pass = password.text;
    final requestedUsername = username.text.trim().toLowerCase();
    final requestedPhone = phone.text.trim();
    if (identifier.isEmpty || pass.isEmpty || (createMode && (name.text.trim().isEmpty || requestedUsername.isEmpty))) {
      setState(() => error = 'Completează toate câmpurile obligatorii.');
      return;
    }
    if (createMode && !RegExp(r'^[a-zA-Z0-9._-]{3,30}$').hasMatch(requestedUsername)) {
      setState(() => error = 'Username-ul trebuie să aibă 3–30 caractere: litere, cifre, punct, _ sau - .');
      return;
    }
    if (createMode && requestedPhone.isNotEmpty && _normalizePhone(requestedPhone).length < 8) {
      setState(() => error = 'Numărul de telefon nu pare complet.');
      return;
    }
    if (createMode && pass != confirmPassword.text) {
      setState(() => error = 'Parolele nu coincid.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      if (createMode) {
        final mail = identifier;
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: mail, password: pass);
        final user = credential.user!;
        await user.updateDisplayName(name.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name.text.trim(),
          'email': mail,
          'username': requestedUsername,
          'usernameNormalized': requestedUsername,
          'phone': requestedPhone,
          'phoneNormalized': _normalizePhone(requestedPhone),
          'role': 'member',
          'function': '',
          'functionIds': const <String>[],
          'effectivePermissions': const <String>[],
          'active': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final resolvedEmail = await _resolveLoginIdentifier(identifier, pass);
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: resolvedEmail, password: pass);
        TextInput.finishAutofillContext(shouldSave: true);
      }
    } catch (e) {
      if (mounted) setState(() => error = _friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final mail = email.text.trim();
    if (mail.isEmpty || !mail.contains('@')) { setState(() => error = 'Pentru resetarea parolei scrie adresa de email a contului.'); return; }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emailul pentru resetarea parolei a fost trimis.')));
    } catch (e) { if (mounted) setState(() => error = _friendly(e)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AppBackdrop(
        settings: widget.settings,
        child: Container(
          color: Colors.black.withValues(alpha: 0.22),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Card(
                    elevation: 12,
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        appBrandLogo(widget.settings, width: 520, height: 130),
                        const SizedBox(height: 12),
                        _InstallAppButtons(settings:widget.settings),
                        const SizedBox(height: 20),
                        Text(createMode ? 'Creează cont' : 'Autentificare', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(createMode ? 'Contul nou va aștepta aprobarea Administratorului.' : 'Andi Carpetă · acces securizat'),
                        const SizedBox(height: 20),
                        if (createMode) ...[
                          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nume și prenume', prefixIcon: Icon(Icons.person_outline))),
                          const SizedBox(height: 12),
                          TextField(controller: username, autocorrect: false, textCapitalization: TextCapitalization.none, decoration: const InputDecoration(labelText: 'Username', hintText: 'ex: timi', prefixIcon: Icon(Icons.alternate_email))),
                          const SizedBox(height: 12),
                          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon (opțional)', prefixIcon: Icon(Icons.phone_outlined))),
                          const SizedBox(height: 12),
                        ],
                        TextField(controller: email, keyboardType: createMode ? TextInputType.emailAddress : TextInputType.text, autocorrect: false, textCapitalization: TextCapitalization.none, autofillHints: const [AutofillHints.username, AutofillHints.email], decoration: InputDecoration(labelText: createMode ? 'Email' : 'Email / username / telefon', prefixIcon: Icon(createMode ? Icons.email_outlined : Icons.account_circle_outlined))),
                        const SizedBox(height: 12),
                        TextField(controller: password, obscureText: obscure, autofillHints: const [AutofillHints.password], onSubmitted: (_) => createMode ? null : _submit(), decoration: InputDecoration(labelText: 'Parolă', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)))),
                        if (createMode) ...[
                          const SizedBox(height: 12),
                          TextField(controller: confirmPassword, obscureText: obscure, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Confirmă parola', prefixIcon: Icon(Icons.lock_reset))),
                        ],
                        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)),
                        const SizedBox(height: 18),
                        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : _submit, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(createMode ? Icons.person_add_alt_1 : Icons.login), label: Text(createMode ? 'Creează contul' : 'Intră în cont'))),
                        if (!createMode) TextButton(onPressed: busy ? null : _resetPassword, child: const Text('Am uitat parola')),
                        const Divider(height: 28),
                        TextButton(onPressed: busy ? null : () => setState(() { createMode = !createMode; error = null; }), child: Text(createMode ? 'Am deja cont · Autentificare' : 'Nu am cont · Creează cont')),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PendingApprovalPage extends StatelessWidget {
  final FirebaseUserProfile profile;
  final AppSettings settings;
  const PendingApprovalPage({super.key, required this.profile, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AppBackdrop(
        settings: settings,
        child: Container(
          color: Colors.black.withValues(alpha: .26),
          child: Center(
            child: Card(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      appBrandLogo(settings, width: 500, height: 125),
                      const SizedBox(height: 22),
                      const Icon(Icons.hourglass_top, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Cont în așteptare',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('${profile.name}\n${profile.email}', textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      const Text(
                        'Contul a fost creat. Administratorul trebuie să îl activeze și să îi atribuie funcția înainte de acces.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Ieși din cont'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MissingProfilePage extends StatelessWidget {
  final String email;
  const MissingProfilePage({super.key, required this.email});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.manage_accounts_outlined, size: 52),
    const SizedBox(height: 12),
    const Text('Contul există în Authentication, dar profilul Firestore lipsește.', textAlign: TextAlign.center),
    if (email.isNotEmpty) Text(email),
    const SizedBox(height: 16),
    OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Ieși din cont')),
  ]))));
}

class HomePage extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final FirebaseUserProfile profile;
  const HomePage({super.key, required this.settings, required this.onSettingsChanged, required this.profile});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  late final String currentUserId;
  AppSettings get settings => widget.settings;
  late final List<AppUser> users;
  late final List<Team> teams;
  late final List<Car> cars;
  late final List<Location> locations;
  final categories = <LocationCategory>[];
  final functionDefinitions = <FunctionDefinition>[];
  final schedules = <WorkSchedule>[];
  final records = <CentralizerRecord>[];
  final expenses = <Expense>[];
  final perDiems = <PerDiemEntry>[];
  final finances = <TeamFinance>[];
  final settlements = <TravelSettlement>[];
  final notifications = <AppNotification>[];
  final audit = <AuditEntry>[];
  final Set<String> _hiddenUserIds = <String>{};
  Timer? _liveLocationTimer;
  StreamSubscription<Position>? _backgroundLocationSubscription;
  Position? _lastSharedPosition;
  DateTime? _lastSharedAt;
  String _personalLocationMode = 'economic';
  int _personalLocationIntervalMinutes = 10;
  final Map<String,bool> _personalNotificationPreferences=<String,bool>{
    'chat':true,'schedule':true,'arrival':true,'decont':true,'learning':true,'general':true,
  };
  bool _offlineLocationCleared = false;
  bool _permissionSyncInFlight = false;
  bool _automaticBackupInFlight = false;
  final Map<String, DateTime> _autoInsideSince = <String, DateTime>{};
  final Map<String, DateTime> _autoOutsideSince = <String, DateTime>{};
  final Map<String, DateTime> _arrivalSnoozedUntil = <String, DateTime>{};
  final Map<String, int> _arrivalPromptCounts = <String, int>{};
  final Set<String> _automationNotified = <String>{};
  bool _arrivalDialogOpen = false;
  bool _nativeLocationProximityBoost = false;
  final Set<String> _knownNotificationIds = <String>{};
  final Set<String> _knownIncomingMessageIds = <String>{};
  final Set<String> _knownGroupMessageIds = <String>{};
  bool _notificationsPrimed = false;
  bool _messagesPrimed = false;
  bool _groupMessagesPrimed = false;
  int _unreadPrivateMessageCount = 0;
  int _unreadGroupMessageCount = 0;
  int _unreadMessageCount = 0;
  DateTime? _lastGroupChatSeenAt;
  List<QueryDocumentSnapshot<Map<String,dynamic>>> _recentGroupDocs = <QueryDocumentSnapshot<Map<String,dynamic>>>[];
  bool _pushInitializationInFlight = false;
  bool _pushListenersAttached = false;
  bool _pushPermissionDialogShown = false;
  String _lastLiveLocalityLabel = '';
  DateTime? _lastLiveLocalityResolvedAt;
  Position? _lastLiveLocalityPosition;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.profile.uid;
    final current = AppUser(
      id: widget.profile.uid,
      name: widget.profile.name,
      role: widget.profile.isAdmin ? UserRole.director : UserRole.member,
      function: widget.profile.function,
      functionIds: widget.profile.functionIds,
      teamId: null,
      email: widget.profile.email,
      active: widget.profile.active,
      photoBase64: '',
    );
    users = [current];
    teams = [];
    cars = [];
    locations = _seedLocations();
    categories.addAll(defaultLocationCategories());
    functionDefinitions.addAll(defaultFunctionDefinitions());
    _startCoreSync();
    _startAdaptiveLiveLocation();
    unawaited(_initPushNotifications());
  }

  void _showIncomingPopup({required String title, required String body, VoidCallback? onView}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff1F2937),
          duration: const Duration(seconds: 7),
          content: Row(children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              if (body.trim().isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
            ])),
          ]),
          action: onView == null ? null : SnackBarAction(label: 'VEZI', textColor: Colors.white, onPressed: onView),
        ));
    });
  }

  Future<void> _openChatFromAlert(String otherUserId) async {
    if (!mounted || otherUserId.trim().isEmpty || otherUserId == currentUserId) return;
    if (!isAdmin && _hiddenUserIds.contains(otherUserId)) return;
    try {
      final snap = await FirebaseFirestore.instance.collection(isAdmin ? 'users' : 'memberDirectory').doc(otherUserId).get();
      if (!mounted) return;
      final d = snap.data() ?? <String, dynamic>{};
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrivateChatPage(
        currentUser: me,
        otherUserId: otherUserId,
        otherName: (d['name'] ?? d['email'] ?? 'Membru').toString(),
        otherPhotoBase64: (d['photoBase64'] ?? '').toString(),
      )));
    } catch (_) {
      if (mounted) _openMembersDirectory();
    }
  }

  String _pushTokenDocId(String token) => base64UrlEncode(utf8.encode(token)).replaceAll('=', '');

  Future<void> _savePushToken(String token) async {
    if (token.trim().isEmpty) return;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    await FirebaseFirestore.instance
        .collection('users').doc(currentUserId)
        .collection('pushTokens').doc(_pushTokenDocId(token))
        .set({
          'token': token,
          'platform': platform,
          'deviceOwnerUid': currentUserId,
          'active': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _offerPushPermissionAutomatically() {
    if (_pushPermissionDialogShown || !mounted) return;
    _pushPermissionDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.notifications_active_outlined),
            SizedBox(width: 10),
            Expanded(child: Text('Activează notificările')),
          ]),
          content: const Text(
            'Andi Carpetă îți va înregistra automat acest dispozitiv pentru notificări. '
            'Trebuie doar să confirmi o singură dată permisiunea sistemului. După aceea nu mai este nevoie de „Reînregistrează dispozitivul”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Mai târziu'),
            ),
            FilledButton.icon(
              onPressed: () {
                // Important pentru Web/iOS: requestPermission trebuie pornit direct
                // din gestul utilizatorului. Pornim înainte de a închide dialogul.
                unawaited(_initPushNotifications(fromUserGesture: true));
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Activează'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _initPushNotifications({bool fromUserGesture = false}) async {
    if (_pushInitializationInFlight) return;
    _pushInitializationInFlight = true;
    try {
      final messaging = FirebaseMessaging.instance;

      NotificationSettings permission;
      if (kIsWeb && fromUserGesture) {
        // Pe Web (inclusiv PWA iPhone), cererea trebuie lansată direct dintr-un
        // gest al utilizatorului. Nu facem niciun await înainte de apelul acesta.
        permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
      } else {
        permission = await messaging.getNotificationSettings();
        if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
          if (kIsWeb) {
            // Nu cerem utilizatorului să intre în Profil. Afișăm automat dialogul
            // de activare, iar după tap tokenul este creat și salvat singur.
            _offerPushPermissionAutomatically();
            return;
          }
          permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
        }
      }

      if (permission.authorizationStatus == AuthorizationStatus.denied ||
          permission.authorizationStatus == AuthorizationStatus.deniedPermanently) {
        debugPrint('[push] Permisiunea pentru notificări este refuzată.');
        return;
      }
      if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (kIsWeb) _offerPushPermissionAutomatically();
        return;
      }

      if (kIsWeb) {
        if (_webPushVapidKey.trim().isEmpty) {
          debugPrint('[push] FCM_WEB_VAPID_KEY lipsește din build.');
          return;
        }
        // După acordarea permisiunii, dăm service worker-ului o clipă să fie gata.
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _webPushVapidKey)
          : await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[push] Firebase Messaging nu a returnat un token.');
        return;
      }

      await _savePushToken(token);
      debugPrint('[push] Token FCM înregistrat AUTOMAT și salvat pentru $currentUserId.');

      if (!_pushListenersAttached) {
        _pushListenersAttached = true;
        _coreSubscriptions.add(messaging.onTokenRefresh.listen(
          (value) => unawaited(_savePushToken(value)),
          onError: (Object error) => debugPrint('[push] onTokenRefresh: $error'),
        ));
        _coreSubscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final type = (message.data['type'] ?? '').toString();
          if (type == 'chat') {
            final senderId = (message.data['senderId'] ?? '').toString();
            if (senderId.isNotEmpty) unawaited(_openChatFromAlert(senderId));
          }
        }));
      }

      final initial = await messaging.getInitialMessage();
      if (initial != null && (initial.data['type'] ?? '').toString() == 'chat') {
        final senderId = (initial.data['senderId'] ?? '').toString();
        if (senderId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_openChatFromAlert(senderId)));
        }
      }
    } catch (e, st) {
      debugPrint('[push] Inițializarea FCM a eșuat: $e');
      debugPrintStack(stackTrace: st);
      // Butonul din Profil rămâne doar ca diagnostic/fallback. Înregistrarea
      // normală se face automat la fiecare pornire/login.
    } finally {
      _pushInitializationInFlight = false;
    }
  }

  void _startAdaptiveLiveLocation() {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    _backgroundLocationSubscription?.cancel();
    _backgroundLocationSubscription = null;
    unawaited(_shareLiveLocationIfAllowed());
    if (kIsWeb) {
      // Browserele/PWA pot suspenda complet execuția când aplicația este închisă.
      // Cât timp pagina rulează folosim intervalul adaptiv de mai jos.
      _liveLocationTimer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_shareLiveLocationIfAllowed()));
      return;
    }
    unawaited(_startNativeBackgroundLocationStream());
  }

  Future<void> _startNativeBackgroundLocationStream() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      await _backgroundLocationSubscription?.cancel();
      _backgroundLocationSubscription = null;

      // Mod economic: cât timp suntem departe de următoarea sală folosim mai puține
      // actualizări. La apropierea de traseul activ activăm temporar precizia ridicată.
      final economical = _personalLocationMode == 'economic' && !_nativeLocationProximityBoost;
      LocationSettings settings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: economical ? LocationAccuracy.medium : LocationAccuracy.high,
          distanceFilter: economical ? 60 : 10,
          intervalDuration: economical ? const Duration(minutes: 1) : const Duration(seconds: 20),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: 'Andi Carpetă · locație activă',
            notificationText: economical
                ? 'Localizare economică activă. Precizia crește automat lângă următoarea sală.'
                : 'Te apropii de o locație programată. Detectarea sosirii este activă.',
            enableWakeLock: !economical,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        settings = AppleSettings(
          accuracy: economical ? LocationAccuracy.medium : LocationAccuracy.high,
          distanceFilter: economical ? 60 : 10,
          pauseLocationUpdatesAutomatically: economical,
          showBackgroundLocationIndicator: true,
        );
      } else {
        settings = LocationSettings(
          accuracy: economical ? LocationAccuracy.medium : LocationAccuracy.high,
          distanceFilter: economical ? 60 : 10,
        );
      }
      _backgroundLocationSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) => unawaited(_shareLiveLocationIfAllowed(position)),
        onError: (Object e) => debugPrint('[location] Background stream: $e'),
      );
    } catch (e) {
      debugPrint('[location] Nu am putut porni tracking-ul nativ în background: $e');
    }
  }

  void _updateNativeLocationProximityBoost(Position p, DateTime workDate) {
    if (kIsWeb || _personalLocationMode != 'economic') return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty) return;
    final active = schedules.where((s) => s.teamId == teamId && sameDay(s.date, workDate) && s.started && !s.closed && !s.paused && !s.postponed).toList();
    var nearest = double.infinity;
    for (final schedule in active) {
      for (final item in schedule.items) {
        final r = _homeLatestRecord(teamId, item.locationId, workDate);
        if (r?.status == WorkAttemptStatus.completed || r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted) continue;
        final loc = _homeLocationById(item.locationId);
        if (loc?.latitude == null || loc?.longitude == null) continue;
        final meters = Geolocator.distanceBetween(p.latitude, p.longitude, loc!.latitude!, loc.longitude!);
        if (meters < nearest) nearest = meters;
      }
    }
    final shouldBoost = nearest <= 3000;
    final shouldRelax = nearest > 5000 || nearest == double.infinity;
    if (shouldBoost && !_nativeLocationProximityBoost) {
      _nativeLocationProximityBoost = true;
      Future<void>.delayed(const Duration(milliseconds: 250), () => _startNativeBackgroundLocationStream());
    } else if (shouldRelax && _nativeLocationProximityBoost) {
      _nativeLocationProximityBoost = false;
      Future<void>.delayed(const Duration(milliseconds: 250), () => _startNativeBackgroundLocationStream());
    }
  }

  Future<String> _resolveLiveLocality(Position p) async {
    final now = DateTime.now();
    if (_lastLiveLocalityLabel.isNotEmpty && _lastLiveLocalityResolvedAt != null && _lastLiveLocalityPosition != null) {
      final moved = Geolocator.distanceBetween(_lastLiveLocalityPosition!.latitude, _lastLiveLocalityPosition!.longitude, p.latitude, p.longitude);
      if (moved < 5000 && now.difference(_lastLiveLocalityResolvedAt!) < const Duration(minutes: 30)) return _lastLiveLocalityLabel;
    }
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': p.latitude.toStringAsFixed(7),
        'lon': p.longitude.toStringAsFixed(7),
        'zoom': '10',
        'addressdetails': '1',
        'accept-language': 'ro',
      });
      final headers = <String,String>{'Accept':'application/json','Accept-Language':'ro'};
      if (!kIsWeb) headers['User-Agent'] = 'AndiCarpeta/2.0.8 (internal operations app)';
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['address'] is Map) {
          final a = decoded['address'] as Map;
          String first(List<String> keys) {
            for (final key in keys) {
              final v = a[key]?.toString().trim() ?? '';
              if (v.isNotEmpty) return v;
            }
            return '';
          }
          final city = first(['city','town','municipality','village']);
          final county = first(['county','state']);
          final label = city.isNotEmpty && county.isNotEmpty && city.toLowerCase() != county.toLowerCase() ? '$city · $county' : (city.isNotEmpty ? city : county);
          if (label.isNotEmpty) {
            _lastLiveLocalityLabel = label;
            _lastLiveLocalityResolvedAt = now;
            _lastLiveLocalityPosition = p;
            return label;
          }
        }
      }
    } catch (e) {
      debugPrint('[location] Localitatea nu a putut fi identificată: $e');
    }
    return _lastLiveLocalityLabel;
  }

  Future<void> _shareLiveLocationIfAllowed([Position? suppliedPosition]) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final now = DateTime.now();
      final workDate = operationalWorkDate(now);
      final inWork = isInsideWorkWindow(now, workDate);

      // Preferința personală poate fi live / economic / offline. În timpul programului
      // modul offline este ridicat automat la economic, ca detectarea operațională să aibă date.
      var effectiveMode = _personalLocationMode;
      if (inWork && effectiveMode == 'offline') effectiveMode = 'economic';
      if (!inWork && effectiveMode == 'offline') {
        if (!_offlineLocationCleared) {
          await FirebaseFirestore.instance.collection('liveLocations').doc(currentUserId).delete();
          _offlineLocationCleared = true;
          _lastSharedAt = null;
          _lastSharedPosition = null;
        }
        return;
      }
      _offlineLocationCleared = false;

      final configured = _personalLocationIntervalMinutes.clamp(1, 60).toInt();
      final minGap = _nativeLocationProximityBoost && inWork
          ? const Duration(seconds: 20)
          : effectiveMode == 'live'
              ? const Duration(minutes: 1)
              : Duration(minutes: inWork ? configured.clamp(1, 3).toInt() : configured);
      if (_lastSharedAt != null && now.difference(_lastSharedAt!) < minGap) return;

      final accuracy = effectiveMode == 'live' || inWork ? LocationAccuracy.high : LocationAccuracy.medium;
      final p = suppliedPosition ?? await Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: accuracy));
      _updateNativeLocationProximityBoost(p, workDate);
      var moved = true;
      if (_lastSharedPosition != null) {
        final meters = Geolocator.distanceBetween(_lastSharedPosition!.latitude, _lastSharedPosition!.longitude, p.latitude, p.longitude);
        final threshold = effectiveMode == 'live' ? 10.0 : (inWork ? 25.0 : 150.0);
        moved = meters >= threshold;
      }
      final heartbeatDue = _lastSharedAt == null || inWork || (effectiveMode == 'live' && now.difference(_lastSharedAt!) >= const Duration(minutes: 5));
      if (!moved && !heartbeatDue) return;
      final myTeam = me.teamId;
      final localityLabel = await _resolveLiveLocality(p);
      await FirebaseFirestore.instance.collection('liveLocations').doc(currentUserId).set({
        'userId': currentUserId,
        'name': me.name,
        'teamId': myTeam,
        'photoBase64': me.photoBase64,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'mode': inWork ? 'operational-$effectiveMode' : effectiveMode,
        'nativeBackground': !kIsWeb,
        'localityLabel': localityLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _lastSharedPosition = p;
      _lastSharedAt = now;
      await _applyWorkAutomationFromPosition(p, now, workDate);
    } catch (e) {
      debugPrint('[location] Actualizarea locației a eșuat: $e');
    }
  }

  Location? _homeLocationById(String id) {
    for (final l in locations) { if (l.id == id) return l; }
    return null;
  }

  CentralizerRecord? _homeLatestRecord(String teamId, String locationId, DateTime workDate) {
    final list = records.where((r) => r.teamId == teamId && r.locationId == locationId && recordBelongsToWorkDate(r, workDate)).toList()
      ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    return list.isEmpty ? null : list.last;
  }

  void _automationNotifyOnce(String key, String title, String message) {
    if (_automationNotified.add(key)) notifyUser(currentUserId, title, message);
  }

  Future<void> _applyWorkAutomationFromPosition(Position p, DateTime now, DateTime workDate) async {
    // Geofencing-ul nu poate confirma sosirea dintr-o poziție GPS imprecisă,
    // veche sau raportată în timpul deplasării rapide. Nu pornim niciodată
    // o intervenție fără alegerea explicită a utilizatorului.
    if (!p.latitude.isFinite || !p.longitude.isFinite ||
        p.latitude < -90 || p.latitude > 90 ||
        p.longitude < -180 || p.longitude > 180) return;
    if (!p.accuracy.isFinite || p.accuracy < 0 || p.accuracy > 80) return;
    if (p.timestamp.isAfter(now.add(const Duration(minutes: 1))) ||
        now.difference(p.timestamp) > const Duration(minutes: 2)) return;
    if (p.speed.isFinite && p.speed > 8) return;
    if (!hasPermission(FunctionPermission.editProgram)) return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty || !canEditTeam(teamId)) return;

    await _maybeAutoCloseResolvedSchedules(workDate);

    final active = schedules.where((s) => s.teamId == teamId && sameDay(s.date, workDate) && s.started && !s.closed && !s.paused && !s.postponed).toList();
    if (active.isEmpty) return;
    if (active.length > 1) {
      _automationNotifyOnce('multi_${teamId}_${workDate.toIso8601String().substring(0,10)}', 'Automatizare suspendată', 'Sunt mai multe grafice pornite pentru aceeași echipă. Alege manual locația pentru INTRĂ/IEȘI.');
      return;
    }
    final schedule = active.first;
    final access = settings.learning['access'];

    final running = records.where((r) => r.teamId == teamId && r.status == WorkAttemptStatus.running && r.finishedAt == null && recordBelongsToWorkDate(r, workDate)).toList()
      ..sort((a, b) => recordEventTime(b).compareTo(recordEventTime(a)));

    // Finalizarea automată rămâne disponibilă doar dacă Learning pentru acces este activ.
    if (running.isNotEmpty) {
      if (settings.autoFinish && access?.enabled == true) {
        final current = running.first;
        final loc = _homeLocationById(current.locationId);
        if (loc?.latitude != null && loc?.longitude != null && current.startedAt != null) {
          final meters = Geolocator.distanceBetween(p.latitude, p.longitude, loc!.latitude!, loc.longitude!);
          final elapsed = now.difference(current.startedAt!);
          if (meters >= 220 && elapsed >= const Duration(minutes: 5)) {
            final firstOutside = _autoOutsideSince.putIfAbsent(current.id, () => now);
            if (now.difference(firstOutside) >= const Duration(seconds: 45)) {
              // Nu mai închidem automat intervenția: răspunsul despre fațadă este obligatoriu.
              _automationNotifyOnce(
                'finish_${current.id}',
                'Confirmă ieșirea din locație',
                'Te-ai îndepărtat ${meters.round()} m de ${current.locationNameSnapshot}. Apasă STOP și răspunde obligatoriu dacă fațada a fost realizată.',
              );
            }
          } else {
            _autoOutsideSince.remove(current.id);
            _automationNotified.remove('finish_${current.id}');
          }
        }
      }
      return;
    }

    // Sosirea la sală cere întotdeauna confirmarea omului. Nu pornim lucrarea doar
    // pentru că GPS-ul spune că telefonul este în apropiere.
    final candidates = <(ScheduleItem, Location, double)>[];
    for (final item in schedule.items) {
      final r = _homeLatestRecord(teamId, item.locationId, workDate);
      if (r?.status == WorkAttemptStatus.completed ||
          r?.status == WorkAttemptStatus.refused ||
          r?.status == WorkAttemptStatus.notCompleted ||
          r?.status == WorkAttemptStatus.waitingAccess ||
          r?.status == WorkAttemptStatus.running) continue;
      final loc = _homeLocationById(item.locationId);
      if (loc?.latitude == null || loc?.longitude == null) continue;
      final meters = Geolocator.distanceBetween(p.latitude, p.longitude, loc!.latitude!, loc.longitude!);
      // GPS-ul cu eroare mare nu trebuie să declanșeze promptul la marginea razei.
      // Cerem ca distanța + eroarea estimată să rămână în raza de 250 m.
      if (meters + p.accuracy <= 250) candidates.add((item, loc, meters));
    }
    if (candidates.isEmpty) {
      _autoInsideSince.clear();
      _arrivalSnoozedUntil.clear();
      _arrivalPromptCounts.clear();
      _automationNotified.removeWhere((key) => key.startsWith('arrival_'));
      return;
    }

    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    final item = candidates.first.$1;
    final meters = candidates.first.$3;
    final key = '${schedule.id}_${item.locationId}_${workDate.year}${two(workDate.month)}${two(workDate.day)}';
    final firstInside = _autoInsideSince.putIfAbsent(key, () => now);
    _autoInsideSince.removeWhere((k, _) => k != key);

    // Mic dwell pentru a evita întrebarea când doar trecem pe lângă locație.
    if (now.difference(firstInside) < const Duration(seconds: 20)) return;
    final snoozedUntil = _arrivalSnoozedUntil[key];
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) return;
    if ((_arrivalPromptCounts[key] ?? 0) >= 2) return;

    await _handleArrivalDetected(schedule, item, meters, workDate, key);
  }

  Future<void> _handleArrivalDetected(WorkSchedule schedule, ScheduleItem item, double meters, DateTime workDate, String key) async {
    final notificationKey = 'arrival_$key';
    _automationNotifyOnce(
      notificationKey,
      'Ai ajuns la ${item.locationNameSnapshot}',
      'Ești la aproximativ ${meters.round()} m. Ai început lucrul sau ești în așteptare?',
    );
    if (!mounted || _arrivalDialogOpen) return;

    _arrivalDialogOpen = true;
    _arrivalPromptCounts[key] = (_arrivalPromptCounts[key] ?? 0) + 1;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ai ajuns la locație'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.locationNameSnapshot, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text('Detectat la aproximativ ${meters.round()} m de locație.'),
          const SizedBox(height: 12),
          const Text('Ce se întâmplă acum?'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'later'), child: const Text('NU ÎNCĂ')),
          OutlinedButton.icon(onPressed: () => Navigator.pop(dialogContext, 'waiting'), icon: const Icon(Icons.hourglass_top), label: const Text('SUNT ÎN AȘTEPTARE')),
          FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, 'start'), icon: const Icon(Icons.play_arrow), label: const Text('ÎNCEP LUCRUL')),
        ],
      ),
    );
    _arrivalDialogOpen = false;
    if (!mounted) return;

    if (choice == 'later') {
      _arrivalSnoozedUntil[key] = DateTime.now().add(const Duration(minutes: 10));
      // Permitem o singură reamintire după 10 minute dacă membrul este încă acolo.
      _automationNotified.remove(notificationKey);
      return;
    }
    if (choice == 'waiting') {
      await _saveArrivalWaiting(schedule, item, workDate);
      return;
    }
    if (choice == 'start') {
      await _saveArrivalStart(schedule, item, workDate);
    }
  }

  Future<void> _saveArrivalStart(WorkSchedule schedule, ScheduleItem item, DateTime workDate) async {
    final teamId = schedule.teamId;
    final now = DateTime.now();
    final existing = _homeLatestRecord(teamId, item.locationId, workDate);
    // Dacă între timp colegul a stabilit deja starea, nu dublăm execuția.
    if (existing?.status == WorkAttemptStatus.running || existing?.status == WorkAttemptStatus.waitingAccess || existing?.completed == true) return;
    final started = CentralizerRecord(
      id: existing?.id ?? idNow(), teamId: teamId, locationId: item.locationId, type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot, addressSnapshot: item.addressSnapshot,
      waitingStartedAt: existing?.waitingStartedAt,
      waitingEndedAt: existing?.waitingStartedAt != null && existing?.waitingEndedAt == null ? now : existing?.waitingEndedAt,
      startedAt: now, finishedAt: null, status: WorkAttemptStatus.running,
      refusalReason: null, keptForLearning: existing?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: existing?.facadeDone ?? false,
    );
    try {
      await _saveRecordDirect(started);
      log('INTRĂ confirmat la sosire', '${item.locationNameSnapshot} · ${timeText(now)}');
      if (mounted) showSuccessMessage(context, 'Lucrarea a început la ${item.locationNameSnapshot}.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Pornirea lucrării nu a putut fi salvată: $e');
    }
  }

  Future<void> _saveArrivalWaiting(WorkSchedule schedule, ScheduleItem item, DateTime workDate) async {
    final teamId = schedule.teamId;
    final now = DateTime.now();
    final existing = _homeLatestRecord(teamId, item.locationId, workDate);
    if (existing?.status == WorkAttemptStatus.running || existing?.status == WorkAttemptStatus.waitingAccess || existing?.completed == true) return;
    final waiting = CentralizerRecord(
      id: existing?.id ?? idNow(), teamId: teamId, locationId: item.locationId, type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot, addressSnapshot: item.addressSnapshot,
      waitingStartedAt: existing?.waitingStartedAt ?? now, waitingEndedAt: null,
      startedAt: null, finishedAt: null, status: WorkAttemptStatus.waitingAccess,
      refusalReason: null, keptForLearning: existing?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: existing?.facadeDone ?? false,
    );
    try {
      await _saveRecordDirect(waiting);
      log('Așteptare confirmată la sosire', '${item.locationNameSnapshot} · ${timeText(now)}');
      if (mounted) showSuccessMessage(context, 'Așteptarea a fost pornită la ${item.locationNameSnapshot}.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Așteptarea nu a putut fi salvată: $e');
    }
  }

  Future<void> _maybeAutoCloseResolvedSchedules(DateTime workDate) async {
    if (!settings.autoCloseWhenAllDone || !hasPermission(FunctionPermission.editProgram)) return;
    final programLearning = settings.learning['program'];
    if (programLearning?.enabled != true) return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty || !canEditTeam(teamId)) return;
    final active = schedules.where((s) => s.teamId == teamId && sameDay(s.date, workDate) && s.started && !s.closed).toList();
    for (final schedule in active) {
      if (schedule.items.isEmpty) continue;
      var allResolved = true;
      for (final item in schedule.items) {
        final r = _homeLatestRecord(teamId, item.locationId, workDate);
        if (r == null || (r.status != WorkAttemptStatus.completed && r.status != WorkAttemptStatus.refused && r.status != WorkAttemptStatus.notCompleted)) {
          allResolved = false; break;
        }
      }
      if (!allResolved) continue;
      final key = 'close_${schedule.id}';
      if (programLearning!.mode == LearningMode.manualApproval) {
        _automationNotifyOnce(key, 'Grafic terminat', '${schedule.graphName} are toate locațiile rezolvate. Poți închide graficul.');
        continue;
      }
      schedule.closed = true;
      schedule.active = false;
      schedule.paused = false;
      try {
        await _saveScheduleDirect(schedule);
        log('Grafic închis automat Learning', '${schedule.graphName} · ${formatDate(schedule.date)}');
        _automationNotified.add(key);
      } catch (_) {}
    }
  }

  List<Location> _seedLocations() {
    return [
      // MAGIC — toate cele 36 de locații din ANEXA MAGIC FEBR.
      Location(id:'magic01',name:'MAGIC Alexandria',address:'Jud. Teleorman, Mun. Alexandria, Str. București, Bl. G103, parter',type:LocationType.magic,notes:'Anexa indică aproximativ 45–50 mp; tipul suprafeței nu este precizat explicit.'),
      Location(id:'magic02',name:'MAGIC Brăila',address:'Jud. Brăila, Mun. Brăila, Str. Școlilor, nr. 52, bl. 15, parter',type:LocationType.magic,surfaceM2:133,facadeM2:264),
      Location(id:'magic03',name:'MAGIC Brăila 2',address:'Jud. Brăila, Mun. Brăila, Calea Călărașilor, nr. 55, bl. 11, parter',type:LocationType.magic,surfaceM2:212,facadeM2:168),
      Location(id:'magic04',name:'MAGIC Brăila 3',address:'Jud. Brăila, Mun. Brăila, Dorobanților, parter',type:LocationType.magic,surfaceM2:92,facadeM2:112),
      Location(id:'magic05',name:'MAGIC Buzău',address:'Jud. Buzău, Mun. Buzău, Bd. Unirii, bl. 18D',type:LocationType.magic,surfaceM2:168,facadeM2:15),
      Location(id:'magic06',name:'MAGIC Buzău 2',address:'Buzău, Str. 1 Decembrie 1918',type:LocationType.magic,facadeM2:5),
      Location(id:'magic07',name:'MAGIC Sălăjan',address:'București, Bd. N. Grigorescu nr. 51A, clădirea C1, Sector 3',type:LocationType.magic,surfaceM2:200,facadeM2:75),
      Location(id:'magic08',name:'MAGIC Octavian Goga',address:'București, Sector 3, Bd. Octavian Goga nr. 22, Tronson I, Magazin 1, parter',type:LocationType.magic,surfaceM2:107,facadeM2:140),
      Location(id:'magic09',name:'MAGIC Herăstrău',address:'București, Sector 1, Str. Nicolae G. Caramfil nr. 4',type:LocationType.magic,facadeM2:250),
      Location(id:'magic10',name:'MAGIC Theodor Pallady',address:'București, Str. Victor Brauner nr. 29 (Theodor Pallady)',type:LocationType.magic,facadeM2:150),
      Location(id:'magic11',name:'MAGIC Giurgiului',address:'București, Sector 4, Șos. Giurgiului nr. 121, bl. 5, parter',type:LocationType.magic,facadeM2:60),
      Location(id:'magic12',name:'MAGIC Popești-Leordeni',address:'Popești-Leordeni, Str. Amurgului nr. 34',type:LocationType.magic,surfaceM2:58),
      Location(id:'magic13',name:'MAGIC Bragadiru',address:'Jud. Ilfov, Bragadiru, Str. Cristalului nr. 1',type:LocationType.magic,facadeM2:50),
      Location(id:'magic14',name:'MAGIC Otopeni',address:'Jud. Ilfov, Otopeni, Str. 23 August nr. 204',type:LocationType.magic,facadeM2:60),
      Location(id:'magic15',name:'MAGIC Colentina',address:'București, Str. Colentina nr. 76',type:LocationType.magic,facadeM2:60),
      Location(id:'magic16',name:'MAGIC Prosper',address:'București, 13 Septembrie nr. 221 (Prosper)',type:LocationType.magic,facadeM2:60),
      Location(id:'magic17',name:'MAGIC Andronache',address:'București, Colentina nr. 261 (Andronache)',type:LocationType.magic,facadeM2:95),
      Location(id:'magic18',name:'MAGIC Constanța',address:'Jud. Constanța, Mun. Constanța, Bd. 1 Decembrie 1918 nr. 43, bl. L24',type:LocationType.magic,facadeM2:150),
      Location(id:'magic19',name:'MAGIC Reșița',address:'Jud. Caraș-Severin, Mun. Reșița, Bd. Republicii nr. 24',type:LocationType.magic,surfaceM2:101,facadeM2:15),
      Location(id:'magic20',name:'MAGIC Reșița 2',address:'Jud. Caraș-Severin, Mun. Reșița, Bd. Republicii nr. 13',type:LocationType.magic,surfaceM2:79,facadeM2:20),
      Location(id:'magic21',name:'MAGIC Reșița 3',address:'Jud. Caraș-Severin, Mun. Reșița, Str. Ion Luca Caragiale nr. 1',type:LocationType.magic,facadeM2:20),
      Location(id:'magic22',name:'MAGIC Drobeta Turnu Severin',address:'Jud. Mehedinți, Drobeta Turnu Severin, Bd. Tudor Vladimirescu nr. 130, bl. IS3A, parter',type:LocationType.magic,surfaceM2:109,facadeM2:10),
      Location(id:'magic23',name:'MAGIC Focșani',address:'Jud. Vrancea, Mun. Focșani, Bd. Brăilei nr. 102, unitatea GF08',type:LocationType.magic,facadeM2:20),
      Location(id:'magic24',name:'MAGIC Galați',address:'Jud. Galați, Mun. Galați, Bd. George Coșbuc nr. 2, parter hotel',type:LocationType.magic,facadeM2:544),
      Location(id:'magic25',name:'MAGIC Hunedoara',address:'Jud. Hunedoara, Mun. Hunedoara, Bd. Dacia nr. 6 Bis',type:LocationType.magic,facadeM2:10),
      Location(id:'magic26',name:'MAGIC Lugoj',address:'Jud. Timiș, Mun. Lugoj, Str. Bucegi nr. 28',type:LocationType.magic,facadeM2:30),
      Location(id:'magic27',name:'MAGIC Lugoj 2',address:'Jud. Timiș, Mun. Lugoj, Str. Huniade nr. 5',type:LocationType.magic,surfaceM2:40,facadeM2:25),
      Location(id:'magic28',name:'MAGIC Ploiești',address:'Ploiești, Șoseaua Nordului nr. 1',type:LocationType.magic,surfaceM2:200),
      Location(id:'magic29',name:'MAGIC Slobozia 2',address:'Jud. Ialomița, Mun. Slobozia, Bd. Matei Basarab, bl. 35, sc. A',type:LocationType.magic,surfaceM2:240,facadeM2:130),
      Location(id:'magic30',name:'MAGIC Sfântu Gheorghe',address:'Jud. Covasna, Mun. Sfântu Gheorghe, Str. Nicolae Iorga nr. 61, bl. 10, sc. E/A',type:LocationType.magic,facadeM2:38),
      Location(id:'magic31',name:'MAGIC Sibiu Gara',address:'Sibiu, Piața 1 Decembrie 1918 (în gară)',type:LocationType.magic),
      Location(id:'magic32',name:'MAGIC Târgu Jiu',address:'Jud. Gorj, Mun. Târgu Jiu, Str. Victoriei, bl. 35, sc. 1, parter',type:LocationType.magic,facadeM2:55),
      Location(id:'magic33',name:'MAGIC Sediu București',address:'București, Calea Floreasca nr. 55',type:LocationType.magic,surfaceM2:334),
      Location(id:'magic34',name:'MAGIC Slatina',address:'Slatina, Bd. Alexandru Ioan Cuza nr. 9',type:LocationType.magic,facadeM2:100),
      Location(id:'magic35',name:'MAGIC Constanța Mamaia',address:'Constanța, Bd. Mamaia nr. 264',type:LocationType.magic,surfaceM2:350,notes:'Anexa indică 350 mp fără separare mochetă/fațadă'),
      Location(id:'magic36',name:'MAGIC Constanța Traian',address:'Constanța, Str. Traian nr. 62',type:LocationType.magic,surfaceM2:425,notes:'Anexa indică 425 mp fără separare mochetă/fațadă'),
      // MILLION — toate cele 67 de locații din ANEXE LUNARE- MILION.pdf
      Location(id:'million01',name:'Ard:Revolutiei_83',address:'Ard:Revolutiei_83',type:LocationType.million,surfaceM2:127,notes:'Anexa: 301 mp total, 127 mp parțial.',contacts:[LocationContact(name:'KARINA RACZ',phone:'0755831706')]),
      Location(id:'million02',name:'Bac:CaleaRepublicii_181',address:'Bac:CaleaRepublicii_181',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRU ANDRIAN',phone:'0733330524')]),
      Location(id:'million03',name:'Bac:MihaiViteazu_2-4',address:'Bac:MihaiViteazu_2-4',type:LocationType.million,surfaceM2:161,contacts:[LocationContact(name:'MUTU IULIANA',phone:'0730076826')]),
      Location(id:'million04',name:'Bam:Republicii_14A',address:'Bam:Republicii_14A',type:LocationType.million,surfaceM2:163,contacts:[LocationContact(name:'DIANA CIMPAN',phone:'0732650525')]),
      Location(id:'million05',name:'Bam:Unirii 12',address:'Bam:Unirii 12',type:LocationType.million,surfaceM2:102,contacts:[LocationContact(name:'DIANA DURIJAN',phone:'0730899364')]),
      Location(id:'million06',name:'Bra:NicolaeBalcescu 68',address:'Bra:NicolaeBalcescu 68',type:LocationType.million,surfaceM2:89,contacts:[LocationContact(name:'MARIA HERMECZI',phone:'0748685308')]),
      Location(id:'million07',name:'Brl:Calea_Calarasilor_66',address:'Brl:Calea_Calarasilor_66',type:LocationType.million,contacts:[LocationContact(name:'COSMINA NEDELCU',phone:'0755365479')]),
      Location(id:'million08',name:'Brl:Eminescu_59',address:'Brl:Eminescu_59',type:LocationType.million,contacts:[LocationContact(name:'ADRIAN GRIGORE',phone:'0723629259')]),
      Location(id:'million09',name:'Braila 3',address:'Braila 3',type:LocationType.million,facadeM2:250,notes:'Anexa menționează fațadă 250 m².'),
      Location(id:'million10',name:'Buz:Unirii 232',address:'Buz:Unirii 232',type:LocationType.million,surfaceM2:475),
      Location(id:'million11',name:'Car:MihaiViteazul',address:'Car:MihaiViteazul',type:LocationType.million,surfaceM2:151,contacts:[LocationContact(name:'NICOLAE ARMAS',phone:'0790052585'),LocationContact(name:'CRISTINA COVACIU',phone:'0731014101')]),
      Location(id:'million12',name:'Crv:Calea_Bucuresti_80',address:'Crv:Calea_Bucuresti_80',type:LocationType.million,surfaceM2:439,notes:'Anexa menționează separat terasă 49,6 m².',contacts:[LocationContact(name:'LOREDANA ZANFIRACHE',phone:'0765177503')]),
      Location(id:'million13',name:'Crv:CaleaBucuresti_18',address:'Crv:CaleaBucuresti_18',type:LocationType.million,surfaceM2:199,contacts:[LocationContact(name:'TOMINA CALIN',phone:'0732650506')]),
      Location(id:'million14',name:'Crv:IonMaiorescu_nr.3',address:'Crv:IonMaiorescu_nr.3',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA DRAGHICI',phone:'0760188002')]),
      Location(id:'million15',name:'Crv:PiataGarii - Daciei',address:'Crv:PiataGarii - Daciei',type:LocationType.million,surfaceM2:159,contacts:[LocationContact(name:'EMILIA PUNCIOIU',phone:'0763014497')]),
      Location(id:'million16',name:'Craiova - George Enescu 76',address:'Craiova - George Enescu 76',type:LocationType.million,contacts:[LocationContact(name:'SIMONA BURDANGIU',phone:'0766905285')]),
      Location(id:'million17',name:'Craiova - Bd Oltenia nr 50',address:'Craiova - Bd Oltenia nr 50',type:LocationType.million,surfaceM2:72,contacts:[LocationContact(name:'CRISTINA NICU',phone:'0726736680')]),
      Location(id:'million18',name:'Craiova, bld Sarari /Henri Coanda',address:'Craiova, bld Sarari /Henri Coanda',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA NICA',phone:'0769393550')]),
      Location(id:'million19',name:'Craiova General Averescu',address:'Craiova General Averescu',type:LocationType.million,surfaceM2:90,contacts:[LocationContact(name:'ELENA OPREA',phone:'0763653557')]),
      Location(id:'million20',name:'Craiova, str Brazda Novac -Lamaitei',address:'Craiova, str Brazda Novac -Lamaitei',type:LocationType.million,contacts:[LocationContact(name:'EMILIAN STRECHE',phone:'0760870784')]),
      Location(id:'million21',name:'Craiova, 1 mai',address:'Craiova, 1 mai',type:LocationType.million,surfaceM2:106,contacts:[LocationContact(name:'ANDREEA BICU',phone:'0760712372')]),
      Location(id:'million22',name:'Craiova - George Enescu nr 100',address:'Craiova - George Enescu nr 100',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA DRAGHICI',phone:'0760188002')]),
      Location(id:'million23',name:'Ctn:1Decembrie_1918',address:'Ctn:1Decembrie_1918',type:LocationType.million,surfaceM2:135,contacts:[LocationContact(name:'IULIA NASTASE',phone:'0737587406')]),
      Location(id:'million24',name:'Ctn:Soveja',address:'Ctn:Soveja',type:LocationType.million,surfaceM2:140,notes:'Anexa: locația s-a mărit cu magazinul de încălțăminte.',contacts:[LocationContact(name:'ELENA CHIVU',phone:'0731610509')]),
      Location(id:'million25',name:'Ctn:Tomis 391',address:'Ctn:Tomis 391',type:LocationType.million,surfaceM2:205,contacts:[LocationContact(name:'OANA FODULU',phone:'0724970734')]),
      Location(id:'million26',name:'Ctn: Dezrobirii, nr 143',address:'Ctn: Dezrobirii, nr 143',type:LocationType.million,surfaceM2:115,contacts:[LocationContact(name:'CRISTINA BOTOSENCU',phone:'0747925278')]),
      Location(id:'million27',name:'Cta Navodari',address:'Cta Navodari',type:LocationType.million,surfaceM2:74,contacts:[LocationContact(name:'FLORENTINA PANDELE',phone:'0784292802')]),
      Location(id:'million28',name:'Foc:CaleaMoldovei_32',address:'Foc:CaleaMoldovei_32',type:LocationType.million,surfaceM2:107,contacts:[LocationContact(name:'BOGDAN CHIRIAC',phone:'0730025129')]),
      Location(id:'million29',name:'Foc:Brailei_102',address:'Foc:Brailei_102',type:LocationType.million,contacts:[LocationContact(name:'NISAN PERINDAG',phone:'0732650523')]),
      Location(id:'million30',name:'Foc:Unirii_14',address:'Foc:Unirii_14',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA IOSIF',phone:'0731036859')]),
      Location(id:'million31',name:'Foc:Unirii_65',address:'Foc:Unirii_65',type:LocationType.million,contacts:[LocationContact(name:'OVIDIU VATASOIU',phone:'0728977321'),LocationContact(name:'NICOLETA URZICA',phone:'0728398423')]),
      Location(id:'million32',name:'Ias:Anastasie_Panu_31',address:'Ias:Anastasie_Panu_31',type:LocationType.million,contacts:[LocationContact(name:'LAURA LEFTER',phone:'0725795603')]),
      Location(id:'million33',name:'Ias:TudorVladimirescu',address:'Ias:TudorVladimirescu',type:LocationType.million,surfaceM2:457,contacts:[LocationContact(name:'ANDREEA CALIMAN',phone:'0734010791'),LocationContact(name:'ELENA GRASU',phone:'0738099719'),LocationContact(name:'ANDREEA SULUGIUC',phone:'0739935667'),LocationContact(name:'LAVINIA GRADINARIU',phone:'0735784696'),LocationContact(name:'ROXANA HUJA',phone:'0725054453')]),
      Location(id:'million34',name:'Oradea , str Transilvaniei nr 24',address:'Oradea , str Transilvaniei nr 24',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA SANDOR',phone:'0758044994')]),
      Location(id:'million35',name:'Pit:MaiorSantu_D2',address:'Pit:MaiorSantu_D2',type:LocationType.million,surfaceM2:139,contacts:[LocationContact(name:'SANDRA STANCESCU',phone:'0741438284')]),
      Location(id:'million36',name:'Plo:Republicii_17-25-1',address:'Plo:Republicii_17-25-1',type:LocationType.million,surfaceM2:154,contacts:[LocationContact(name:'STEFAN BAILESCU',phone:'0769398966')]),
      Location(id:'million37',name:'Plo:Nordului_1A',address:'Plo:Nordului_1A',type:LocationType.million,surfaceM2:294,contacts:[LocationContact(name:'TUDOR GAVRILOIU',phone:'0724107970'),LocationContact(name:'GEORGIANA CISMARU',phone:'0721356133')]),
      Location(id:'million38',name:'Rmv:ReginaMaria_4',address:'Rmv:ReginaMaria_4',type:LocationType.million,surfaceM2:351,contacts:[LocationContact(name:'GEORGE NICOLAE',phone:'0724220687'),LocationContact(name:'DIANA DUMITRA',phone:'0766643255')]),
      Location(id:'million39',name:'Rmv:MateiBasarab_1',address:'Rmv:MateiBasarab_1',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA DRAGOMIR',phone:'0765058278')]),
      Location(id:'million40',name:'Rmv:Tineretului',address:'Rmv:Tineretului',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA MIJA',phone:'0756623935')]),
      Location(id:'million41',name:'Rmv:Rapsodiei_19',address:'Rmv:Rapsodiei_19',type:LocationType.million,contacts:[LocationContact(name:'ANA MARIA CIOCHINA',phone:'0742898106')]),
      Location(id:'million42',name:'Sgm:1Decembrie1918',address:'Sgm:1Decembrie1918',type:LocationType.million,surfaceM2:93,contacts:[LocationContact(name:'ANAMARIA AILOAIE',phone:'0733330490')]),
      Location(id:'million43',name:'Sgm:Cuza Voda',address:'Sgm:Cuza Voda',type:LocationType.million,surfaceM2:75,contacts:[LocationContact(name:'STEFANIA ILES',phone:'0734703667')]),
      Location(id:'million44',name:'Slo:MateiBasarab_K1',address:'Slo:MateiBasarab_K1',type:LocationType.million,contacts:[LocationContact(name:'MADALINA PRELIPCEAN',phone:'0735787761')]),
      Location(id:'million45',name:'Sib:Shopping_City',address:'Sib:Shopping_City / Selimbar',type:LocationType.million,surfaceM2:150,contacts:[LocationContact(name:'VIOLETA TUDOR',phone:'0752549262')]),
      Location(id:'million46',name:'Sib:Promenada',address:'Sib:Promenada',type:LocationType.million,contacts:[LocationContact(name:'LAVINIA VATAU',phone:'0768999793')]),
      Location(id:'million47',name:'Stm:AlexandruIoanCuza 2',address:'Stm:AlexandruIoanCuza 2',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA TULIAN',phone:'0750824911')]),
      Location(id:'million48',name:'Stm:Careiului 17',address:'Stm:Careiului 17',type:LocationType.million,contacts:[LocationContact(name:'ONDINA PRINTI',phone:'0752661435'),LocationContact(name:'ALEXANDRA SZARAZ',phone:'0771041469'),LocationContact(name:'VANESSA POP',phone:'0745345380')]),
      Location(id:'million49',name:'Stm:Independentei 53',address:'Stm:Independentei 53',type:LocationType.million,surfaceM2:51,contacts:[LocationContact(name:'HENRIETTA BARTHA',phone:'0751243463')]),
      Location(id:'million50',name:'Sf Gheorghe, str Lunca Oltului nr 46',address:'Sf Gheorghe, str Lunca Oltului nr 46',type:LocationType.million,contacts:[LocationContact(name:'ANA MARIA TREFAN',phone:'0733560824')]),
      Location(id:'million51',name:'Tgj:Eroilor_nr.6',address:'Tgj:Eroilor_nr.6',type:LocationType.million,surfaceM2:300,contacts:[LocationContact(name:'IRINEL MALAESCU',phone:'0732650510'),LocationContact(name:'PREDOI IONELA',phone:'0764286861')]),
      Location(id:'million52',name:'Tgj:9Mai',address:'Tgj:9Mai',type:LocationType.million,contacts:[LocationContact(name:'RALUCA CALINA',phone:'0742891086')]),
      Location(id:'million53',name:'Tgv:ConstantinBrancoveanu_58',address:'Tgv:ConstantinBrancoveanu_58',type:LocationType.million,surfaceM2:90,contacts:[LocationContact(name:'NICOLETA MIHALCIOIU',phone:'0766644272')]),
      Location(id:'million54',name:'Tgv:Independentei_O2 (Nicolae Radian)',address:'Tgv:Independentei_O2 (Nicolae Radian)',type:LocationType.million,surfaceM2:148,contacts:[LocationContact(name:'MARIUS RADU',phone:'0730015087'),LocationContact(name:'GABRIELA NICOLAE',phone:'0724641567')]),
      Location(id:'million55',name:'Tgv:Dambovita_Mall',address:'Tgv:Dambovita_Mall',type:LocationType.million,surfaceM2:279,contacts:[LocationContact(name:'ALEXANDRU ANGHEL',phone:'0732890921')]),
      Location(id:'million56',name:'Targoviste 4 (unirii nr 60 )',address:'Targoviste 4 (unirii nr 60 )',type:LocationType.million,contacts:[LocationContact(name:'GINA PANAIT',phone:'0731810865')]),
      Location(id:'million57',name:'Tim:PiataMarasti_nr.1-2',address:'Tim:PiataMarasti_nr.1-2',type:LocationType.million,contacts:[LocationContact(name:'GIORGIANA STANCIU',phone:'0747568526')]),
      Location(id:'million58',name:'Bucuresti- Octavian Goga',address:'Bucuresti- Octavian Goga',type:LocationType.million,contacts:[LocationContact(name:'CLAUDIA PARASCHIV',phone:'0730233505')]),
      Location(id:'million59',name:'Bucuresti- Decebal',address:'Bucuresti- Decebal',type:LocationType.million,surfaceM2:200,contacts:[LocationContact(name:'IONELA CIMPOERU',phone:'0720058965')]),
      Location(id:'million60',name:'Bucuresti- Crangasi',address:'Bucuresti- Crangasi',type:LocationType.million,contacts:[LocationContact(name:'ANAMARIA NANCY',phone:'0734200358')]),
      Location(id:'million61',name:'Bucuresti - Ctin Brancoveanu',address:'Bucuresti - Ctin Brancoveanu',type:LocationType.million,surfaceM2:70,contacts:[LocationContact(name:'RADU LUMINITA',phone:'0730531020')]),
      Location(id:'million62',name:'Bucuresti - 13 septembrie',address:'Bucuresti - 13 septembrie',type:LocationType.million,surfaceM2:80,contacts:[LocationContact(name:'ISABELA TUDORA',phone:'0766748597')]),
      Location(id:'million63',name:'Slatina',address:'Slatina',type:LocationType.million,contacts:[LocationContact(name:'ALECSANDRA BOGHEANU',phone:'0757176083')]),
      Location(id:'million64',name:'Bucuresti bld Drumul Taberei',address:'Bucuresti bld Drumul Taberei',type:LocationType.million,contacts:[LocationContact(name:'IONUT ALEXANDRU',phone:'0733330487')]),
      Location(id:'million65',name:'Sibiu Str Lunga',address:'Sibiu Str Lunga',type:LocationType.million,contacts:[LocationContact(name:'MARIA MALAI',phone:'0743354536')]),
      Location(id:'million66',name:'Ploiesti Veronica Micle',address:'Ploiesti Veronica Micle',type:LocationType.million,contacts:[LocationContact(name:'ANDREI CISMARU',phone:'0739935665')]),
      Location(id:'million67',name:'Piata Victoriei Ploiesti',address:'Piata Victoriei Ploiesti',type:LocationType.million,contacts:[LocationContact(name:'MIHAELA STOICA',phone:'0799923020')]),
    ];
  }

  final List<StreamSubscription<dynamic>> _coreSubscriptions = [];
  final List<StreamSubscription<dynamic>> _financialSubscriptions = [];
  String? _financialTeamScope;
  final Map<String, String> _locationCache = {};
  final Map<String, String> _categoryCache = {};
  final Map<String, String> _functionCache = {};
  final Map<String, String> _teamCache = {};
  final Map<String, String> _carCache = {};
  final Map<String, String> _scheduleCache = {};
  final Map<String, String> _recordCache = {};
  final Map<String, String> _expenseCache = {};
  final Map<String, String> _perDiemCache = {};
  final Map<String, String> _financeCache = {};
  final Map<String, String?> _userTeamCache = {};
  String? coreSyncError;

  Map<String, dynamic> _locationMap(Location l) => {
    'name': l.name,
    'address': l.address,
    'type': l.type.name,
    'categoryId': l.categoryId,
    'status': l.status.name,
    'latitude': l.latitude,
    'longitude': l.longitude,
    'phone': l.phone,
    'contacts': l.contacts.map((c) => {'name': c.name, 'phone': c.phone, 'role': c.role, 'smsEnabled': c.smsEnabled}).toList(),
    'surfaceM2': l.surfaceM2,
    'facadeM2': l.facadeM2,
    'notes': l.notes,
    'active': l.active,
  };

  Location _locationFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    LocationType type = LocationType.million;
    final typeText = (d['type'] ?? 'million').toString();
    for (final item in LocationType.values) {
      if (item.name == typeText) type = item;
    }
    final rawContacts = d['contacts'];
    final contacts = <LocationContact>[];
    if (rawContacts is List) {
      for (final item in rawContacts) {
        if (item is Map) {
          contacts.add(LocationContact(
            name: (item['name'] ?? '').toString(),
            phone: (item['phone'] ?? '').toString(),
            role: (item['role'] ?? 'Manager').toString(),
            smsEnabled: item['smsEnabled'] != false,
          ));
        }
      }
    }
    double? numberOrNull(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }
    var status = LocationStatus.open;
    final statusText = (d['status'] ?? (d['active'] == false ? 'permanentlyClosed' : 'open')).toString();
    for (final value in LocationStatus.values) {
      if (value.name == statusText) status = value;
    }
    final categoryId = (d['categoryId'] ?? defaultCategoryIdForType(type)).toString();
    return Location(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      address: (d['address'] ?? '').toString(),
      type: type,
      categoryId: categoryId,
      status: status,
      latitude: numberOrNull(d['latitude']),
      longitude: numberOrNull(d['longitude']),
      phone: d['phone']?.toString(),
      contacts: contacts,
      surfaceM2: numberOrNull(d['surfaceM2']) ?? 0,
      facadeM2: numberOrNull(d['facadeM2']) ?? 0,
      notes: (d['notes'] ?? '').toString(),
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _categoryMap(LocationCategory c) => {
    'name': c.name,
    'colorValue': c.colorValue,
    'active': c.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  LocationCategory _categoryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return LocationCategory(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      colorValue: d['colorValue'] is num ? (d['colorValue'] as num).toInt() : int.tryParse('${d['colorValue']}') ?? Colors.blueGrey.value,
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _functionMap(FunctionDefinition f) => {
    'name': f.name,
    'iconKey': f.iconKey,
    'badgeKeys': f.badgeKeys,
    'colorValue': f.colorValue,
    'permissions': f.permissions.toList()..sort(),
    'active': f.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  FunctionDefinition _functionFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final raw = d['permissions'];
    final rawIconKey = (d['iconKey'] ?? 'badge_driver').toString();
    final iconKey = rawIconKey == 'badge_coordinator' || rawIconKey == 'badge_machine' ? 'badge_worker' : rawIconKey;
    final badgeKeys = (d['badgeKeys'] is List
        ? (d['badgeKeys'] as List).map((e) => e.toString())
        : <String>[iconKey])
      .where((e) => e.isNotEmpty && e != 'badge_coordinator')
      .map((e) => e == 'badge_machine' ? 'badge_worker' : e)
      .toSet()
      .take(3)
      .toList();
    if (badgeKeys.isEmpty) badgeKeys.add(iconKey);
    return FunctionDefinition(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      iconKey: iconKey,
      badgeKeys: badgeKeys,
      colorValue: d['colorValue'] is num ? (d['colorValue'] as num).toInt() : int.tryParse('${d['colorValue']}') ?? Colors.blueGrey.value,
      permissions: raw is List ? raw.map((e) => e.toString()).toSet() : <String>{},
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _teamMap(Team t) => {
    'name': t.name,
    'members': t.members,
    'carId': t.carId,
    'financialManagerId': t.financialManagerId,
    'active': t.active,
  };

  Team _teamFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final raw = d['members'];
    return Team(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      members: raw is List ? raw.map((e) => e.toString()).toList() : <String>[],
      carId: d['carId']?.toString(),
      financialManagerId: d['financialManagerId']?.toString(),
      active: d['active'] != false,
    );
  }

  String? _dateString(DateTime? d) => d?.toIso8601String();

  DateTime? _dateFrom(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> _carMap(Car c) => {
    'plate': c.plate,
    'makeModel': c.makeModel,
    'active': c.active,
    'rcaUntil': _dateString(c.rcaUntil),
    'itpUntil': _dateString(c.itpUntil),
    'rovinietaUntil': _dateString(c.rovinietaUntil),
    'averageConsumption': c.averageConsumption,
    'fuelPricePerLiter': c.fuelPricePerLiter,
    'fuelType': c.fuelType,
  };

  Car _carFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Car(
      id: doc.id,
      plate: (d['plate'] ?? '').toString(),
      makeModel: (d['makeModel'] ?? '').toString(),
      active: d['active'] != false,
      rcaUntil: _dateFrom(d['rcaUntil']),
      itpUntil: _dateFrom(d['itpUntil']),
      rovinietaUntil: _dateFrom(d['rovinietaUntil']),
      averageConsumption: (d['averageConsumption'] is num) ? (d['averageConsumption'] as num).toDouble() : 0,
      fuelPricePerLiter: (d['fuelPricePerLiter'] is num) ? (d['fuelPricePerLiter'] as num).toDouble() : 0,
      fuelType: (d['fuelType'] ?? 'Motorină').toString(),
    );
  }

  Map<String, dynamic> _scheduleMap(WorkSchedule s) => {
    'teamId': s.teamId,
    'graphId': s.graphId,
    'graphName': s.graphName,
    'date': Timestamp.fromDate(s.date),
    'active': s.active,
    'closed': s.closed,
    'started': s.started,
    'paused': s.paused,
    'postponed': s.postponed,
    'autoProposed': s.autoProposed,
    'planAlertAt': s.planAlertAt == null ? null : Timestamp.fromDate(s.planAlertAt!),
    'planAlertReason': s.planAlertReason,
    'lastRecalculatedAt': s.lastRecalculatedAt == null ? null : Timestamp.fromDate(s.lastRecalculatedAt!),
    'recalculationCount': s.recalculationCount,
    'learningExplanation': s.learningExplanation,
    'learningConfidence': s.learningConfidence,
    'learningSamples': s.learningSamples,
    'departureName': s.departureName,
    'departureLatitude': s.departureLatitude,
    'departureLongitude': s.departureLongitude,
    'returnName': s.returnName,
    'returnLatitude': s.returnLatitude,
    'returnLongitude': s.returnLongitude,
    'items': s.items.map((i) => {
      'locationId': i.locationId,
      'locationNameSnapshot': i.locationNameSnapshot,
      'addressSnapshot': i.addressSnapshot,
      'typeSnapshot': i.typeSnapshot.name,
      'categoryIdSnapshot': i.categoryIdSnapshot,
      'order': i.order,
      'transferred': i.transferred,
      'facadePlanned': i.facadePlanned,
    }).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  WorkSchedule _scheduleFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final rawItems = d['items'];
    final items = <ScheduleItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        var type = LocationType.million;
        final typeText = (raw['typeSnapshot'] ?? 'million').toString();
        for (final value in LocationType.values) {
          if (value.name == typeText) type = value;
        }
        items.add(ScheduleItem(
          locationId: (raw['locationId'] ?? '').toString(),
          locationNameSnapshot: (raw['locationNameSnapshot'] ?? '').toString(),
          addressSnapshot: (raw['addressSnapshot'] ?? '').toString(),
          typeSnapshot: type,
          categoryIdSnapshot: (raw['categoryIdSnapshot'] ?? defaultCategoryIdForType(type)).toString(),
          order: raw['order'] is num ? (raw['order'] as num).toInt() : int.tryParse('${raw['order']}') ?? 0,
          transferred: raw['transferred'] == true,
          facadePlanned: raw['facadePlanned'] == true,
        ));
      }
    }
    items.sort((a, b) => a.order.compareTo(b.order));
    return WorkSchedule(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      graphId: (d['graphId'] ?? '').toString().trim().isNotEmpty
          ? (d['graphId'] ?? '').toString()
          : 'legacy_${(d['teamId'] ?? '').toString()}_${(_dateFrom(d['date']) ?? DateTime.now()).year}_${(_dateFrom(d['date']) ?? DateTime.now()).month.toString().padLeft(2, '0')}',
      graphName: (d['graphName'] ?? '').toString().trim().isNotEmpty
          ? (d['graphName'] ?? '').toString()
          : graphDefaultName(_dateFrom(d['date']) ?? DateTime.now()),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      items: items,
      active: d['active'] != false,
      closed: d['closed'] == true,
      started: d['started'] == true,
      paused: d['paused'] == true,
      postponed: d['postponed'] == true,
      autoProposed: d['autoProposed'] == true,
      planAlertAt: _dateFrom(d['planAlertAt']),
      planAlertReason: (d['planAlertReason'] ?? '').toString(),
      lastRecalculatedAt: _dateFrom(d['lastRecalculatedAt']),
      recalculationCount: d['recalculationCount'] is num ? (d['recalculationCount'] as num).toInt() : int.tryParse('${d['recalculationCount']}') ?? 0,
      learningExplanation: (d['learningExplanation'] ?? '').toString(),
      learningConfidence: d['learningConfidence'] is num ? (d['learningConfidence'] as num).toDouble() : 0,
      learningSamples: d['learningSamples'] is num ? (d['learningSamples'] as num).toInt() : 0,
      departureName: (d['departureName'] ?? '').toString(),
      departureLatitude: d['departureLatitude'] is num ? (d['departureLatitude'] as num).toDouble() : null,
      departureLongitude: d['departureLongitude'] is num ? (d['departureLongitude'] as num).toDouble() : null,
      returnName: (d['returnName'] ?? '').toString(),
      returnLatitude: d['returnLatitude'] is num ? (d['returnLatitude'] as num).toDouble() : null,
      returnLongitude: d['returnLongitude'] is num ? (d['returnLongitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> _recordMap(CentralizerRecord r) => {
    'teamId': r.teamId,
    'locationId': r.locationId,
    'type': r.type.name,
    'locationNameSnapshot': r.locationNameSnapshot,
    'addressSnapshot': r.addressSnapshot,
    'waitingStartedAt': r.waitingStartedAt == null ? null : Timestamp.fromDate(r.waitingStartedAt!),
    'waitingEndedAt': r.waitingEndedAt == null ? null : Timestamp.fromDate(r.waitingEndedAt!),
    'startedAt': r.startedAt == null ? null : Timestamp.fromDate(r.startedAt!),
    'finishedAt': r.finishedAt == null ? null : Timestamp.fromDate(r.finishedAt!),
    'status': r.status.name,
    'refusalReason': r.refusalReason,
    'keptForLearning': r.keptForLearning,
    'facadePlanned': r.facadePlanned,
    'facadeDone': r.facadeDone,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  CentralizerRecord _recordFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var type = LocationType.million;
    for (final value in LocationType.values) {
      if (value.name == (d['type'] ?? 'million').toString()) type = value;
    }
    var status = WorkAttemptStatus.waitingAccess;
    for (final value in WorkAttemptStatus.values) {
      if (value.name == (d['status'] ?? 'waitingAccess').toString()) status = value;
    }
    return CentralizerRecord(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      locationId: (d['locationId'] ?? '').toString(),
      type: type,
      locationNameSnapshot: (d['locationNameSnapshot'] ?? '').toString(),
      addressSnapshot: (d['addressSnapshot'] ?? '').toString(),
      waitingStartedAt: _dateFrom(d['waitingStartedAt']),
      waitingEndedAt: _dateFrom(d['waitingEndedAt']),
      startedAt: _dateFrom(d['startedAt']),
      finishedAt: _dateFrom(d['finishedAt']),
      status: status,
      refusalReason: d['refusalReason']?.toString(),
      keptForLearning: d['keptForLearning'] != false,
      facadePlanned: d['facadePlanned'] == true,
      facadeDone: d['facadeDone'] == true,
    );
  }

  Map<String, dynamic> _notificationMap(AppNotification n) => {
    'userId': n.userId,
    'title': n.title,
    'message': n.message,
    'createdAt': Timestamp.fromDate(n.createdAt),
    'read': n.read,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  AppNotification _notificationFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AppNotification(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      createdAt: _dateFrom(d['createdAt']) ?? DateTime.now(),
      read: d['read'] == true,
    );
  }

  double _doubleFrom(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _expenseMap(Expense e) => {
    'teamId': e.teamId,
    'settlementId': e.settlementId,
    'category': e.category,
    'description': e.description,
    'amount': e.amount,
    'date': Timestamp.fromDate(e.date),
    'documentType': e.documentType.name,
    'documentNumber': e.documentNumber,
    'supplier': e.supplier,
    'liters': e.liters,
    'pricePerLiter': e.pricePerLiter,
    'documentImageBase64': e.documentImageBase64,
    'imageFingerprint': e.imageFingerprint,
    'ocrRawText': e.ocrRawText,
    'ocrConfidence': e.ocrConfidence,
    'confirmed': e.confirmed,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Expense _expenseFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var docType = ExpenseDocumentType.fiscalReceipt;
    for (final value in ExpenseDocumentType.values) {
      if (value.name == (d['documentType'] ?? '').toString()) docType = value;
    }
    return Expense(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      settlementId: d['settlementId']?.toString(),
      category: (d['category'] ?? 'Alte cheltuieli').toString(),
      description: (d['description'] ?? '').toString(),
      amount: _doubleFrom(d['amount']),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      documentType: docType,
      documentNumber: (d['documentNumber'] ?? '').toString(),
      supplier: (d['supplier'] ?? '').toString(),
      liters: d['liters'] == null ? null : _doubleFrom(d['liters']),
      pricePerLiter: d['pricePerLiter'] == null ? null : _doubleFrom(d['pricePerLiter']),
      documentImageBase64: (d['documentImageBase64'] ?? '').toString(),
      imageFingerprint: (d['imageFingerprint'] ?? '').toString(),
      ocrRawText: (d['ocrRawText'] ?? '').toString(),
      ocrConfidence: _doubleFrom(d['ocrConfidence']),
      confirmed: d['confirmed'] != false,
    );
  }

  Map<String, dynamic> _perDiemMap(PerDiemEntry d) => {
    'teamId': d.teamId,
    'settlementId': d.settlementId,
    'memberId': d.memberId,
    'date': Timestamp.fromDate(d.date),
    'amount': d.amount,
    'status': d.status.name,
    'method': d.method?.name,
    'distributedBy': d.distributedBy,
    'distributedAt': d.distributedAt == null ? null : Timestamp.fromDate(d.distributedAt!),
    'confirmedAt': d.confirmedAt == null ? null : Timestamp.fromDate(d.confirmedAt!),
    'received': d.received,
    'actualReceivedAmount': d.actualReceivedAmount,
    'supplementaryFor': d.supplementaryFor,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  PerDiemEntry _perDiemFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var status = PerDiemStatus.notGranted;
    for (final value in PerDiemStatus.values) {
      if (value.name == (d['status'] ?? '').toString()) status = value;
    }
    PerDiemPaymentMethod? method;
    for (final value in PerDiemPaymentMethod.values) {
      if (value.name == (d['method'] ?? '').toString()) method = value;
    }
    return PerDiemEntry(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      settlementId: d['settlementId']?.toString(),
      memberId: (d['memberId'] ?? '').toString(),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      amount: _doubleFrom(d['amount']),
      status: status,
      method: method,
      distributedBy: d['distributedBy']?.toString(),
      distributedAt: _dateFrom(d['distributedAt']),
      confirmedAt: _dateFrom(d['confirmedAt']),
      received: d['received'] is bool ? d['received'] as bool : null,
      actualReceivedAmount: d['actualReceivedAmount'] == null ? null : _doubleFrom(d['actualReceivedAmount']),
      supplementaryFor: d['supplementaryFor']?.toString(),
    );
  }

  Map<String, dynamic> _settlementMap(TravelSettlement s) => {
    'teamId': s.teamId,
    'name': s.name,
    'startDate': Timestamp.fromDate(s.startDate),
    'endDate': s.endDate == null ? null : Timestamp.fromDate(s.endDate!),
    'managerId': s.managerId,
    'receivedDeparture': s.departureTotal,
    'receivedDuring': s.duringTotal,
    'receivedEntries': s.receivedEntries.map((e)=>{
      'id': e.id, 'kind': e.kind, 'amount': e.amount, 'method': e.method, 'fromName': e.fromName, 'date': Timestamp.fromDate(e.date),
    }).toList(),
    'perDiemRate': s.perDiemRate,
    'closed': s.closed,
    'createdAt': Timestamp.fromDate(s.createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TravelSettlement _settlementFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final receivedEntries=<ReceivedMoneyEntry>[];
    final rawReceived=d['receivedEntries'];
    if(rawReceived is List){
      for(final raw in rawReceived){
        if(raw is! Map)continue;
        receivedEntries.add(ReceivedMoneyEntry(
          id:(raw['id']??idNow()).toString(),
          kind:(raw['kind']??'during').toString(),
          amount:_doubleFrom(raw['amount']),
          method:(raw['method']??'Cash').toString(),
          fromName:(raw['fromName']??'').toString(),
          date:_dateFrom(raw['date'])??DateTime.now(),
        ));
      }
    }
    return TravelSettlement(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      name: (d['name'] ?? 'Deplasare').toString(),
      startDate: _dateFrom(d['startDate']) ?? DateTime.now(),
      endDate: _dateFrom(d['endDate']),
      managerId: d['managerId']?.toString(),
      receivedDeparture: _doubleFrom(d['receivedDeparture']),
      receivedDuring: _doubleFrom(d['receivedDuring']),
      receivedEntries: receivedEntries,
      perDiemRate: _doubleFrom(d['perDiemRate'], settings.defaultPerDiem),
      closed: d['closed'] == true,
      createdAt: _dateFrom(d['createdAt']),
    );
  }

  Map<String, dynamic> _financeMap(TeamFinance f) => {
    'teamId': f.teamId,
    'managerId': f.managerId,
    'receivedDeparture': f.departureTotal,
    'receivedDuring': f.duringTotal,
    'receivedEntries': f.receivedEntries.map((e)=>{
      'id': e.id, 'kind': e.kind, 'amount': e.amount, 'method': e.method, 'fromName': e.fromName, 'date': Timestamp.fromDate(e.date),
    }).toList(),
    'perDiemRate': f.perDiemRate,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TeamFinance _financeFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final receivedEntries=<ReceivedMoneyEntry>[];
    final rawReceived=d['receivedEntries'];
    if(rawReceived is List){
      for(final raw in rawReceived){
        if(raw is! Map)continue;
        receivedEntries.add(ReceivedMoneyEntry(
          id:(raw['id']??idNow()).toString(),
          kind:(raw['kind']??'during').toString(),
          amount:_doubleFrom(raw['amount']),
          method:(raw['method']??'Cash').toString(),
          fromName:(raw['fromName']??'').toString(),
          date:_dateFrom(raw['date'])??DateTime.now(),
        ));
      }
    }
    return TeamFinance(
      teamId: doc.id,
      managerId: d['managerId']?.toString(),
      receivedDeparture: _doubleFrom(d['receivedDeparture']),
      receivedDuring: _doubleFrom(d['receivedDuring']),
      receivedEntries: receivedEntries,
      perDiemRate: _doubleFrom(d['perDiemRate'], settings.defaultPerDiem),
    );
  }

  String _encoded(Map<String, dynamic> value) => jsonEncode(value.map((key, value) {
    if (value is FieldValue) return MapEntry(key, '<serverTimestamp>');
    if (value is Timestamp) return MapEntry(key, value.toDate().toIso8601String());
    if (value is List) {
      return MapEntry(key, value.map((e) {
        if (e is Map) return e.map((k, v) => MapEntry(k.toString(), v is Timestamp ? v.toDate().toIso8601String() : v));
        return e;
      }).toList());
    }
    return MapEntry(key, value);
  }));

  void _applyTeamMembership() {
    for (final u in users) {
      String? found;
      for (final t in teams) {
        if (t.members.contains(u.id)) {
          found = t.id;
          break;
        }
      }
      u.teamId = found;
    }
  }

  void _startFinancialSync() {
    final canViewAll = isAdmin || hasPermission(FunctionPermission.viewOtherDecont);
    final scope = canViewAll ? '*' : me.teamId;
    if (_financialTeamScope == scope) return;
    _financialTeamScope = scope;
    for (final sub in _financialSubscriptions) { sub.cancel(); }
    _financialSubscriptions.clear();
    expenses.clear(); perDiems.clear(); finances.clear(); settlements.clear();
    if (scope == null || scope.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final db=FirebaseFirestore.instance;
    final Query<Map<String,dynamic>> expensesQuery = canViewAll ? db.collection('expenses') : db.collection('expenses').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> perDiemQuery = canViewAll ? db.collection('perDiems') : db.collection('perDiems').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> financeQuery = canViewAll ? db.collection('finance') : db.collection('finance').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> settlementQuery = canViewAll ? db.collection('settlements') : db.collection('settlements').where('teamId',isEqualTo:scope);
    _financialSubscriptions.add(expensesQuery.snapshots().listen((snap){
      final list=snap.docs.map(_expenseFromDoc).toList()..sort((a,b)=>a.date.compareTo(b.date));
      if(!mounted)return;setState((){expenses..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Cheltuieli: $e');}));
    _financialSubscriptions.add(perDiemQuery.snapshots().listen((snap){
      final list=snap.docs.map(_perDiemFromDoc).toList()..sort((a,b)=>a.date.compareTo(b.date));
      if(!mounted)return;setState((){perDiems..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Diurne: $e');}));
    _financialSubscriptions.add(financeQuery.snapshots().listen((snap){
      final list=snap.docs.map(_financeFromDoc).toList();
      if(!mounted)return;setState((){finances..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Financiar: $e');}));
    _financialSubscriptions.add(settlementQuery.snapshots().listen((snap){
      final list=snap.docs.map(_settlementFromDoc).toList()..sort((a,b)=>b.startDate.compareTo(a.startDate));
      if(!mounted)return;setState((){settlements..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Deplasări: $e');}));
  }

  Future<void> _runAutomaticMaintenance() async {
    if (!isAdmin || _automaticBackupInFlight) return;
    _automaticBackupInFlight = true;
    try {
      await _pruneOldNotifications();
      await _pruneAutomaticBackups();
      if (!settings.automaticBackup) return;
      final db = FirebaseFirestore.instance;
      final stateRef = db.collection('meta').doc('backupAutomation');
      final state = await stateRef.get();
      final lastRaw = state.data()?['lastRunAt'];
      final last = lastRaw is Timestamp ? lastRaw.toDate() : null;
      if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) return;
      await _createAutomaticBackup();
      await stateRef.set({
        'lastRunAt': FieldValue.serverTimestamp(),
        'lastRunBy': currentUserId,
        'retentionDays': settings.backupRetentionDays,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Mentenanță automată: $e');
    } finally {
      _automaticBackupInFlight = false;
    }
  }

  Future<void> _createAutomaticBackup() async {
    const collectionNames = <String>[
      'users','teams','cars','locations','locationCategories','functions',
      'schedules','records','expenses','perDiems','finance','settlements',
      'documents','notifications','audit',
    ];
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final backupId = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final backupRef = db.collection('backups').doc(backupId);
    final uiSettingsSnapshot=await db.collection('meta').doc('uiSettings').get();
    await backupRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUserId,
      'type': 'automatic',
      'status': 'running',
      'collections': collectionNames,
      'documentCount': 0,
      'uiSettings': uiSettingsSnapshot.data(),
    });
    var total = 0;
    try {
      WriteBatch batch = db.batch();
      var batchCount = 0;
      Future<void> flush() async {
        if (batchCount == 0) return;
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
      for (final collectionName in collectionNames) {
        final snapshot = await db.collection(collectionName).get();
        for (final doc in snapshot.docs) {
          final safeId = '${collectionName}__${doc.id}';
          batch.set(backupRef.collection('items').doc(safeId), {
            'collection': collectionName,
            'documentId': doc.id,
            'data': doc.data(),
          });
          batchCount++;
          total++;
          // Documentele cu poze pot fi mari; loturi mici evită depășirea limitei de request.
          if (batchCount >= 8) await flush();
        }
      }
      await flush();
      await backupRef.set({
        'status': 'complete',
        'completedAt': FieldValue.serverTimestamp(),
        'documentCount': total,
      }, SetOptions(merge: true));
    } catch (e) {
      await backupRef.set({
        'status': 'failed',
        'error': e.toString().length > 500 ? e.toString().substring(0, 500) : e.toString(),
        'completedAt': FieldValue.serverTimestamp(),
        'documentCount': total,
      }, SetOptions(merge: true));
      rethrow;
    }
  }

  Future<void> _pruneAutomaticBackups() async {
    final db = FirebaseFirestore.instance;
    final cutoff = DateTime.now().subtract(Duration(days: settings.backupRetentionDays.clamp(1, 365)));
    final old = await db.collection('backups').where('createdAt', isLessThan: Timestamp.fromDate(cutoff)).get();
    for (final backup in old.docs) {
      final items = await backup.reference.collection('items').get();
      WriteBatch batch = db.batch();
      var count = 0;
      for (final item in items.docs) {
        batch.delete(item.reference);
        count++;
        if (count >= 300) { await batch.commit(); batch = db.batch(); count = 0; }
      }
      if (count > 0) await batch.commit();
      await backup.reference.delete();
    }
  }

  Future<void> _pruneOldNotifications() async {
    final db = FirebaseFirestore.instance;
    final cutoff = DateTime.now().subtract(Duration(days: settings.notificationHistoryDays.clamp(1, 365)));
    final old = await db.collection('notifications').where('createdAt', isLessThan: Timestamp.fromDate(cutoff)).get();
    WriteBatch batch = db.batch();
    var count = 0;
    for (final doc in old.docs) {
      batch.delete(doc.reference);
      count++;
      if (count >= 300) { await batch.commit(); batch = db.batch(); count = 0; }
    }
    if (count > 0) await batch.commit();
  }

  void _startCoreSync() {
    final db = FirebaseFirestore.instance;

    _coreSubscriptions.add(
      db.collection('locationCategories').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedDefinitionsIfNeeded());
          return;
        }
        final list = snap.docs.map(_categoryFromDoc).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final item = _categoryFromDoc(doc);
          _categoryCache[item.id] = _encoded(_categoryMap(item));
        }
        if (!mounted) return;
        setState(() { categories..clear()..addAll(list); });
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Categorii: $e'); }),
    );

    _coreSubscriptions.add(
      db.collection('backgrounds').snapshots().listen((snap) {
        final next=<String,Map<String,String>>{};
        for(final doc in snap.docs){
          final d=doc.data();
          if(d['active']==false)continue;
          final image=(d['imageBase64']??'').toString();
          if(image.isEmpty)continue;
          next[doc.id]={'name':(d['name']??doc.id).toString(),'imageBase64':image};
        }
        if(!mounted)return;
        setState((){settings.customBackgrounds..clear()..addAll(next);});
        WidgetsBinding.instance.addPostFrameCallback((_)=>widget.onSettingsChanged());
      },onError:(Object e){if(mounted)setState(()=>coreSyncError='Fundaluri: $e');}),
    );

    _coreSubscriptions.add(
      db.collection('functions').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedDefinitionsIfNeeded());
          return;
        }
        final list = snap.docs.map(_functionFromDoc).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final item = _functionFromDoc(doc);
          _functionCache[item.id] = _encoded(_functionMap(item));
        }
        if (!mounted) return;
        setState(() { functionDefinitions..clear()..addAll(list); });
        _startFinancialSync();
        if (isAdmin) unawaited(_syncUserPermissionSnapshots());
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Funcții: $e'); }),
    );

    _coreSubscriptions.add(
      (isAdmin ? db.collection('users') : db.collection('memberDirectory')).snapshots().listen((snap) {
        final list = snap.docs.map((doc) {
          final d = doc.data();
          final roleText = (d['role'] ?? 'member').toString();
          final role = roleText == 'admin' ? UserRole.director : UserRole.member;
          final function = FirebaseUserProfile._functionFrom(d['function']?.toString(), roleText);
          final email = (d['email'] ?? '').toString();
          var name = (d['name'] ?? '').toString().trim();
          final nickname = (d['nickname'] ?? '').toString().trim();
          if (d['useNickname'] == true && nickname.isNotEmpty) name = nickname;
          if (name.isEmpty) name = roleText == 'admin' ? 'Administrator' : (email.isEmpty ? doc.id : email.split('@').first);
          _userTeamCache[doc.id] = d['teamId']?.toString();
          if (doc.id == currentUserId) {
            _personalLocationMode = (d['locationMode'] ?? 'economic').toString();
            _personalLocationIntervalMinutes = (d['locationIntervalMinutes'] is num) ? (d['locationIntervalMinutes'] as num).toInt().clamp(1, 60).toInt() : 10;
            final rawNotificationPreferences=d['notificationPreferences'];
            if(rawNotificationPreferences is Map){for(final key in _personalNotificationPreferences.keys.toList()){if(rawNotificationPreferences[key] is bool)_personalNotificationPreferences[key]=rawNotificationPreferences[key] as bool;}}
            final rawGroupSeen = d['lastGroupChatSeenAt'];
            _lastGroupChatSeenAt = rawGroupSeen is Timestamp ? rawGroupSeen.toDate() : null;
            if (_recentGroupDocs.isNotEmpty) _recomputeGroupUnread();
            final personalTheme = AppThemeChoice.values.firstWhere((x) => x.name == (d['theme'] ?? settings.theme.name).toString(), orElse: () => settings.theme);
            final personalFont = _normalizeFontChoice((d['fontFamily'] ?? settings.fontFamily).toString());
            final visualChanged = personalTheme != settings.theme || personalFont != settings.fontFamily;
            settings.theme = personalTheme;
            // Fundalul este global și este controlat exclusiv de Admin.
            settings.personalBackgroundId = 'global';
            settings.fontFamily = personalFont;
            if (visualChanged) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSettingsChanged());
          }
          final functionIds = d['functionIds'] is List
              ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
              : <String>[(roleText == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList();
          return AppUser(
            id: doc.id,
            name: name,
            role: role,
            function: function,
            functionIds: functionIds,
            teamId: d['teamId']?.toString(),
            email: email,
            active: d['active'] == true,
            hiddenFromMembers: d['hiddenFromMembers'] == true,
            photoBase64: (d['photoBase64'] ?? '').toString(),
          );
        }).where((u) => isAdmin || !u.hiddenFromMembers || u.id == currentUserId).toList();
        final hiddenIds = snap.docs.where((doc) {
          final d = doc.data();
          return (d['role'] ?? '').toString() == 'admin' && d['hiddenFromMembers'] == true;
        }).map((doc) => doc.id).toSet();
        list.sort((a, b) {
          if (a.role != b.role) return a.role == UserRole.director ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        if (!mounted) return;
        setState(() {
          _hiddenUserIds
            ..clear()
            ..addAll(hiddenIds);
          users
            ..clear()
            ..addAll(list);
          if (!users.any((u) => u.id == currentUserId)) {
            users.add(AppUser(
              id: widget.profile.uid,
              name: widget.profile.name,
              role: widget.profile.isAdmin ? UserRole.director : UserRole.member,
              function: widget.profile.function,
              functionIds: widget.profile.functionIds,
              email: widget.profile.email,
              active: widget.profile.active,
            ));
          }
          _applyTeamMembership();
        });
        _startFinancialSync();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Conturi: $e');
      }),
    );

    // Datele private ale contului propriu nu sunt in directorul public.
    if (!isAdmin) _coreSubscriptions.add(
      db.collection('users').doc(currentUserId).snapshots().listen((snap) {
        final d = snap.data();
        if (d == null || !mounted) return;
        _personalLocationMode = (d['locationMode'] ?? 'economic').toString();
        _personalLocationIntervalMinutes = (d['locationIntervalMinutes'] is num)
            ? (d['locationIntervalMinutes'] as num).toInt().clamp(1, 60).toInt() : 10;
        final prefs = d['notificationPreferences'];
        if (prefs is Map) {
          for (final key in _personalNotificationPreferences.keys.toList()) {
            if (prefs[key] is bool) _personalNotificationPreferences[key] = prefs[key] as bool;
          }
        }
        final seen = d['lastGroupChatSeenAt'];
        _lastGroupChatSeenAt = seen is Timestamp ? seen.toDate() : null;
        if (_recentGroupDocs.isNotEmpty) _recomputeGroupUnread();
        final personalTheme = AppThemeChoice.values.firstWhere(
          (x) => x.name == (d['theme'] ?? settings.theme.name).toString(),
          orElse: () => settings.theme);
        final personalFont = _normalizeFontChoice((d['fontFamily'] ?? settings.fontFamily).toString());
        final visualChanged = personalTheme != settings.theme || personalFont != settings.fontFamily;
        settings.theme = personalTheme;
        settings.personalBackgroundId = 'global';
        settings.fontFamily = personalFont;
        if (visualChanged) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSettingsChanged());
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Profil propriu: $e'); }),
    );

    _coreSubscriptions.add(
      db.collection('teams').snapshots().listen((snap) {
        final list = snap.docs.map(_teamFromDoc).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final t = _teamFromDoc(doc);
          _teamCache[doc.id] = _encoded(_teamMap(t));
        }
        if (!mounted) return;
        setState(() {
          teams
            ..clear()
            ..addAll(list);
          _applyTeamMembership();
        });
        _startFinancialSync();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Echipe: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('cars').snapshots().listen((snap) {
        final list = snap.docs.map(_carFromDoc).toList()..sort((a, b) => a.plate.compareTo(b.plate));
        for (final doc in snap.docs) {
          final c = _carFromDoc(doc);
          _carCache[doc.id] = _encoded(_carMap(c));
        }
        if (!mounted) return;
        setState(() {
          cars
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Mașini: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('locations').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedLocationsIfNeeded());
          return;
        }
        final list = snap.docs.map(_locationFromDoc).toList()..sort((a, b) => a.id.compareTo(b.id));
        for (final doc in snap.docs) {
          final l = _locationFromDoc(doc);
          _locationCache[doc.id] = _encoded(_locationMap(l));
        }
        if (!mounted) return;
        setState(() {
          locations
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Locații: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('schedules').snapshots().listen((snap) {
        final list = snap.docs.map(_scheduleFromDoc).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        for (final doc in snap.docs) {
          final item = _scheduleFromDoc(doc);
          _scheduleCache[doc.id] = _encoded(_scheduleMap(item));
        }
        if (!mounted) return;
        setState(() {
          schedules
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Grafice de lucru: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('records').snapshots().listen((snap) {
        final list = snap.docs.map(_recordFromDoc).toList()
          ..sort((a, b) => (a.startedAt ?? DateTime(2000)).compareTo(b.startedAt ?? DateTime(2000)));
        for (final doc in snap.docs) {
          final item = _recordFromDoc(doc);
          _recordCache[doc.id] = _encoded(_recordMap(item));
        }
        if (!mounted) return;
        setState(() {
          records
            ..clear()
            ..addAll(list);
        });
        unawaited(_maybeAutoCloseResolvedSchedules(operationalWorkDate(DateTime.now())));
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Execuții: $e');
      }),
    );


    final Query<Map<String, dynamic>> notificationQuery = isAdmin
        ? db.collection('notifications')
        : db.collection('notifications').where('userId', isEqualTo: currentUserId);
    _coreSubscriptions.add(
      notificationQuery.snapshots().listen((snap) {
        final list = snap.docs.map(_notificationFromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final ownUnread = snap.docs.where((d) {
          final data = d.data();
          return (data['userId'] ?? '').toString() == currentUserId && data['read'] != true;
        }).toList();
        if (!_notificationsPrimed) {
          _knownNotificationIds.addAll(snap.docs.map((d) => d.id));
          _notificationsPrimed = true;
          final alertable=ownUnread.where((doc){final d=doc.data();return _allowPersonalAlert((d['title']??'Notificare').toString(),(d['message']??'').toString());}).toList();
          if (alertable.isNotEmpty) {
            _showIncomingPopup(
              title: alertable.length == 1 ? (alertable.first.data()['title']??'Notificare nouă').toString() : '${alertable.length} notificări necitite',
              body: alertable.length == 1 ? (alertable.first.data()['message'] ?? '').toString() : 'Le găsești în Setări → Istoric notificări.',
            );
          }
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null || (data['userId'] ?? '').toString() != currentUserId || data['read'] == true) continue;
            if (!_knownNotificationIds.add(doc.id)) continue;
            final title=(data['title']??'Notificare nouă').toString();final body=(data['message']??'').toString();
            if(_allowPersonalAlert(title,body))_showIncomingPopup(title:title,body:body);
          }
          _knownNotificationIds.addAll(snap.docs.map((d) => d.id));
        }
        if (!mounted) return;
        setState(() {
          notifications
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Notificări: $e');
      }),
    );

    String visibleSenderName(Map<String, dynamic> data) {
      final senderId = (data['senderId'] ?? '').toString();
      if (!isAdmin && _hiddenUserIds.contains(senderId)) return 'Sistem';
      return (data['senderName'] ?? 'un membru').toString();
    }

    bool mandatoryChatAlert(Map<String,dynamic> data) {
      final senderId=(data['senderId']??'').toString();
      if(_hiddenUserIds.contains(senderId))return true;
      return users.any((u)=>u.id==senderId&&u.role==UserRole.director);
    }

    _coreSubscriptions.add(
      db.collection('chatMessages').where('recipientId', isEqualTo: currentUserId).snapshots().listen((snap) {
        final unread = snap.docs.where((d) {
          final data = d.data();
          final deletedFor = data['deletedFor'];
          final senderId = (data['senderId'] ?? '').toString();
          if (!isAdmin && _hiddenUserIds.contains(senderId)) return false;
          return data['read'] != true && !(deletedFor is List && deletedFor.map((e) => e.toString()).contains(currentUserId));
        }).toList();
        if (!_messagesPrimed) {
          _knownIncomingMessageIds.addAll(snap.docs.map((d) => d.id));
          _messagesPrimed = true;
          final mandatoryUnread=unread.any((doc)=>mandatoryChatAlert(doc.data()));
          if (unread.isNotEmpty && ((_personalNotificationPreferences['chat']??true)||mandatoryUnread)) {
            final one = unread.length == 1 ? unread.first.data() : null;
            _showIncomingPopup(
              title: unread.length == 1 ? 'Mesaj nou de la ${visibleSenderName(one!)}' : '${unread.length} mesaje necitite',
              body: unread.length == 1 ? (one?['text'] ?? '').toString() : 'Deschide Chat live pentru conversații.',
              onView: one == null ? ()=>_openMembersDirectory(chatMode:true) : () => unawaited(_openChatFromAlert((one['senderId'] ?? '').toString())),
            );
          }
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null || data['read'] == true || !_knownIncomingMessageIds.add(doc.id)) continue;
            if((_personalNotificationPreferences['chat']??true)||mandatoryChatAlert(data))_showIncomingPopup(
              title: 'Mesaj nou de la ${visibleSenderName(data)}',
              body: (data['text'] ?? '').toString(),
              onView: () => unawaited(_openChatFromAlert((data['senderId'] ?? '').toString())),
            );
          }
          _knownIncomingMessageIds.addAll(snap.docs.map((d) => d.id));
        }
        _unreadPrivateMessageCount = unread.length;
        _refreshUnreadMessageCount();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Mesaje: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('groupChatMessages').orderBy('createdAt', descending: true).limit(20).snapshots().listen((snap) {
        final docs = snap.docs;
        _recentGroupDocs = docs;
        _recomputeGroupUnread();
        if (!_groupMessagesPrimed) {
          _knownGroupMessageIds.addAll(docs.map((d) => d.id));
          _groupMessagesPrimed = true;
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null) continue;
            if ((data['senderId'] ?? '').toString() == currentUserId || !_knownGroupMessageIds.add(doc.id)) continue;
            if (_personalNotificationPreferences['chat'] ?? true) {
              _showIncomingPopup(
                title: 'Mesaj nou în Chat live',
                body: '${(data['senderName'] ?? 'Membru').toString()}: ${(data['text'] ?? '').toString()}',
                onView: _openGroupChat,
              );
            }
          }
          _knownGroupMessageIds.addAll(docs.map((d) => d.id));
        }
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Chat comun: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('meta').doc('uiSettings').snapshots().listen((snap) {
        final d = snap.data();
        if (!mounted) return;
        if (d == null) { if (isAdmin) unawaited(_runAutomaticMaintenance()); return; }
        setState(() {
          settings.background = (d['background'] ?? settings.background).toString();
          settings.brandingBackgroundId = (d['brandingBackgroundId'] ?? settings.brandingBackgroundId).toString();
          settings.brandingLogoId = (d['brandingLogoId'] ?? settings.brandingLogoId).toString();
          settings.androidDownloadUrl = (d['androidDownloadUrl'] ?? settings.androidDownloadUrl).toString();
          final smsTime = (d['smsPreviousDayTime'] ?? settings.smsPreviousDayTime).toString().trim();
          if (RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(smsTime)) settings.smsPreviousDayTime = smsTime;
          final rawTemplates = d['smsTemplates'];
          if (rawTemplates is Map) {
            for (final key in <String>['initial','rescheduled','postponed']) {
              final value = rawTemplates[key]?.toString().trim();
              if (value != null && value.isNotEmpty) settings.smsTemplates[key] = value;
            }
          }
          if (d['backgroundOpacity'] is num) settings.backgroundOpacity = (d['backgroundOpacity'] as num).toDouble().clamp(0.0, .70).toDouble();
          if (d['defaultPerDiem'] is num) settings.defaultPerDiem = (d['defaultPerDiem'] as num).toDouble();
          if (d['allowUndo'] is bool) settings.allowUndo = d['allowUndo'] as bool;
          if (d['autoStart'] is bool) settings.autoStart = d['autoStart'] as bool;
          if (d['autoFinish'] is bool) settings.autoFinish = d['autoFinish'] as bool;
          if (d['autoCloseWhenAllDone'] is bool) settings.autoCloseWhenAllDone = d['autoCloseWhenAllDone'] as bool;
          if (d['pushNotifications'] is bool) settings.pushNotifications = d['pushNotifications'] as bool;
          if (d['automaticBackup'] is bool) settings.automaticBackup = d['automaticBackup'] as bool;
          if (d['backupRetentionDays'] is num) settings.backupRetentionDays = (d['backupRetentionDays'] as num).toInt().clamp(1,365).toInt();
          if (d['notificationHistoryDays'] is num) settings.notificationHistoryDays = (d['notificationHistoryDays'] as num).toInt().clamp(1,365).toInt();
          final rawLearning = d['learning'];
          if (rawLearning is Map) {
            for (final entry in settings.learning.entries) {
              final raw = rawLearning[entry.key];
              if (raw is! Map) continue;
              if (raw['enabled'] is bool) entry.value.enabled = raw['enabled'] as bool;
              final modeName = raw['mode']?.toString();
              for (final mode in LearningMode.values) {
                if (mode.name == modeName) entry.value.mode = mode;
              }
            }
          }
        });
        if (isAdmin) unawaited(_runAutomaticMaintenance());
      }, onError: (Object e) {
        if (mounted && isAdmin) setState(() => coreSyncError = 'Setări UI: $e');
      }),
    );

    if (isAdmin) {
      _coreSubscriptions.add(
        db.collection('audit').orderBy('at', descending: true).limit(500).snapshots().listen((snap) {
          final list = snap.docs.map((doc) {
            final d = doc.data();
            return AuditEntry(
              id: doc.id,
              actor: (d['actor'] ?? '').toString(),
              action: (d['action'] ?? '').toString(),
              target: (d['target'] ?? '').toString(),
              at: _dateFrom(d['at']) ?? DateTime.now(),
            );
          }).toList();
          if (!mounted) return;
          setState(() {
            audit
              ..clear()
              ..addAll(list);
          });
        }, onError: (Object e) {
          if (mounted) setState(() => coreSyncError = 'Audit: $e');
        }),
      );
      unawaited(_seedLocationsIfNeeded());
      unawaited(_seedDefinitionsIfNeeded());
      unawaited(_migrateFunctionBadgeSystemIfNeeded());
    }
    _startFinancialSync();
  }

  Set<String> _effectivePermissionsForIds(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      final def = functionById(functionDefinitions, id);
      if (def != null && def.active) out.addAll(def.permissions);
    }
    return out;
  }

  Future<void> _syncUserPermissionSnapshots() async {
    if (!isAdmin || _permissionSyncInFlight || functionDefinitions.isEmpty) return;
    _permissionSyncInFlight = true;
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db.collection('users').get();
      final batch = db.batch();
      var writes = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final role = (d['role'] ?? 'member').toString();
        final functionIds = d['functionIds'] is List
            ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
            : <String>[(role == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList();
        final effective = role == 'admin'
            ? FunctionPermission.values.map((e) => e.name).toSet()
            : _effectivePermissionsForIds(functionIds);
        final current = d['effectivePermissions'] is List
            ? (d['effectivePermissions'] as List).map((e) => e.toString()).toSet()
            : <String>{};
        if (current.length == effective.length && current.containsAll(effective)) continue;
        final sorted = effective.toList()..sort();
        batch.set(doc.reference, {
          'effectivePermissions': sorted,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        writes++;
      }
      if (writes > 0) await batch.commit();
    } catch (e) {
      if (mounted) setState(() => coreSyncError = 'Sincronizare drepturi: $e');
    } finally {
      _permissionSyncInFlight = false;
    }
  }

  Future<void> _seedLocationsIfNeeded() async {
    final col = FirebaseFirestore.instance.collection('locations');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final l in _seedLocations()) {
      batch.set(col.doc(l.id), _locationMap(l));
    }
    await batch.commit();
  }

  Future<void> _seedDefinitionsIfNeeded() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final categoriesCol = db.collection('locationCategories');
    final functionsCol = db.collection('functions');
    final existingCategories = await categoriesCol.limit(1).get();
    final existingFunctions = await functionsCol.limit(1).get();
    final batch = db.batch();
    var writes = 0;
    if (existingCategories.docs.isEmpty) {
      for (final c in defaultLocationCategories()) { batch.set(categoriesCol.doc(c.id), _categoryMap(c)); writes++; }
    }
    if (existingFunctions.docs.isEmpty) {
      for (final f in defaultFunctionDefinitions()) { batch.set(functionsCol.doc(f.id), _functionMap(f)); writes++; }
    }
    if (writes > 0) await batch.commit();
  }

  Future<void> _migrateFunctionBadgeSystemIfNeeded() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final metaRef = db.collection('meta').doc('uiSettings');
    final metaSnap = await metaRef.get();
    if ((metaSnap.data()?['functionSystemVersion'] ?? '').toString() == 'badge_v2') return;

    final usersSnap = await db.collection('users').get();
    final functionsSnap = await db.collection('functions').get();
    final adminFunction = defaultFunctionDefinitions().first;
    final allPermissions = FunctionPermission.values.map((e) => e.name).toList()..sort();

    WriteBatch batch = db.batch();
    var writes = 0;
    Future<void> flush() async {
      if (writes == 0) return;
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }

    for (final doc in functionsSnap.docs) {
      batch.delete(doc.reference);
      writes++;
      if (writes >= 350) await flush();
    }
    batch.set(db.collection('functions').doc(adminFunction.id), _functionMap(adminFunction));
    writes++;
    if (writes >= 350) await flush();

    for (final doc in usersSnap.docs) {
      final role = (doc.data()['role'] ?? 'member').toString();
      final isDocAdmin = role == 'admin';
      batch.set(doc.reference, {
        'function': isDocAdmin ? 'admin' : '',
        'functionIds': isDocAdmin ? <String>['admin'] : <String>[],
        'effectivePermissions': isDocAdmin ? allPermissions : <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      writes++;
      if (writes >= 350) await flush();
    }

    batch.set(metaRef, {'functionSystemVersion': 'badge_v2', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    writes++;
    await flush();
  }

  Future<void> _writeLearningEvent({
    required String category,
    required String event,
    String teamId = '',
    String locationId = '',
    String scheduleId = '',
    Map<String, dynamic>? data,
  }) async {
    final cfg = settings.learning[category];
    if (cfg?.enabled == false) return;
    try {
      final id = idNow();
      await FirebaseFirestore.instance.collection('learningEvents').doc(id).set({
        'actorUid': currentUserId,
        'actor': me.name,
        'category': category,
        'event': event,
        'teamId': teamId,
        'locationId': locationId,
        'scheduleId': scheduleId,
        'mode': cfg?.mode.name ?? LearningMode.manualApproval.name,
        'data': data ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[learning] Nu s-a putut salva evenimentul $category/$event: $e');
    }
  }

  Future<void> _deleteLocationDirect(String id) async {
    if (!isAdmin) throw StateError('Doar Adminul poate șterge locații.');
    await FirebaseFirestore.instance.collection('locations').doc(id).delete();
    unawaited(_writeLearningEvent(category: 'operations', event: 'location_deleted', locationId: id));
    _locationCache.remove(id);
    if (!mounted) return;
    setState(() => locations.removeWhere((x) => x.id == id));
  }

  Future<void> _saveLocationDirect(Location l) async {
    if (!isAdmin) throw StateError('Doar Adminul poate modifica locații.');
    final data = _locationMap(l);
    await FirebaseFirestore.instance.collection('locations').doc(l.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'operations', event: 'location_saved', locationId: l.id, data: {
      'name': l.name, 'status': l.status.name, 'active': l.active, 'hasGps': l.latitude != null && l.longitude != null,
    }));
    _locationCache[l.id] = _encoded(data);
    if (!mounted) return;
    setState(() {
      final index = locations.indexWhere((x) => x.id == l.id);
      if (index >= 0) {
        locations[index] = l;
      } else {
        locations.add(l);
      }
      locations.sort((a, b) => a.id.compareTo(b.id));
    });
  }

  Future<void> _saveScheduleDirect(WorkSchedule schedule) async {
    if (!canEditTeam(schedule.teamId) || !hasPermission(FunctionPermission.editProgram)) {
      throw StateError('Nu ai dreptul să modifici acest Grafic de lucru.');
    }
    final data = _scheduleMap(schedule);
    await FirebaseFirestore.instance.collection('schedules').doc(schedule.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'program', event: 'schedule_saved', teamId: schedule.teamId, scheduleId: schedule.id, data: {
      'date': schedule.date.toIso8601String(), 'started': schedule.started, 'closed': schedule.closed,
      'paused': schedule.paused, 'postponed': schedule.postponed, 'order': schedule.items.map((e) => e.locationId).toList(),
      'autoProposed': schedule.autoProposed, 'learningConfidence': schedule.learningConfidence,
    }));
    _scheduleCache[schedule.id] = _encoded(data);
    if (!mounted) return;
    setState(() {
      final index = schedules.indexWhere((x) => x.id == schedule.id);
      if (index >= 0) {
        schedules[index] = schedule;
      } else {
        schedules.add(schedule);
      }
    });
  }

  Future<void> _saveRecordDirect(CentralizerRecord record) async {
    final canWriteRecord = hasPermission(FunctionPermission.editProgram) || hasPermission(FunctionPermission.editCentralizer);
    if (!canEditTeam(record.teamId) || !canWriteRecord) {
      throw StateError('Nu ai dreptul să modifici execuțiile acestei echipe.');
    }
    final data = _recordMap(record);
    await FirebaseFirestore.instance.collection('records').doc(record.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'duration', event: 'execution_${record.status.name}', teamId: record.teamId, locationId: record.locationId, data: {
      'startedAt': record.startedAt?.toIso8601String(), 'finishedAt': record.finishedAt?.toIso8601String(),
      'durationSeconds': record.duration?.inSeconds, 'waitingSeconds': record.waitingDuration?.inSeconds,
      'refusalReason': record.refusalReason ?? '', 'keptForLearning': record.keptForLearning,
    }));
    _recordCache[record.id] = _encoded(data);
    if (!mounted) return;
    setState(() {
      final index = records.indexWhere((x) => x.id == record.id);
      if (index >= 0) {
        records[index] = record;
      } else {
        records.add(record);
      }
    });
  }

  Future<void> _saveExpenseDirect(Expense expense) async {
    if (!canEditTeam(expense.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw StateError('Nu ai dreptul să modifici Decontul acestei echipe.');
    }
    final data = _expenseMap(expense);
    await FirebaseFirestore.instance.collection('expenses').doc(expense.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: expense.ocrRawText.trim().isNotEmpty ? 'ocr' : 'finance', event: 'expense_saved', teamId: expense.teamId, data: {
      'category': expense.category, 'amount': expense.amount, 'documentType': expense.documentType.name,
      'ocrConfidence': expense.ocrConfidence, 'confirmed': expense.confirmed, 'hasImage': expense.hasImage,
    }));
    _expenseCache[expense.id] = _encoded(data);
  }

  Future<void> _savePerDiemDirect(PerDiemEntry entry) async {
    final canWrite = isAdmin || entry.memberId == currentUserId ||
        (canEditTeam(entry.teamId) && hasPermission(FunctionPermission.viewOwnDecont));
    if (!canWrite) throw StateError('Nu ai dreptul să modifici această diurnă.');
    final data = _perDiemMap(entry);
    // Confirmarea sau refuzul se salvează atomic. Verificarea exclusiv în UI
    // nu poate preveni două confirmări simultane de pe dispozitive diferite.
    final isReceiptResponse = entry.distributedBy != null &&
        (entry.status == PerDiemStatus.confirmed ||
         (entry.status == PerDiemStatus.awaitingConfirmation && entry.received == false));
    final db = FirebaseFirestore.instance;
    final ref = db.collection('perDiems').doc(entry.id);
    if (isReceiptResponse) {
      if (entry.memberId != currentUserId) {
        throw StateError('Doar beneficiarul poate confirma primirea diurnei.');
      }
      // 79–86: validarea se face înainte de tranzacție, iar în tranzacție
      // verificăm documentul curent, nu datele posibil învechite din UI.
      final received = entry.actualReceivedAmount;
      final receivedBani = received == null ? null :
          (received.isFinite ? parsePerDiemBani(received.toString()) : null);
      final isRefusal = entry.received == false &&
          entry.status == PerDiemStatus.awaitingConfirmation && received == null;
      if (!isRefusal && (entry.status != PerDiemStatus.confirmed ||
          entry.received != true || receivedBani == null || receivedBani <= 0)) {
        throw StateError('Confirmare invalidă: suma primită trebuie să fie pozitivă.');
      }
      if (FirebaseAuth.instance.currentUser?.uid != currentUserId) {
        throw StateError('Sesiunea de autentificare nu corespunde beneficiarului.');
      }
      final auditRef = ref.collection('receiptAudit').doc();
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Distribuirea nu mai există.');
        final previous = snap.data()!;
        if (previous['memberId'] != currentUserId ||
            previous['distributedBy'] == null ||
            previous['status'] != PerDiemStatus.awaitingConfirmation.name ||
            previous['actualReceivedAmount'] != null) {
          throw StateError('Diurna a fost deja confirmată sau modificată. Reîncarcă datele.');
        }
        if (previous['distributedBy'] is! String ||
            (previous['distributedBy'] as String).isEmpty) {
          throw StateError('Distribuitorul acestei diurne este invalid.');
        }
        final declared = previous['amount'];
        if (declared is! num || !declared.toDouble().isFinite ||
            declared <= 0 || parsePerDiemBani(declared.toString()) == null) {
          throw StateError('Suma declarată nu este validă.');
        }
        if (isRefusal && previous['received'] == false) {
          throw StateError('Refuzul a fost deja înregistrat.');
        }
        // Valoarea declarată, identitatea și echipa NU sunt modificate.
        final declaredBani = parsePerDiemBani(declared.toString())!;
        final changes = <String, dynamic>{
          'received': !isRefusal,
          'actualReceivedAmount': isRefusal ? null : receivedBani! / 100,
          'status': isRefusal ? PerDiemStatus.awaitingConfirmation.name
              : PerDiemStatus.confirmed.name,
          'confirmedAt': isRefusal ? null : FieldValue.serverTimestamp(),
          'receiptUpdatedAt': FieldValue.serverTimestamp(),
        };
        tx.update(ref, changes);
        tx.set(auditRef, {
          'actorUid': currentUserId,
          'action': isRefusal ? 'reported_missing' : 'confirmed_received',
          'distributorId': previous['distributedBy'],
          'beneficiaryId': previous['memberId'],
          'declaredAmountBani': declaredBani,
          'actualReceivedBani': isRefusal ? 0 : receivedBani,
          'differenceBani': declaredBani - (isRefusal ? 0 : receivedBani!),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      // Distribuirea este imuabilă: nu suprascriem confirmări existente.
      await db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) {
          throw StateError('Această distribuire există deja.');
        }
        tx.set(ref, data);
      });
    }
    unawaited(_writeLearningEvent(category: 'finance', event: 'per_diem_saved', teamId: entry.teamId, data: {
      'memberId': entry.memberId, 'amount': entry.amount, 'status': entry.status.name, 'method': entry.method?.name ?? '',
    }));
    _perDiemCache[entry.id] = _encoded(data);
  }

  Future<void> _saveSettlementDirect(TravelSettlement settlement) async {
    if (!canEditTeam(settlement.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw StateError('Nu ai dreptul să modifici această deplasare.');
    }
    await FirebaseFirestore.instance.collection('settlements').doc(settlement.id).set(_settlementMap(settlement), SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'finance', event: 'settlement_saved', teamId: settlement.teamId, data: {
      'name': settlement.name, 'closed': settlement.closed, 'received': settlement.totalReceived,
    }));
  }

  Future<void> _saveFinanceDirect(TeamFinance finance) async {
    if (!canEditTeam(finance.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw StateError('Nu ai dreptul să modifici datele financiare ale acestei echipe.');
    }
    final data = _financeMap(finance);
    await FirebaseFirestore.instance.collection('finance').doc(finance.teamId).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'finance', event: 'team_finance_saved', teamId: finance.teamId, data: {
      'receivedDeparture': finance.receivedDeparture, 'receivedDuring': finance.receivedDuring, 'perDiemRate': finance.perDiemRate,
    }));
    _financeCache[finance.teamId] = _encoded(data);
  }

  Future<void> _writeAuditRemote(String action, String target) async {
    final entry = AuditEntry(id: idNow(), actor: me.name, action: action, target: target, at: DateTime.now());
    if (isAdmin && mounted) {
      setState(() => audit.insert(0, entry));
    }
    try {
      await FirebaseFirestore.instance.collection('audit').doc(entry.id).set({
        'actorUid': currentUserId,
        'actor': me.name,
        'action': action,
        'target': target,
        'at': Timestamp.fromDate(entry.at),
      });
      unawaited(_writeLearningEvent(category: 'operations', event: 'audit_action', data: {'action': action, 'target': target}));
    } catch (_) {
      // Auditul nu trebuie să blocheze operația principală; eroarea poate fi urmărită separat.
    }
  }

  Future<void> _persistCoreData() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final pendingLocations = <String, String>{};
    final pendingTeams = <String, String>{};
    final pendingCars = <String, String>{};
    final pendingUsers = <String, String?>{};
    var writes = 0;

    for (final l in locations) {
      final data = _locationMap(l);
      final encoded = _encoded(data);
      if (_locationCache[l.id] != encoded) {
        batch.set(db.collection('locations').doc(l.id), data, SetOptions(merge: true));
        pendingLocations[l.id] = encoded;
        writes++;
      }
    }

    for (final t in teams) {
      final data = _teamMap(t);
      final encoded = _encoded(data);
      if (_teamCache[t.id] != encoded) {
        batch.set(db.collection('teams').doc(t.id), data, SetOptions(merge: true));
        pendingTeams[t.id] = encoded;
        writes++;
      }
    }

    for (final c in cars) {
      final data = _carMap(c);
      final encoded = _encoded(data);
      if (_carCache[c.id] != encoded) {
        batch.set(db.collection('cars').doc(c.id), data, SetOptions(merge: true));
        pendingCars[c.id] = encoded;
        writes++;
      }
    }

    for (final u in users) {
      if (_userTeamCache[u.id] != u.teamId) {
        batch.set(db.collection('users').doc(u.id), {'teamId': u.teamId}, SetOptions(merge: true));
        pendingUsers[u.id] = u.teamId;
        writes++;
      }
    }

    if (writes == 0) return;
    await batch.commit();
    _locationCache.addAll(pendingLocations);
    _teamCache.addAll(pendingTeams);
    _carCache.addAll(pendingCars);
    _userTeamCache.addAll(pendingUsers);
  }

  @override
  void dispose() {
    for (final sub in _coreSubscriptions) { sub.cancel(); }
    for (final sub in _financialSubscriptions) { sub.cancel(); }
    _liveLocationTimer?.cancel();
    _backgroundLocationSubscription?.cancel();
    super.dispose();
  }


  AppUser get me => users.firstWhere(
        (u) => u.id == currentUserId,
        orElse: () => AppUser(
          id: widget.profile.uid,
          name: widget.profile.name,
          role: widget.profile.isAdmin ? UserRole.director : UserRole.member,
          function: widget.profile.function,
          functionIds: widget.profile.functionIds,
          email: widget.profile.email,
          active: widget.profile.active,
        ),
      );
  bool get isAdmin => widget.profile.isAdmin;
  bool canEditTeam(String id) {
    if (isAdmin) return true;
    final matches = teams.where((t) => t.id == id);
    return matches.isNotEmpty && matches.first.members.contains(currentUserId);
  }
  String userName(String id) {
    if (!isAdmin && _hiddenUserIds.contains(id)) return 'Sistem';
    return users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: id, name: 'Membru', role: UserRole.member)).name;
  }
  void log(String action, String target) { unawaited(_writeAuditRemote(action, target)); }
  String _notificationCategory(String title,String message){
    final t='$title $message'.toLowerCase();
    if(t.contains('diurn')||t.contains('decont')||t.contains('cheltu'))return 'decont';
    if(t.contains('sosir')||t.contains('locați')||t.contains('locati')||t.contains('gps'))return 'arrival';
    if(t.contains('learning')||t.contains('estim')||t.contains('recomand'))return 'learning';
    if(t.contains('grafic')||t.contains('program')||t.contains('traseu')||t.contains('plan'))return 'schedule';
    return 'general';
  }
  bool _allowPersonalAlert(String title,String message){
    if(title.trim().toLowerCase()=='sistem'||title.trim().toLowerCase().contains('admin'))return true;
    return _personalNotificationPreferences[_notificationCategory(title,message)]??true;
  }
  void notifyUser(String uid, String title, String msg) {
    if (!settings.pushNotifications) return;
    final n = AppNotification(id: idNow(), userId: uid, title: title, message: msg, createdAt: DateTime.now());
    if (mounted && (isAdmin || uid == currentUserId)) setState(() => notifications.insert(0, n));
    unawaited(FirebaseFirestore.instance.collection('notifications').doc(n.id).set(_notificationMap(n)).catchError((Object e) {
      if (mounted) setState(() => coreSyncError = 'Notificare: $e');
    }));
  }
  void notifyTeam(String teamId, String title, String msg) {
    final matches = teams.where((t) => t.id == teamId);
    if (matches.isEmpty) return;
    for (final uid in matches.first.members) {
      notifyUser(uid, title, msg);
    }
  }
  void refresh() {
    // Refresh-urile operaționale nu trebuie să reconstruiască MaterialApp/AuthGate.
    // Tema este propagată separat doar când se schimbă efectiv în Firestore.
    setState(() {});
    if (isAdmin) {
      unawaited(_persistCoreData().catchError((Object e) {
        if (!mounted) return;
        setState(() => coreSyncError = 'Salvare Firestore: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Salvarea nu a reușit: $e')));
      }));
    }
  }

  bool hasPermission(FunctionPermission permission) {
    if (isAdmin) return true;
    final ids = me.functionIds;
    if (ids.isEmpty) return false;
    for (final id in ids) {
      final def = functionById(functionDefinitions, id);
      if (def != null && def.active && def.permissions.contains(permission.name)) return true;
    }
    // Compatibilitate pentru conturile vechi până când colecția functions este populată.
    if (ids.contains(me.function.name)) {
      final fallback = settings.functionPermissions[me.function];
      return fallback?.contains(permission) ?? false;
    }
    return false;
  }

  void _recomputeGroupUnread() {
    final seenAt = _lastGroupChatSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    _unreadGroupMessageCount = _recentGroupDocs.where((doc) {
      final data = doc.data();
      if ((data['senderId'] ?? '').toString() == currentUserId) return false;
      final raw = data['createdAt'];
      final createdAt = raw is Timestamp ? raw.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      return createdAt.isAfter(seenAt);
    }).length;
    _refreshUnreadMessageCount();
  }

  void _refreshUnreadMessageCount() {
    if (!mounted) return;
    setState(() => _unreadMessageCount = _unreadPrivateMessageCount + _unreadGroupMessageCount);
  }

  void _openGroupChat() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupChatPage(currentUser: me, users: users, functionDefinitions: functionDefinitions))).then((_) {
      _unreadGroupMessageCount = 0;
      _refreshUnreadMessageCount();
    });
  }

  void _openMembersDirectory({bool chatMode=false}) {
    // Directorul membrilor este disponibil tuturor utilizatorilor autentificați.
    // Documentele sunt proiectate în memberDirectory fără date private.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MembersDirectoryPage(currentUser: me, functionDefinitions: functionDefinitions, chatMode: chatMode),
    ));
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(
      user: me,
      teams: teams,
      functionDefinitions: functionDefinitions,
      records: records,
      perDiems: perDiems,
    )));
  }

  Future<void> _openNotificationsSheet() async {
    final mine = notifications.where((n) => n.userId == currentUserId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Notificări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Închide')),
                  ],
                ),
              ),
              Expanded(
                child: mine.isEmpty
                    ? const Center(child: Text('Nu ai notificări.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                        children: mine.take(50).map((n) => Card(
                          child: ListTile(
                            leading: Icon(n.read ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined),
                            title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w900)),
                            subtitle: Text('${n.message}\n${formatDate(n.createdAt)} · ${timeText(n.createdAt)}'),
                            isThreeLine: true,
                            onTap: n.read ? null : () async {
                              n.read = true;
                              await FirebaseFirestore.instance.collection('notifications').doc(n.id).set({'read': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                              if (mounted) setState(() {});
                            },
                          ),
                        )).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppInformationPage(settings: settings, isAdmin: isAdmin)));
  }

  @override
  Widget build(BuildContext context) {
    final compactNav = MediaQuery.sizeOf(context).width < 650;
    final myPhoto = decodeProfilePhoto(me.photoBase64);
    final myUnreadNotifications = notifications.where((n) => n.userId == currentUserId && !n.read).length;
    final pages = <Widget>[];
    final destinations = <NavigationDestination>[];
    final tabColors = <Color>[];

    void addPage(bool allowed, Widget page, NavigationDestination destination, Color color) {
      if (!allowed) return;
      pages.add(page);
      destinations.add(destination);
      tabColors.add(color);
    }

    const homeColor = Color(0xff2F6BFF);
    const programColor = Color(0xff7C4DFF);
    const mapColor = Color(0xff00A884);
    const centralizerColor = Color(0xffFF8A00);
    const decontColor = Color(0xff00A86B);
    const messagesColor = Color(0xff0F9D58);
    const docsColor = Color(0xff536DFE);
    const settingsColor = Color(0xff607D8B);

    addPage(hasPermission(FunctionPermission.viewDashboard),
      DashboardPage(teams: teams, users: users, functionDefinitions: functionDefinitions, locations: locations, categories: categories, schedules: schedules, records: records, settings: settings, currentUser: me, canEditProgram: hasPermission(FunctionPermission.editProgram), userName: userName, onChanged: refresh, saveRecord: _saveRecordDirect, saveSchedule: _saveScheduleDirect, log: log),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_dashboard.png', size: 24, accent: homeColor), selectedIcon: appAssetIcon('assets/ui/tab_dashboard.png', size: 27, accent: homeColor, selected: true), label: 'Acasă'), homeColor);
    addPage(hasPermission(FunctionPermission.viewProgram),
      ProgramPage(currentUser: me, teams: teams, cars: cars, locations: locations, categories: categories, schedules: schedules, records: records, settings: settings, canEditTeam: canEditTeam, canEditProgram: hasPermission(FunctionPermission.editProgram), userName: userName, onChanged: refresh, notifyTeam: notifyTeam, log: log, saveSchedule: _saveScheduleDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_grafic.png', size: 24, accent: programColor), selectedIcon: appAssetIcon('assets/ui/tab_grafic.png', size: 27, accent: programColor, selected: true), label: 'Grafic'), programColor);
    addPage(hasPermission(FunctionPermission.viewMap),
      MapPage(currentUser: me, users: users, teams: teams, schedules: schedules, records: records, locations: locations, categories: categories, isAdmin: isAdmin, hiddenUserIds: _hiddenUserIds, onChanged: refresh, log: log, saveLocation: _saveLocationDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_harta.png', size: 24, accent: mapColor), selectedIcon: appAssetIcon('assets/ui/tab_harta.png', size: 27, accent: mapColor, selected: true), label: 'Hartă'), mapColor);
    addPage(hasPermission(FunctionPermission.viewCentralizer),
      CentralizerPage(currentUser: me, teams: teams, locations: locations, categories: categories, schedules: schedules, records: records, isAdmin: isAdmin, canEditTeam: canEditTeam, canEditCentralizer: hasPermission(FunctionPermission.editCentralizer), onChanged: refresh, log: log, saveRecord: _saveRecordDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_centralizator.png', size: 24, accent: centralizerColor), selectedIcon: appAssetIcon('assets/ui/tab_centralizator.png', size: 27, accent: centralizerColor, selected: true), label: compactNav ? 'Central.' : 'Centralizator'), centralizerColor);
    addPage(hasPermission(FunctionPermission.viewOwnDecont) || hasPermission(FunctionPermission.viewOtherDecont),
      ExpensePage(currentUser: me, teams: teams, users: users, expenses: expenses, perDiems: perDiems, finances: finances, settlements: settlements, settings: settings, canEditTeam: canEditTeam, isAdmin: isAdmin, canEditOwnDecont: hasPermission(FunctionPermission.viewOwnDecont), canViewOtherDecont: hasPermission(FunctionPermission.viewOtherDecont), onChanged: refresh, notifyUser: notifyUser, log: log, saveExpense: _saveExpenseDirect, savePerDiem: _savePerDiemDirect, saveFinance: _saveFinanceDirect, saveSettlement: _saveSettlementDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_decont.png', size: 24, accent: decontColor), selectedIcon: appAssetIcon('assets/ui/tab_decont.png', size: 27, accent: decontColor, selected: true), label: 'Decont'), decontColor);
    addPage(hasPermission(FunctionPermission.viewContacts),
      MessagesContactsPage(locations:locations,settings:settings,canEditContacts:hasPermission(FunctionPermission.editContacts),canManageTemplates:hasPermission(FunctionPermission.manageMessageTemplates),onChanged:refresh,log:log),
      NavigationDestination(icon: appAssetIcon('assets/ui/chat_live.png', size: 24, accent: messagesColor), selectedIcon: appAssetIcon('assets/ui/chat_live.png', size: 27, accent: messagesColor, selected: true), label: compactNav ? 'Contacte' : 'Mesaje'), messagesColor);
    addPage(true, DocumentsPage(isAdmin: isAdmin),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_documente.png', size: 24, accent: docsColor), selectedIcon: appAssetIcon('assets/ui/tab_documente.png', size: 27, accent: docsColor, selected: true), label: compactNav ? 'Doc.' : 'Documente'), docsColor);
    addPage(true,
      SettingsPage(user: me, notifications: notifications, settings: settings, onChanged: refresh, onThemeChanged: widget.onSettingsChanged, onAdmin: isAdmin ? () => _openAdmin() : null, onLogout: () => FirebaseAuth.instance.signOut()),
      const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: settingsColor), label: 'Setări'), settingsColor);

    if (pages.isEmpty) {
      pages.add(const _Empty(icon: Icons.lock_outline, text: 'Contul nu are încă drepturi de acces. Contactează Adminul.'));
      destinations.add(const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Cont'));
      tabColors.add(settingsColor);
    }
    if (tab >= pages.length) tab = 0;
    final selectedColor = tabColors[tab];

    return Scaffold(
      endDrawerEnableOpenDragGesture: true,
      endDrawer: kIsWeb ? Drawer(
        width: math.min(MediaQuery.sizeOf(context).width * .88, 330.0),
        child: SafeArea(child: Column(children: [
          ListTile(title: const Text('Categorii', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), trailing: Builder(builder: (drawerContext) => IconButton(icon: const Icon(Icons.close), tooltip: 'Închide meniul', onPressed: () => Navigator.of(drawerContext).pop()))),
          const Divider(height: 1),
          Expanded(child: ListView.builder(itemCount: destinations.length, itemBuilder: (drawerContext, i) => ListTile(
            leading: destinations[i].icon,
            title: Text(destinations[i].label),
            selected: tab == i,
            selectedTileColor: tabColors[i].withValues(alpha: .15),
            onTap: () { setState(() => tab = i); Navigator.of(drawerContext).pop(); },
          ))),
        ])),
      ) : null,
      body: _AppBackdrop(
        settings: settings,
        child: SafeArea(child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: .90),
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
            ),
            child: Row(children: [
              SizedBox(width:compactNav?104:150,height:38,child:appBrandLogo(settings,width:150,height:38)),
              const SizedBox(width:6),
              compactNav
                ? IconButton(tooltip:'Despre',onPressed:_openAbout,icon:const Icon(Icons.info_outline))
                : TextButton.icon(onPressed:_openAbout,icon:const Icon(Icons.info_outline),label:const Text('Despre')),
              const Spacer(),
              Badge(
                isLabelVisible:myUnreadNotifications>0,
                label:Text(myUnreadNotifications>99?'99+':'$myUnreadNotifications'),
                child: IconButton(
                  tooltip:'Notificări',
                  onPressed:_openNotificationsSheet,
                  icon:const Icon(Icons.notifications_outlined),
                ),
              ),
              const SizedBox(width:6),
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: _openProfile,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: compactNav ? 16 : 17, backgroundImage: myPhoto == null ? null : MemoryImage(myPhoto), child: myPhoto == null ? const Icon(Icons.person, size: 18) : null),
                    if(!compactNav)...[const SizedBox(width:8), const Text('Profil', style: TextStyle(fontWeight: FontWeight.w700))],
                  ]),
                ),
              ),
              const SizedBox(width:6),
              if (kIsWeb) Builder(builder: (menuContext) => IconButton(
                tooltip: 'Deschide categoriile',
                icon: const Icon(Icons.menu_open_rounded, size: 29),
                onPressed: () => Scaffold.of(menuContext).openEndDrawer(),
              )),
              if(compactNav)...[
                IconButton(tooltip:'Membrii',onPressed:()=>_openMembersDirectory(),icon:sectionAssetWidget('Membri', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.people_outline)),
                Badge(isLabelVisible:_unreadMessageCount>0,label:Text(_unreadMessageCount>99?'99+':'$_unreadMessageCount'),child:IconButton(tooltip:'Chat live',onPressed:_openGroupChat,icon:sectionAssetWidget('Chat live', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.forum_outlined))),
              ]else...[
                FilledButton.tonalIcon(onPressed:()=>_openMembersDirectory(),icon:sectionAssetWidget('Membri', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.people_outline),label:const Text('Membrii')),
                const SizedBox(width:8),
                Badge(isLabelVisible:_unreadMessageCount>0,label:Text(_unreadMessageCount>99?'99+':'$_unreadMessageCount'),child:FilledButton.tonalIcon(onPressed:_openGroupChat,icon:sectionAssetWidget('Chat live', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.forum_outlined),label:const Text('Chat live'))),
              ],
            ]),
          ),
          Expanded(child: pages[tab]),
        ])),
      ),
      bottomNavigationBar: kIsWeb ? null : NavigationBar(
        height: compactNav ? 66 : 72,
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .97),
        indicatorColor: selectedColor.withValues(alpha: .18),
        labelBehavior: compactNav ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: destinations,
      ),
    );
  }

  void _openAdmin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminPanelPage(users: users, teams: teams, cars: cars, locations: locations, categories: categories, functionDefinitions: functionDefinitions, schedules: schedules, records: records, expenses: expenses, perDiems: perDiems, finances: finances, settlements: settlements, notifications: notifications, audit: audit, settings: settings, userName: userName, onChanged: refresh, log: log, saveLocation: _saveLocationDirect, deleteLocation: _deleteLocationDirect)));
  }
}

class DashboardPage extends StatefulWidget {
  final List<Team> teams; final List<AppUser> users; final List<FunctionDefinition> functionDefinitions; final List<Location> locations; final List<LocationCategory> categories; final List<WorkSchedule> schedules; final List<CentralizerRecord> records; final AppSettings settings; final AppUser currentUser; final bool canEditProgram; final String Function(String) userName; final VoidCallback onChanged; final Future<void> Function(CentralizerRecord) saveRecord; final Future<void> Function(WorkSchedule) saveSchedule; final void Function(String,String) log;
  const DashboardPage({super.key, required this.teams, required this.users, required this.functionDefinitions, required this.locations, required this.categories, required this.schedules, required this.records, required this.settings, required this.currentUser, required this.canEditProgram, required this.userName, required this.onChanged, required this.saveRecord, required this.saveSchedule, required this.log});
  @override State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  int teamIndex = 0;
  String? selectedGraphId;

  Team get team => widget.teams[teamIndex.clamp(0, widget.teams.length - 1)];

  List<CentralizerRecord> _recordsForItem(ScheduleItem item, DateTime workDate) {
    final out = widget.records.where((r) =>
      r.teamId == team.id &&
      r.locationId == item.locationId &&
      recordBelongsToWorkDate(r, workDate)
    ).toList();
    out.sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    return out;
  }

  CentralizerRecord? _latestRecord(ScheduleItem item, DateTime workDate) {
    final rs = _recordsForItem(item, workDate);
    return rs.isEmpty ? null : rs.last;
  }

  List<CentralizerRecord> _completedHistory(String locationId) => widget.records
      .where((r) => r.locationId == locationId && r.completed && r.duration != null)
      .toList();

  Duration? _averageDuration(String locationId) => learnedAverageDuration(widget.records, locationId, widget.settings);

  WorkSchedule _copySchedule(WorkSchedule s) => WorkSchedule(
    id:s.id, teamId:s.teamId, graphId:s.graphId, graphName:s.graphName, date:s.date,
    items:s.items.map((i)=>ScheduleItem(locationId:i.locationId,locationNameSnapshot:i.locationNameSnapshot,addressSnapshot:i.addressSnapshot,typeSnapshot:i.typeSnapshot,categoryIdSnapshot:i.categoryIdSnapshot,order:i.order,transferred:i.transferred,facadePlanned:i.facadePlanned)).toList(),
    active:s.active, closed:s.closed, started:s.started, paused:s.paused, postponed:s.postponed, autoProposed:s.autoProposed,
    planAlertAt:s.planAlertAt, planAlertReason:s.planAlertReason, lastRecalculatedAt:s.lastRecalculatedAt, recalculationCount:s.recalculationCount,
    learningExplanation:s.learningExplanation, learningConfidence:s.learningConfidence, learningSamples:s.learningSamples,
    departureName:s.departureName, departureLatitude:s.departureLatitude, departureLongitude:s.departureLongitude, returnName:s.returnName, returnLatitude:s.returnLatitude, returnLongitude:s.returnLongitude,
  );

  Future<Map<String,dynamic>?> _dashboardGeocodeTripPoint(String query) async {
    final clean=query.trim();
    if(clean.isEmpty)return null;

    Map<String,dynamic>? parsePoint(Object? raw){
      if(raw is! Map)return null;
      final lat=double.tryParse((raw['lat']??'').toString());
      final lon=double.tryParse((raw['lon']??'').toString());
      if(lat==null||lon==null)return null;
      return {'lat':lat,'lon':lon};
    }

    Future<Map<String,dynamic>?> viaServer() async {
      try{
        final token=await FirebaseAuth.instance.currentUser?.getIdToken();
        if(token==null||token.isEmpty)return null;
        final response=await http.post(
          Uri.parse(_geocodeRomaniaPlaceUrl),
          headers:{'Content-Type':'application/json','Authorization':'Bearer $token'},
          body:jsonEncode({'query':clean}),
        ).timeout(const Duration(seconds:12));
        if(response.statusCode!=200||response.body.isEmpty)return null;
        return parsePoint(jsonDecode(response.body));
      }catch(e){debugPrint('[geocode] Dashboard server fallback: $e');return null;}
    }

    Future<Map<String,dynamic>?> viaNominatim(String value) async {
      try{
        final uri=Uri.https('nominatim.openstreetmap.org','/search',{
          'format':'jsonv2','q':value,'limit':'1','countrycodes':'ro','accept-language':'ro','addressdetails':'1'
        });
        final headers=<String,String>{'Accept':'application/json','Accept-Language':'ro'};
        if(!kIsWeb)headers['User-Agent']='AndiCarpeta/2.0.8 (internal operations app)';
        final response=await http.get(uri,headers:headers).timeout(const Duration(seconds:10));
        if(response.statusCode!=200||response.body.isEmpty)return null;
        final decoded=jsonDecode(response.body);
        if(decoded is! List||decoded.isEmpty)return null;
        return parsePoint(decoded.first);
      }catch(e){debugPrint('[geocode] Dashboard Nominatim $value: $e');return null;}
    }

    if(kIsWeb){
      final server=await viaServer();
      if(server!=null)return server;
    }
    final candidates=<String>[clean];
    if(!clean.toLowerCase().contains('românia')&&!clean.toLowerCase().contains('romania'))candidates.add('$clean, România');
    for(final candidate in candidates){
      final direct=await viaNominatim(candidate);
      if(direct!=null)return direct;
    }
    if(!kIsWeb)return viaServer();
    return null;
  }

  Future<void> _toggleProgram(WorkSchedule schedule) async {
    if(!schedule.started){
      final dep=TextEditingController(text:schedule.departureName);
      final ret=TextEditingController(text:schedule.returnName);
      final choice=await showDialog<Map<String,String>>(context:context,builder:(c)=>AlertDialog(
        title:const Text('START program'),
        content:SizedBox(width:540,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Punctele sunt folosite numai pentru deplasare, kilometri și consum. Nu apar în Centralizator.'),
          const SizedBox(height:12),
          TextField(controller:dep,decoration:const InputDecoration(labelText:'Plecare',hintText:'Ex: Brăila')),
          const SizedBox(height:10),
          TextField(controller:ret,decoration:const InputDecoration(labelText:'Întoarcere / destinație finală',hintText:'Ex: Brăila')),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,{'departure':dep.text.trim(),'return':ret.text.trim()}),child:const Text('START'))],
      ));
      dep.dispose();ret.dispose();
      if(choice==null)return;
      final departureText=(choice['departure']??'').trim();final returnText=(choice['return']??'').trim();
      if(departureText.isEmpty||returnText.isEmpty){if(mounted)showErrorMessage(context,'Completează plecarea și punctul final.');return;}
      final startPoint=await _dashboardGeocodeTripPoint(departureText);
      final endPoint=departureText.toLowerCase()==returnText.toLowerCase()?startPoint:await _dashboardGeocodeTripPoint(returnText);
      if(startPoint==null||endPoint==null){if(mounted)showErrorMessage(context,'Nu am putut identifica una dintre localități. Scrie localitatea mai explicit.');return;}
      final sameGraph=widget.schedules.where((s)=>s.graphId==schedule.graphId&&s.teamId==schedule.teamId).map(_copySchedule).toList();
      for(final x in sameGraph){
        x.started=true;x.paused=false;x.closed=false;
        x.departureName=departureText;x.departureLatitude=startPoint['lat'] as double;x.departureLongitude=startPoint['lon'] as double;
        x.returnName=returnText;x.returnLatitude=endPoint['lat'] as double;x.returnLongitude=endPoint['lon'] as double;
        await widget.saveSchedule(x);
      }
      widget.log('START program din Acasă','${team.name} · ${schedule.graphName} · $departureText → $returnText');
      if(mounted)showSuccessMessage(context,'Programul echipei a fost pornit cu traseul complet.');
      return;
    }
    final updated=_copySchedule(schedule);
    updated.started=false;
    updated.paused=false;
    await widget.saveSchedule(updated);
    widget.log('STOP program din Acasă','${team.name} · ${updated.graphName} · ${formatDate(updated.date)}');
    if(mounted)showSuccessMessage(context,'Programul echipei a fost oprit.');
  }

  // Orașul este preluat din denumirea locației sau din ultimul segment al
  // adresei, nu din numele străzii (primul segment al adresei).
  String _locationCityLabel(Location l) {
    final name = l.name.trim().replaceFirst(
      RegExp(r'^(million|magic)\s+', caseSensitive: false), '',
    ).trim();
    final parts = l.address.split(',').map((s) => s.trim())
        .where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      final candidate = parts.last.replaceFirst(
        RegExp(r'^(jud\.?|județul|municipiul|orașul)\s+', caseSensitive: false), '',
      ).trim();
      if (candidate.isNotEmpty &&
          !RegExp(r'^(românia|romania|rom|\d{5,6})$', caseSensitive: false).hasMatch(candidate)) {
        return candidate;
      }
    }
    return name.split(RegExp(r'[-–]')).first.trim();
  }

  String _memberLocationLabel(String userId, Map<String, Map<String,dynamic>> live, String teamId) {
    final d = live[userId];
    if (d == null) return 'Locație live indisponibilă';
    final lat = d['latitude'];
    final lon = d['longitude'];
    if (lat is! num || lon is! num || !lat.toDouble().isFinite ||
        !lon.toDouble().isFinite || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return 'Locație live indisponibilă';
    }
    final updated = d['updatedAt'];
    final at = updated is Timestamp ? updated.toDate() : null;
    if (at == null || DateTime.now().difference(at) > const Duration(minutes: 30) ||
        at.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return 'Locație live neactualizată';
    }
    final age = ' · actualizat ${timeText(at)}';
    final locality = (d['localityLabel'] ?? '').toString().trim();

    // Apropierea GPS de o sală nu dovedește că membrul lucrează acolo.
    // Afișăm sala numai când echipa are o intervenție efectiv în lucru.
    final active = widget.records.where((r) =>
        r.teamId == teamId && r.status == WorkAttemptStatus.running &&
        r.finishedAt == null && recordBelongsToWorkDate(r, DateTime.now()));
    Location? currentSite;
    var closest = double.infinity;
    for (final record in active) {
      for (final site in widget.locations) {
        if (site.id != record.locationId || site.latitude == null || site.longitude == null) continue;
        final meters = Geolocator.distanceBetween(lat.toDouble(), lon.toDouble(),
            site.latitude!, site.longitude!);
        if (meters <= 150 && meters < closest) {
          currentSite = site;
          closest = meters;
        }
      }
    }
    if (currentSite != null) {
      final city = _locationCityLabel(currentSite);
      return city.isEmpty ? '${currentSite.name}$age' : '${currentSite.name} · $city$age';
    }
    if (locality.isNotEmpty) return '$locality$age';
    return 'Oraș/județ indisponibil$age';
  }

  String _confidenceLabel(List<int> counts) {
    if (counts.isEmpty) return '—';
    final minCount = counts.reduce((a, b) => a < b ? a : b);
    if (minCount >= 8) return 'ridicată';
    if (minCount >= 5) return 'medie';
    return 'inițială';
  }

  String _recordStateText(CentralizerRecord? r) {
    if (r == null) return 'Neîncepută';
    switch (r.status) {
      case WorkAttemptStatus.completed:
        return 'Finalizată · ${durationText(r.duration)} · ${timeText(r.startedAt)}–${timeText(r.finishedAt)}';
      case WorkAttemptStatus.running:
        final wait = r.waitingDuration;
        return 'Pe sală din ${timeText(r.startedAt)}${wait == null ? '' : ' · așteptare ${durationText(wait)}'}';
      case WorkAttemptStatus.waitingAccess:
        return 'Așteptare acces din ${timeText(r.waitingStartedAt)}';
      case WorkAttemptStatus.refused:
        return 'Refuzată${(r.refusalReason ?? '').trim().isEmpty ? '' : ' · ${r.refusalReason}'}';
      case WorkAttemptStatus.notCompleted:
        return 'Nerealizată${(r.refusalReason ?? '').trim().isEmpty ? '' : ' · ${r.refusalReason}'}';
    }
  }

  Color _recordStateColor(CentralizerRecord? r) {
    if (r == null) return Colors.blueGrey;
    return switch (r.status) {
      WorkAttemptStatus.completed => Colors.green,
      WorkAttemptStatus.running => Colors.blue,
      WorkAttemptStatus.waitingAccess => Colors.orange,
      WorkAttemptStatus.refused => Colors.red,
      WorkAttemptStatus.notCompleted => Colors.deepOrange,
    };
  }

  IconData _recordStateIcon(CentralizerRecord? r) {
    if (r == null) return Icons.radio_button_unchecked;
    return switch (r.status) {
      WorkAttemptStatus.completed => Icons.check,
      WorkAttemptStatus.running => Icons.cleaning_services,
      WorkAttemptStatus.waitingAccess => Icons.hourglass_top,
      WorkAttemptStatus.refused => Icons.block,
      WorkAttemptStatus.notCompleted => Icons.warning_amber_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final compact = MediaQuery.sizeOf(context).width < 650;
    if (widget.teams.isEmpty) {
      return _Page(title: 'Acasă', subtitle: formatDate(now), child: const _Empty(icon: Icons.groups_outlined, text: 'Nu există încă nicio echipă. Adminul poate crea prima echipă din Admin Panel → Echipe.'));
    }
    if (teamIndex >= widget.teams.length) teamIndex = 0;

    final candidates = widget.schedules.where((s) => s.teamId == team.id && sameDay(s.date, workDate) && !s.closed).toList();
    candidates.sort((a, b) {
      final startedCompare = (b.started ? 1 : 0).compareTo(a.started ? 1 : 0);
      if (startedCompare != 0) return startedCompare;
      return a.graphName.toLowerCase().compareTo(b.graphName.toLowerCase());
    });
    final graphIds = <String>[];
    for (final s in candidates) {
      if (!graphIds.contains(s.graphId)) graphIds.add(s.graphId);
    }
    if (selectedGraphId == null || !graphIds.contains(selectedGraphId)) {
      selectedGraphId = graphIds.isEmpty ? null : graphIds.first;
    }
    final scheduleMatches = candidates.where((s) => s.graphId == selectedGraphId).toList();
    final schedule = scheduleMatches.isEmpty ? null : scheduleMatches.first;
    final items = schedule?.items ?? <ScheduleItem>[];
    final todaysRecords = widget.records.where((r) => r.teamId == team.id && recordBelongsToWorkDate(r, workDate)).toList();
    final done = items.where((i) => _latestRecord(i, workDate)?.completed == true).length;
    final failed = items.where((i) {
      final r = _latestRecord(i, workDate);
      return r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted;
    }).length;
    final running = todaysRecords.where((r) => r.status == WorkAttemptStatus.running && r.startedAt != null && r.finishedAt == null).toList()
      ..sort((a, b) => recordEventTime(b).compareTo(recordEventTime(a)));
    final waiting = todaysRecords.where((r) => r.status == WorkAttemptStatus.waitingAccess && r.waitingStartedAt != null && r.waitingEndedAt == null).toList()
      ..sort((a, b) => recordEventTime(b).compareTo(recordEventTime(a)));
    final inWindow = isInsideWorkWindow(now, workDate);

    String stateText;
    IconData stateIcon;
    Color stateColor;
    if (running.isNotEmpty) {
      stateText = 'PE SALĂ · ${running.first.locationNameSnapshot}'; stateIcon = Icons.location_on; stateColor = Colors.green;
    } else if (waiting.isNotEmpty) {
      stateText = 'AȘTEPTARE ACCES · ${waiting.first.locationNameSnapshot}'; stateIcon = Icons.hourglass_top; stateColor = Colors.orange;
    } else if (schedule?.paused == true) {
      stateText = 'ÎN PAUZĂ'; stateIcon = Icons.pause_circle; stateColor = Colors.orange;
    } else if (schedule?.postponed == true) {
      stateText = 'PROGRAM AMÂNAT'; stateIcon = Icons.event_busy; stateColor = Colors.deepOrange;
    } else if (schedule != null && schedule.started && inWindow) {
      stateText = 'ÎN TIMPUL PROGRAMULUI'; stateIcon = Icons.nightlight_round; stateColor = Colors.blue;
    } else {
      stateText = 'ÎN AFARA PROGRAMULUI'; stateIcon = Icons.schedule; stateColor = Colors.blueGrey;
    }

    final pendingForEstimate = items.where((item) {
      final r = _latestRecord(item, workDate);
      if (r?.completed == true) return false;
      if (r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted) return false;
      return true;
    }).toList();
    var estimateAvailable = pendingForEstimate.isNotEmpty;
    var estimatedSeconds = 0;
    final confidenceCounts = <int>[];
    var insufficientHistory = 0;
    for (final item in pendingForEstimate) {
      final history = _completedHistory(item.locationId);
      if (history.length < 3) {
        estimateAvailable = false;
        insufficientHistory++;
        continue;
      }
      confidenceCounts.add(history.length);
      final average = _averageDuration(item.locationId)!;
      final r = _latestRecord(item, workDate);
      if (r?.status == WorkAttemptStatus.running && r?.startedAt != null) {
        final elapsed = now.difference(r!.startedAt!).inSeconds;
        estimatedSeconds += (average.inSeconds - elapsed).clamp(0, average.inSeconds).toInt();
      } else {
        estimatedSeconds += average.inSeconds;
      }
    }
    final estimatedEnd = estimateAvailable ? now.add(Duration(seconds: estimatedSeconds)) : null;

    return _Page(
      title: 'Acasă',
      subtitle: '${formatDate(now)} · zi de lucru ${formatDate(workDate)}',
      actions: [IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment:Alignment.centerRight,child:_InstallAppButtons(settings:widget.settings,compact:true)),
        const SizedBox(height:10),
        Text('Echipe acum', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: widget.teams.map((t) {
          final ts = widget.schedules.where((s)=>s.teamId==t.id && sameDay(s.date,workDate) && !s.closed).toList();
          final active = ts.any((s)=>s.started && !s.paused && !s.postponed);
          final paused = ts.any((s)=>s.paused);
          final color = active ? Colors.green : paused ? Colors.orange : Colors.blueGrey;
          return SizedBox(width: compact ? double.infinity : 260, child: Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withValues(alpha:.15), child: Icon(active?Icons.play_arrow:paused?Icons.pause:Icons.schedule,color:color)),
            title: Text(t.name, style: const TextStyle(fontWeight:FontWeight.w800)),
            subtitle: Text(active?'În program':paused?'În pauză':'În afara programului'),
            onTap:(){final idx=widget.teams.indexWhere((x)=>x.id==t.id);if(idx>=0)setState((){teamIndex=idx;selectedGraphId=null;});},
          )));
        }).toList()),
        const SizedBox(height: 14),
        _TeamSelector(teams: widget.teams, selected: teamIndex, onChanged: (v) => setState(() { teamIndex = v; selectedGraphId = null; })),
        if (graphIds.length > 1) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedGraphId,
            decoration: const InputDecoration(labelText: 'Grafic activ pentru ziua de lucru'),
            items: graphIds.map((id) {
              final s = candidates.firstWhere((x) => x.graphId == id);
              return DropdownMenuItem(value: id, child: Text('${s.graphName}${s.started ? ' · pornit' : ' · pregătit'}'));
            }).toList(),
            onChanged: (v) => setState(() => selectedGraphId = v),
          ),
        ],
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          CircleAvatar(backgroundColor: stateColor.withValues(alpha: .16), child: Icon(stateIcon, color: stateColor)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Stare echipă', style: TextStyle(fontSize: 12)),
            Text(stateText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Fereastră standard: ${timeText(workWindowStart(workDate))} → ${timeText(workWindowEnd(workDate))}'),
          ])),
          if(schedule!=null && widget.canEditProgram) ...[
            const SizedBox(width:10),
            compact
              ? IconButton.filled(tooltip:schedule.started?'STOP program':'START program',onPressed:()=>_toggleProgram(schedule),icon:Icon(schedule.started?Icons.stop:Icons.play_arrow))
              : FilledButton.icon(onPressed:()=>_toggleProgram(schedule),icon:Icon(schedule.started?Icons.stop:Icons.play_arrow),label:Text(schedule.started?'STOP program':'START program')),
          ],
        ]))),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: FirebaseFirestore.instance.collection('liveLocations').snapshots(),
          builder:(context,snap){
            final live=<String,Map<String,dynamic>>{};
            for(final d in snap.data?.docs??<QueryDocumentSnapshot<Map<String,dynamic>>>[]) live[d.id]=d.data();
            final visibleUserIds = widget.users.map((u) => u.id).toSet();
            final visibleMemberIds = team.members.where(visibleUserIds.contains).toList();
            final members=visibleMemberIds.map((id){
              final u=(() { for(final x in widget.users){if(x.id==id)return x;} return null; })();
              final name=u?.name??widget.userName(id);
              final photo=decodeProfilePhoto(u?.photoBase64 ?? '');
              final functions=u==null?'' : u.functionIds.map((fid)=>widget.functionDefinitions.where((f)=>f.id==fid).map((f)=>f.name).cast<String?>().firstWhere((v)=>v!=null,orElse:()=>fid)!).join(', ');
              return ListTile(
                dense:true,
                leading:GestureDetector(
                  onTap:u==null||photo==null?null:()=>showProfilePhotoViewer(context,u.photoBase64,name),
                  child:CircleAvatar(radius:22,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person_outline):null),
                ),
                title:Text(name,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(_memberLocationLabel(id,live,team.id)),if(functions.isNotEmpty)Text(functions),if(u!=null&&u.functionIds.isNotEmpty)...[const SizedBox(height:6),memberBadgeStripWidget(widget.functionDefinitions,u.functionIds,size:30)]]),
              );
            }).toList();
            return Card(child:ExpansionTile(
              initiallyExpanded:true,
              leading:const Icon(Icons.groups_2_outlined),
              title:Text('Membrii ${team.name}',style:const TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('${visibleMemberIds.length} membri · poziție live dacă este disponibilă'),
              children:members.isEmpty?[const ListTile(title:Text('Echipa nu are membri alocați.'))]:members,
            ));
          },
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _StatCard(title: 'Grafic azi', value: schedule == null ? 'Nu există' : '${items.length} locații', asset: 'assets/ui/tab_grafic.png'),
          _StatCard(title: 'Progres', value: '$done finalizate · ${items.length - done} rămase', asset: 'assets/ui/tab_centralizator.png'),
          _StatCard(title: 'Acum', value: running.isNotEmpty ? running.first.locationNameSnapshot : waiting.isNotEmpty ? 'Așteptare · ${waiting.first.locationNameSnapshot}' : (inWindow ? 'Între locații' : 'Liber'), asset: 'assets/ui/tab_harta.png'),
          if (failed > 0) _StatCard(title: 'Excepții', value: '$failed refuzate / nerealizate', icon: Icons.warning_amber_rounded),
        ]),
        const SizedBox(height: 14),
        if (estimatedEnd != null)
          _InfoCard(icon: Icons.schedule_send, title: 'Final estimat ${timeText(estimatedEnd)}', text: 'Încredere ${_confidenceLabel(confidenceCounts)} · calculat numai din locații cu minimum 3 execuții finalizate.'),
        if (estimatedEnd == null && pendingForEstimate.isNotEmpty && insufficientHistory > 0)
          _InfoCard(icon: Icons.auto_graph, title: 'Estimare încă indisponibilă', text: '$insufficientHistory locații rămase au sub 3 execuții istorice. Aplicația nu afișează o oră estimată până când datele nu sunt suficiente.'),
        if (estimatedEnd != null && estimatedEnd.isAfter(workWindowEnd(workDate)))
          Card(color:Theme.of(context).colorScheme.errorContainer,child:ListTile(leading:Icon(Icons.warning_amber_rounded,color:Theme.of(context).colorScheme.error),title:const Text('Risc de depășire a planului',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Finalul estimat este ${timeText(estimatedEnd)}, după limita ${timeText(workWindowEnd(workDate))}. În Grafic de lucru poți recalcula traseul rămas sau transfera locațiile neîncepute.'))),
        if (schedule?.planAlertAt != null && schedule!.planAlertReason.trim().isNotEmpty)
          _InfoCard(icon:Icons.notifications_active,title:'Ultima alertă de plan · ${timeText(schedule.planAlertAt)}',text:schedule.planAlertReason),
        if (schedule != null) ...[
          const SizedBox(height: 12),
          _InfoCard(icon: Icons.route, title: schedule.graphName, text: 'Grafic activ · ${formatDate(schedule.date)} · ${schedule.started ? 'pornit' : 'nepornit'}${schedule.paused ? ' · pauză' : ''}${schedule.postponed ? ' · amânat' : ''}'),
        ],
        if (schedule != null && items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Locațiile zilei curente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...items.map((item) {
            final r = _latestRecord(item, workDate);
            final color = _recordStateColor(r);
            final isRunning = r?.status == WorkAttemptStatus.running && r?.finishedAt == null;
            final canEnter = !isRunning && r?.completed != true && r?.status != WorkAttemptStatus.refused && r?.status != WorkAttemptStatus.notCompleted;
            return Card(child: ListTile(
              leading: Stack(alignment: Alignment.bottomRight, children: [
                categoryBrandWidget(item.categoryIdSnapshot, size: 36, fallbackColor: categoryColor(widget.categories, item.categoryIdSnapshot, fallbackType: item.typeSnapshot)),
                Container(width: 19, height: 19, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), child: Icon(_recordStateIcon(r), color: Colors.white, size: 11)),
              ]),
              title: Text(item.locationNameSnapshot, maxLines: 3, overflow: TextOverflow.ellipsis, softWrap: true),
              subtitle: Text(_recordStateText(r), maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: (r?.refusalReason ?? '').trim().isNotEmpty,
              trailing: r?.completed == true
                ? const Icon(Icons.check_circle, color: Colors.green)
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (canEnter)
                      Tooltip(
                        message: 'Intră / începe lucrul',
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                          onPressed: !widget.canEditProgram || schedule.paused || schedule.postponed || !schedule.started ? null : () => _startLocation(item),
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        ),
                      ),
                    if (isRunning)
                      Tooltip(
                        message: 'Stop / ieși din locație',
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                          onPressed: widget.canEditProgram ? () => _finishLocation(r!) : null,
                          icon: const Icon(Icons.stop_rounded, size: 28),
                        ),
                      ),
                    const SizedBox(width: 4),
                    if (widget.canEditProgram) PopupMenuButton<String>(
                      tooltip: 'Alte acțiuni',
                      onSelected: (value) {
                        if (value == 'wait') unawaited(_markWaiting(item));
                        if (value == 'refused') unawaited(_markOutcome(item, WorkAttemptStatus.refused));
                        if (value == 'notCompleted') unawaited(_markOutcome(item, WorkAttemptStatus.notCompleted));
                      },
                      itemBuilder: (_) => [
                        if (!isRunning && r?.completed != true) const PopupMenuItem(value: 'wait', child: ListTile(leading: Icon(Icons.hourglass_top), title: Text('Așteptare acces'))),
                        if (r?.completed != true) const PopupMenuItem(value: 'refused', child: ListTile(leading: Icon(Icons.block), title: Text('Refuzată'))),
                        if (r?.completed != true) const PopupMenuItem(value: 'notCompleted', child: ListTile(leading: Icon(Icons.warning_amber_rounded), title: Text('Nerealizată'))),
                      ],
                    ),
                  ]),
            ));
          }),
        ] else const _Empty(icon: Icons.route, text: 'Nu există locații în Graficul de lucru pentru această zi.'),
        const SizedBox(height: 12),
        if (schedule != null && items.isNotEmpty && items.every((i) => widget.records.where((r) => r.locationId == i.locationId && r.completed).length >= 3))
          const _InfoCard(icon: Icons.auto_graph, title: 'Learning activ', text: 'Estimările folosesc istoricul real. INTRĂ/IEȘI, așteptările, refuzurile și nerealizările sunt păstrate separat pentru Learning.'),
      ]),
    );
  }

  Future<void> _startLocation(ScheduleItem item) async {
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final running = widget.records.where((r) => r.teamId == team.id && r.status == WorkAttemptStatus.running && r.finishedAt == null && recordBelongsToWorkDate(r, workDate)).toList();
    if (running.isNotEmpty && running.first.locationId != item.locationId) {
      if (mounted) showErrorMessage(context, 'Echipa este deja pe sală la ${running.first.locationNameSnapshot}. Apasă IEȘI înainte de a intra în altă locație.');
      return;
    }
    if (running.isNotEmpty && running.first.locationId == item.locationId) return;

    final existing = widget.records.where((r) => r.teamId == team.id && r.locationId == item.locationId && r.finishedAt == null && recordBelongsToWorkDate(r, workDate)).toList()
      ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    final base = existing.isEmpty ? null : existing.last;
    final r = CentralizerRecord(
      id: base?.id ?? idNow(),
      teamId: team.id,
      locationId: item.locationId,
      type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot,
      addressSnapshot: item.addressSnapshot,
      waitingStartedAt: base?.waitingStartedAt,
      waitingEndedAt: base?.waitingStartedAt != null && base?.waitingEndedAt == null ? now : base?.waitingEndedAt,
      startedAt: now,
      finishedAt: null,
      status: WorkAttemptStatus.running,
      refusalReason: null,
      keptForLearning: base?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: base?.facadeDone ?? false,
    );
    try {
      await widget.saveRecord(r);
      widget.log('INTRĂ pe sală', '${team.name} · ${item.locationNameSnapshot}');
      if (mounted) showSuccessMessage(context, 'Intrare salvată: ${item.locationNameSnapshot} · ${timeText(r.startedAt)}');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Intrarea nu a putut fi salvată: $e');
    }
  }

  Future<void> _finishLocation(CentralizerRecord source) async {
    final facadeDone = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Fațada a fost realizată?'),
        content: Text('${source.locationNameSnapshot}\nRăspunsul este obligatoriu înainte de finalizarea intervenției.'),
        actions: [
          OutlinedButton.icon(onPressed: () => Navigator.pop(c, false), icon: const Icon(Icons.close), label: const Text('NU')),
          FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.check), label: const Text('DA')),
        ],
      ),
    );
    if (facadeDone == null) return;
    final r = CentralizerRecord(
      id: source.id,
      teamId: source.teamId,
      locationId: source.locationId,
      type: source.type,
      locationNameSnapshot: source.locationNameSnapshot,
      addressSnapshot: source.addressSnapshot,
      waitingStartedAt: source.waitingStartedAt,
      waitingEndedAt: source.waitingEndedAt,
      startedAt: source.startedAt,
      finishedAt: DateTime.now(),
      status: WorkAttemptStatus.completed,
      refusalReason: source.refusalReason,
      keptForLearning: source.keptForLearning,
      facadePlanned: source.facadePlanned,
      facadeDone: facadeDone,
    );
    try {
      await widget.saveRecord(r);
      widget.log('IEȘI de pe sală', '${team.name} · ${r.locationNameSnapshot} · ${durationText(r.duration)}');
      if (mounted) {
        if(widget.settings.allowUndo){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:Text('Ieșire salvată: ${r.locationNameSnapshot} · ${timeText(r.finishedAt)} · ${durationText(r.duration)}'),
            action:SnackBarAction(label:'ANULEAZĂ',onPressed:()async{
              try{await widget.saveRecord(source);widget.log('Undo IEȘI','${team.name} · ${source.locationNameSnapshot}');if(mounted)showSuccessMessage(context,'FINAL a fost anulat; locația este din nou în lucru.');}
              catch(e){if(mounted)showErrorMessage(context,'Undo nu a reușit: $e');}
            }),
          ));
        }else{
          showSuccessMessage(context, 'Ieșire salvată: ${r.locationNameSnapshot} · ${timeText(r.finishedAt)} · ${durationText(r.duration)}');
        }
      }
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Ieșirea nu a putut fi salvată: $e');
    }
  }

  Future<void> _markWaiting(ScheduleItem item) async {
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final running = widget.records.where((r) => r.teamId == team.id && r.status == WorkAttemptStatus.running && r.finishedAt == null && recordBelongsToWorkDate(r, workDate)).toList();
    if (running.isNotEmpty) {
      if (mounted) showErrorMessage(context, 'Există deja o locație în lucru. Închide întâi intervenția curentă.');
      return;
    }
    final existing = widget.records.where((r) => r.teamId == team.id && r.locationId == item.locationId && r.finishedAt == null && recordBelongsToWorkDate(r, workDate)).toList()
      ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    final base = existing.isEmpty ? null : existing.last;
    final r = CentralizerRecord(
      id: base?.id ?? idNow(),
      teamId: team.id,
      locationId: item.locationId,
      type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot,
      addressSnapshot: item.addressSnapshot,
      waitingStartedAt: base?.waitingStartedAt ?? now,
      waitingEndedAt: null,
      startedAt: null,
      finishedAt: null,
      status: WorkAttemptStatus.waitingAccess,
      refusalReason: null,
      keptForLearning: base?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: base?.facadeDone ?? false,
    );
    try {
      await widget.saveRecord(r);
      widget.log('Așteptare acces', '${team.name} · ${item.locationNameSnapshot}');
      if (mounted) showSuccessMessage(context, 'Așteptarea a fost pornită pentru ${item.locationNameSnapshot}.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Așteptarea nu a putut fi salvată: $e');
    }
  }

  Future<String?> _reasonDialog(WorkAttemptStatus status, String locationName) async {
    final controller = TextEditingController();
    final title = status == WorkAttemptStatus.refused ? 'Locație refuzată' : 'Locație nerealizată';
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(locationName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: controller, autofocus: true, maxLines: 3, decoration: const InputDecoration(labelText: 'Motiv *', hintText: 'Ex.: acces refuzat, închis, problemă tehnică...')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
          FilledButton(onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(c, value);
          }, child: const Text('Salvează')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _markOutcome(ScheduleItem item, WorkAttemptStatus status) async {
    final reason = await _reasonDialog(status, item.locationNameSnapshot);
    if (reason == null) return;
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final existing = widget.records.where((r) => r.teamId == team.id && r.locationId == item.locationId && r.finishedAt == null && recordBelongsToWorkDate(r, workDate)).toList()
      ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    final base = existing.isEmpty ? null : existing.last;
    final r = CentralizerRecord(
      id: base?.id ?? idNow(),
      teamId: team.id,
      locationId: item.locationId,
      type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot,
      addressSnapshot: item.addressSnapshot,
      waitingStartedAt: base?.waitingStartedAt,
      waitingEndedAt: base?.waitingStartedAt != null && base?.waitingEndedAt == null ? now : base?.waitingEndedAt,
      startedAt: base?.startedAt,
      finishedAt: now,
      status: status,
      refusalReason: reason,
      keptForLearning: base?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: base?.facadeDone ?? false,
    );
    try {
      await widget.saveRecord(r);
      final label = status == WorkAttemptStatus.refused ? 'Refuzată' : 'Nerealizată';
      widget.log(label, '${team.name} · ${item.locationNameSnapshot} · $reason');
      if (mounted) showSuccessMessage(context, '$label: ${item.locationNameSnapshot}. Motivul a fost păstrat pentru Learning.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Statusul nu a putut fi salvat: $e');
    }
  }
}
class ProgramPage extends StatefulWidget {
  final AppUser currentUser; final List<Team> teams; final List<Car> cars; final List<Location> locations; final List<LocationCategory> categories; final List<WorkSchedule> schedules; final List<CentralizerRecord> records; final AppSettings settings; final bool Function(String) canEditTeam; final bool canEditProgram; final String Function(String) userName; final VoidCallback onChanged; final void Function(String,String,String) notifyTeam; final void Function(String,String) log; final Future<void> Function(WorkSchedule) saveSchedule;
  const ProgramPage({super.key, required this.currentUser, required this.teams, required this.cars, required this.locations, required this.categories, required this.schedules, required this.records, required this.settings, required this.canEditTeam, required this.canEditProgram, required this.userName, required this.onChanged, required this.notifyTeam, required this.log, required this.saveSchedule});
  @override State<ProgramPage> createState() => _ProgramPageState();
}
class _ProgramPageState extends State<ProgramPage> {
  String? _roadRouteKey;
  Future<double?>? _roadRouteFuture;

  Future<double?> _roadDistanceForGraph(List<WorkSchedule> days) {
    final route = graphRoutePoints(days, widget.locations);
    final key = route.complete
        ? route.points.map((p) => '${p.latitude},${p.longitude}').join('|')
        : 'incomplete';
    if (_roadRouteKey != key || _roadRouteFuture == null) {
      _roadRouteKey = key;
      _roadRouteFuture = estimateGraphRoadDistanceKm(days, widget.locations);
    }
    return _roadRouteFuture!;
  }

  int teamIndex = 0;
  String? selectedGraphId;
  final GlobalKey _graphCaptureKey = GlobalKey();
  final Set<String> _planAlertInFlight = <String>{};
  Team get team => widget.teams[teamIndex];
  List<WorkSchedule> get teamSchedules => widget.schedules.where((s) => s.teamId == team.id).toList()..sort((a,b)=>a.date.compareTo(b.date));
  List<WorkSchedule> get graphSchedules {
    final id = selectedGraphId;
    if (id == null) return <WorkSchedule>[];
    return teamSchedules.where((s) => s.graphId == id).toList()..sort((a,b)=>a.date.compareTo(b.date));
  }
  List<String> get graphIds {
    final out = <String>[];
    for (final s in teamSchedules) { if (!out.contains(s.graphId)) out.add(s.graphId); }
    out.sort((a,b) {
      DateTime first(String id) => teamSchedules.where((s)=>s.graphId==id).map((s)=>s.date).reduce((x,y)=>y.isBefore(x)?y:x);
      return first(b).compareTo(first(a));
    });
    return out;
  }
  WorkSchedule? get graphHead => graphSchedules.isEmpty ? null : graphSchedules.first;
  Car? get assignedCar {
    final id = team.carId;
    if (id == null) return null;
    for (final c in widget.cars) { if (c.id == id) return c; }
    return null;
  }

  CentralizerRecord? _latestRecordForItem(ScheduleItem item, DateTime workDate) {
    final rs = widget.records.where((r) =>
      r.teamId == team.id && r.locationId == item.locationId && recordBelongsToWorkDate(r, workDate)
    ).toList()..sort((a,b)=>recordEventTime(a).compareTo(recordEventTime(b)));
    return rs.isEmpty ? null : rs.last;
  }

  Duration? _averageDurationForLocation(String locationId) => learnedAverageDuration(widget.records, locationId, widget.settings);

  List<ScheduleItem> _pendingItemsForDay(WorkSchedule day, DateTime workDate, {bool includeActive = true}) {
    return day.items.where((item){
      final r = _latestRecordForItem(item, workDate);
      if (r?.status == WorkAttemptStatus.completed || r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted) return false;
      if (!includeActive && (r?.status == WorkAttemptStatus.running || r?.status == WorkAttemptStatus.waitingAccess)) return false;
      return true;
    }).toList();
  }

  DateTime? _estimatedEndForDay(WorkSchedule day, DateTime now) {
    final workDate = operationalWorkDate(now);
    final pending = _pendingItemsForDay(day, workDate);
    if (pending.isEmpty) return now;
    var seconds = 0;
    for (final item in pending) {
      final avg = _averageDurationForLocation(item.locationId);
      if (avg == null) return null;
      final r = _latestRecordForItem(item, workDate);
      if (r?.status == WorkAttemptStatus.running && r?.startedAt != null) {
        final elapsed = now.difference(r!.startedAt!).inSeconds;
        seconds += (avg.inSeconds - elapsed).clamp(0, avg.inSeconds).toInt();
      } else {
        seconds += avg.inSeconds;
      }
    }
    return now.add(Duration(seconds: seconds));
  }

  String? _planRiskReason(WorkSchedule day, DateTime now) {
    if (!day.started || day.closed || day.paused || day.postponed) return null;
    final workDate = operationalWorkDate(now);
    final pending = _pendingItemsForDay(day, workDate);
    if (pending.isEmpty) return null;
    final failed = day.items.where((item){
      final r = _latestRecordForItem(item, workDate);
      return r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted;
    }).length;
    if (failed > 0) return '$failed locații au fost marcate Refuzată/Nerealizată și mai sunt ${pending.length} de rezolvat.';
    final estimate = _estimatedEndForDay(day, now);
    final deadline = workWindowEnd(workDate);
    if (estimate != null && estimate.isAfter(deadline)) {
      return 'Ora estimată de final este ${timeText(estimate)}, după limita operațională ${timeText(deadline)}.';
    }
    if (now.isAfter(deadline) && pending.isNotEmpty) return 'Intervalul operațional s-a încheiat și au rămas ${pending.length} locații.';
    final lateThreshold = DateTime(workDate.year, workDate.month, workDate.day, 8, 30);
    if (estimate == null && now.isAfter(lateThreshold) && pending.length >= 2) {
      return 'După 08:30 au rămas ${pending.length} locații, iar istoricul nu este suficient pentru o estimare sigură.';
    }
    return null;
  }

  Future<void> _maybeRaisePlanAlert(WorkSchedule day, String reason) async {
    final programLearning = widget.settings.learning['program'];
    if (programLearning?.enabled != true) return;
    if (_planAlertInFlight.contains(day.id)) return;
    // Evităm alerte duplicate la fiecare rebuild, dar permitem una nouă
    // dacă riscul s-a schimbat sau a trecut o perioadă semnificativă.
    if (day.planAlertAt != null &&
        DateTime.now().difference(day.planAlertAt!).inMinutes < 60) return;
    if (day.planAlertReason == reason && day.planAlertAt != null &&
        DateTime.now().difference(day.planAlertAt!).inHours < 4) return;
    _planAlertInFlight.add(day.id);
    try {
      final updated = _cloneSchedule(day);
      updated.planAlertAt = DateTime.now();
      updated.planAlertReason = reason;
      await widget.saveSchedule(updated);
      widget.notifyTeam(team.id, 'Planul zilei este în risc', '${updated.graphName} · ${formatDate(updated.date)} · $reason');
      widget.log('Plan nerespectat / risc întârziere', '${team.name} · ${updated.graphName} · ${formatDate(updated.date)} · $reason');
      final routing = widget.settings.learning['routing'];
      if (programLearning!.mode == LearningMode.automatic && routing?.enabled == true &&
          routing?.mode == LearningMode.automatic &&
          (updated.lastRecalculatedAt == null ||
           DateTime.now().difference(updated.lastRecalculatedAt!).inMinutes >= 30)) {
        await _recalculateRemainingRoute(updated, automatic: true);
      }
    } catch (_) {
      // Avertizarea nu trebuie să blocheze ecranul operațional.
    } finally {
      _planAlertInFlight.remove(day.id);
    }
  }

  Location? _locationById(String id) {
    for (final l in widget.locations) { if (l.id == id) return l; }
    return null;
  }

  Future<List<double>?> _currentAnchor({required bool requestGps, required WorkSchedule day}) async {
    if (requestGps) {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever && await Geolocator.isLocationServiceEnabled()) {
          final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
          return <double>[pos.latitude, pos.longitude];
        }
      } catch (_) {}
    }
    final workDate = operationalWorkDate(DateTime.now());
    final relevant = widget.records.where((r)=>r.teamId==team.id && recordBelongsToWorkDate(r, workDate)).toList()
      ..sort((a,b)=>recordEventTime(b).compareTo(recordEventTime(a)));
    for (final r in relevant) {
      if (r.status != WorkAttemptStatus.completed && r.status != WorkAttemptStatus.running && r.status != WorkAttemptStatus.waitingAccess) continue;
      final l = _locationById(r.locationId);
      if (l?.latitude != null && l?.longitude != null) return <double>[l!.latitude!, l.longitude!];
    }
    return null;
  }

  double _routeKmFrom(double lat, double lon, List<ScheduleItem> items) {
    var km = 0.0;
    var aLat = lat; var aLon = lon;
    for (final item in items) {
      final l = _locationById(item.locationId);
      if (l?.latitude == null || l?.longitude == null) continue;
      km += Geolocator.distanceBetween(aLat, aLon, l!.latitude!, l.longitude!) / 1000.0;
      aLat = l.latitude!; aLon = l.longitude!;
    }
    return km;
  }

  int _learningExecutionCount(String locationId) => widget.records.where((r) =>
    r.locationId == locationId && r.completed && r.keptForLearning && r.duration != null
  ).length;

  String? _lastOperationalLocationId(DateTime workDate) {
    final relevant = widget.records.where((r) =>
      r.teamId == team.id && recordBelongsToWorkDate(r, workDate) &&
      (r.status == WorkAttemptStatus.completed || r.status == WorkAttemptStatus.running || r.status == WorkAttemptStatus.waitingAccess)
    ).toList()..sort((a,b)=>recordEventTime(a).compareTo(recordEventTime(b)));
    return relevant.isEmpty ? null : relevant.last.locationId;
  }

  Map<String, int> _executionTransitionCounts() {
    final grouped = <String, List<CentralizerRecord>>{};
    for (final r in widget.records.where((r) => r.teamId == team.id && r.completed && r.keptForLearning)) {
      final t = recordEventTime(r);
      final wd = operationalWorkDate(t);
      final key = '${r.teamId}_${wd.year}-${wd.month}-${wd.day}';
      grouped.putIfAbsent(key, () => <CentralizerRecord>[]).add(r);
    }
    final counts = <String, int>{};
    for (final values in grouped.values) {
      values.sort((a,b)=>recordEventTime(a).compareTo(recordEventTime(b)));
      for (var i=0;i+1<values.length;i++) {
        final key='${values[i].locationId}>${values[i+1].locationId}';
        counts[key]=(counts[key]??0)+1;
      }
    }
    return counts;
  }

  Future<Map<String, int>> _manualRoutingTransitionCounts() async {
    final counts=<String,int>{};
    try {
      final snap=await FirebaseFirestore.instance.collection('learningEvents')
        .where('teamId', isEqualTo: team.id).limit(300).get();
      for(final doc in snap.docs){
        final d=doc.data();
        if((d['category']??'').toString()!='routing')continue;
        final data=d['data'];
        if(data is! Map)continue;
        final raw=data['order'];
        if(raw is! List)continue;
        final order=raw.map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList();
        for(var i=0;i+1<order.length;i++){
          final key='${order[i]}>${order[i+1]}';
          counts[key]=(counts[key]??0)+2; // alegerea explicită a echipei cântărește dublu
        }
      }
    } catch(e) {
      debugPrint('[learning] Istoricul manual de rutare nu a putut fi citit: $e');
    }
    return counts;
  }

  Future<void> _recordRoutingChoice(WorkSchedule s, String source) async {
    try {
      await FirebaseFirestore.instance.collection('learningEvents').doc(idNow()).set({
        'actorUid': widget.currentUser.id,
        'actor': widget.currentUser.name,
        'category': 'routing',
        'event': source,
        'teamId': s.teamId,
        'scheduleId': s.id,
        'locationId': '',
        'mode': widget.settings.learning['routing']?.mode.name ?? LearningMode.manualApproval.name,
        'data': {'order': s.items.map((e)=>e.locationId).toList(), 'date': s.date.toIso8601String()},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch(e) {
      debugPrint('[learning] Alegerea traseului nu a putut fi jurnalizată: $e');
    }
  }

  // Optimizare locală 2-opt: păstrează toate intervențiile neîncepute și
  // combină distanța GPS cu tranzițiile Learning observate (fără a inventa
  // durate sau distanțe rutiere). Punctul final este inclus în cost.
  List<ScheduleItem> _improveLearnedRoute(
    List<ScheduleItem> initial, double startLat, double startLon,
    String? previousId, Map<String, int> transitions, WorkSchedule day,
  ) {
    if (initial.length < 3 || initial.length > 25) return initial;
    double score(List<ScheduleItem> order) {
      var lat = startLat, lon = startLon, km = 0.0;
      var prev = previousId;
      for (final item in order) {
        final l = _locationById(item.locationId)!;
        km += Geolocator.distanceBetween(lat, lon, l.latitude!, l.longitude!) / 1000;
        // Bonus plafonat: o singură tranziție repetată nu domină kilometri mulți.
        final samples = prev == null ? 0 : (transitions['$prev>${item.locationId}'] ?? 0);
        km -= (samples.clamp(0, 4) * 0.35);
        lat = l.latitude!; lon = l.longitude!;
        prev = item.locationId;
      }
      if (day.returnLatitude != null && day.returnLongitude != null) {
        km += Geolocator.distanceBetween(lat, lon, day.returnLatitude!, day.returnLongitude!) / 1000;
      }
      return km;
    }
    var best = List<ScheduleItem>.from(initial);
    var bestScore = score(best);
    for (var pass = 0; pass < 4; pass++) {
      var changed = false;
      for (var i = 0; i < best.length - 1; i++) {
        for (var j = i + 1; j < best.length; j++) {
          final candidate = <ScheduleItem>[
            ...best.take(i), ...best.sublist(i, j + 1).reversed, ...best.skip(j + 1),
          ];
          final candidateScore = score(candidate);
          if (candidateScore < bestScore - 0.001) {
            best = candidate;
            bestScore = candidateScore;
            changed = true;
          }
        }
      }
      if (!changed) break;
    }
    return best;
  }

  Future<bool> _recalculateRemainingRoute(WorkSchedule day, {bool automatic = false}) async {
    final workDate = operationalWorkDate(DateTime.now());
    final movable = _pendingItemsForDay(day, workDate, includeActive: false);
    if (movable.length < 2) {
      if (!automatic && mounted) showErrorMessage(context, 'Sunt necesare cel puțin 2 locații rămase, neîncepute, pentru recalculare.');
      return false;
    }
    final insufficient = movable.where((i) => _learningExecutionCount(i.locationId) < 3).toList();
    if (insufficient.isNotEmpty) {
      if (!automatic && mounted) {
        final names = insufficient.take(4).map((e)=>e.locationNameSnapshot).join(', ');
        showErrorMessage(context, 'Learning nu propune ordine până când fiecare locație rămasă are minimum 3 execuții. Lipsesc date pentru ${insufficient.length}: $names${insufficient.length>4?'…':''}');
      }
      return false;
    }
    final anchor = await _currentAnchor(requestGps: !automatic, day: day);
    if (anchor == null) {
      if (!automatic && mounted) showErrorMessage(context, 'Nu am un punct de plecare GPS. Activează locația sau finalizează o locație înainte de recalculare.');
      return false;
    }
    final withGps = movable.where((i){final l=_locationById(i.locationId);return l?.latitude!=null&&l?.longitude!=null;}).toList();
    final withoutGps = movable.where((i){final l=_locationById(i.locationId);return l?.latitude==null||l?.longitude==null;}).toList();
    if (withGps.length < 2) {
      if (!automatic && mounted) showErrorMessage(context, 'Prea puține locații rămase au GPS pentru a calcula o ordine mai bună.');
      return false;
    }
    // Nu reordonăm automat un traseu incomplet: ar putea muta săli fără GPS
    // la final, fără ca echipa să știe că optimizarea a fost parțială.
    if (withoutGps.isNotEmpty) {
      if (!automatic && mounted) {
        showErrorMessage(context, 'Recalcularea necesită GPS pentru toate locațiile rămase. Lipsesc coordonate pentru: ${withoutGps.map((e) => e.locationNameSnapshot).join(', ')}.');
      }
      return false;
    }
    final executionTransitions = _executionTransitionCounts();
    final manualTransitions = await _manualRoutingTransitionCounts();
    final transitionCounts = <String,int>{...executionTransitions};
    for(final e in manualTransitions.entries) transitionCounts[e.key]=(transitionCounts[e.key]??0)+e.value;
    final remaining = <ScheduleItem>[...withGps];
    final optimized = <ScheduleItem>[];
    var lat = anchor[0], lon = anchor[1];
    String? previousId = _lastOperationalLocationId(workDate);
    var learnedDecisions = 0;
    var transitionSamples = 0;
    while (remaining.isNotEmpty) {
      remaining.sort((a,b){
        final la=_locationById(a.locationId)!; final lb=_locationById(b.locationId)!;
        final da=Geolocator.distanceBetween(lat,lon,la.latitude!,la.longitude!);
        final db=Geolocator.distanceBetween(lat,lon,lb.latitude!,lb.longitude!);
        final ca=previousId==null?0:(transitionCounts['$previousId>${a.locationId}']??0);
        final cb=previousId==null?0:(transitionCounts['$previousId>${b.locationId}']??0);
        if(ca!=cb)return cb.compareTo(ca); // istoricul echipei are prioritate
        return da.compareTo(db); // GPS este departajare, nu sursa principală de Learning
      });
      final next=remaining.removeAt(0);
      final learned = previousId==null?0:(transitionCounts['$previousId>${next.locationId}']??0);
      if(learned>0){learnedDecisions++;transitionSamples+=learned;}
      optimized.add(next);
      final l=_locationById(next.locationId)!; lat=l.latitude!; lon=l.longitude!;
      previousId=next.locationId;
    }
    // Îmbunătățire globală față de alegerea strict locală a următoarei săli.
    // Se aplică doar locațiilor cu minimum 3 execuții și GPS valid.
    final refined = _improveLearnedRoute(optimized, anchor[0], anchor[1],
        _lastOperationalLocationId(workDate), transitionCounts, day);
    optimized
      ..clear()
      ..addAll(refined);
    // Mapbox Optimization este doar o propunere asistată: nu înlocuiește
    // deciziile Learning și nu schimbă automat ordinea de lucru.
    // Punctele de plecare și sosire sunt fixe și nu devin intervenții.
    var mapboxSuggested = false;
    if (!automatic && kMapboxEnabled && optimized.length >= 2 &&
        optimized.length <= 10 && day.returnLatitude != null &&
        day.returnLongitude != null) {
      final mapboxInput = <List<double>>[
        <double>[anchor[0], anchor[1]],
        ...optimized.map((item) {
          final location = _locationById(item.locationId)!;
          return <double>[location.latitude!, location.longitude!];
        }),
        <double>[day.returnLatitude!, day.returnLongitude!],
      ];
      final proposedIndices = await _mapboxServices.optimizedOrder(mapboxInput);
      if (proposedIndices != null && proposedIndices.length == mapboxInput.length) {
        final proposal = proposedIndices.skip(1).take(optimized.length)
            .map((index) => optimized[index - 1]).toList();
        final originalIds = optimized.map((e) => e.locationId).toList();
        final proposalIds = proposal.map((e) => e.locationId).toList();
        if (proposalIds.toSet().length == originalIds.length &&
            proposalIds.toSet().containsAll(originalIds) &&
            proposalIds.join('|') != originalIds.join('|')) {
          final oldRoadKm = await _mapboxServices.drivingKm(mapboxInput);
          final newRoadKm = await _mapboxServices.drivingKm(<List<double>>[
            mapboxInput.first,
            ...proposedIndices.skip(1).take(optimized.length)
                .map((index) => mapboxInput[index]),
            mapboxInput.last,
          ]);
          // Acceptăm sugestia doar dacă Mapbox confirmă economie rutieră;
          // utilizatorul trebuie în continuare să o aprobe în dialog.
          if (oldRoadKm != null && newRoadKm != null &&
              newRoadKm + 0.1 < oldRoadKm) {
            optimized..clear()..addAll(proposal);
            mapboxSuggested = true;
          }
        }
      }
    }
    optimized.addAll(withoutGps);
    // Nu salvăm și nu notificăm dacă ordinea propusă este identică.
    final unchanged = movable.length == optimized.length &&
        List.generate(movable.length, (i) => movable[i].locationId == optimized[i].locationId).every((same) => same);
    if (unchanged) {
      if (!automatic && mounted) showSuccessMessage(context, 'Traseul rămas este deja în ordinea recomandată.');
      return false;
    }
    final oldKm = _routeKmFrom(anchor[0], anchor[1], movable);
    final newKm = _routeKmFrom(anchor[0], anchor[1], optimized);
    if (!automatic) {
      final ok = await showDialog<bool>(context: context, builder:(c)=>AlertDialog(
        title: const Text('Recalculare asistată a traseului'),
        content: SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Traseu rămas: ${oldKm.toStringAsFixed(1)} km → ${newKm.toStringAsFixed(1)} km estimați.'),
          const SizedBox(height:8),
          if (mapboxSuggested) const Text('Propunere Mapbox bazată pe drumuri reale; necesită aprobare.', style: TextStyle(fontWeight:FontWeight.w600)),
          const Text('Ordinea propusă:',style:TextStyle(fontWeight:FontWeight.bold)),
          const SizedBox(height:6),
          ...optimized.take(8).toList().asMap().entries.map((e)=>Text('${e.key+1}. ${e.value.locationNameSnapshot}')),
          if(optimized.length>8)Text('… și încă ${optimized.length-8} locații'),
          if(withoutGps.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text('${withoutGps.length} locații fără GPS au fost păstrate la final, în ordinea existentă.')),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Păstrează ordinea')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Aplică ordinea'))],
      ))??false;
      if(!ok)return false;
    }
    final updated = _cloneSchedule(day);
    final movableIds = movable.map((e)=>e.locationId).toSet();
    var p = 0;
    for (var i=0;i<updated.items.length;i++) {
      if (movableIds.contains(updated.items[i].locationId)) updated.items[i] = optimized[p++];
    }
    for (var i=0;i<updated.items.length;i++) updated.items[i].order=i+1;
    updated.autoProposed = true;
    updated.lastRecalculatedAt = DateTime.now();
    updated.recalculationCount += 1;
    final completedSamples = movable.fold<int>(0, (sum, i) => sum + _learningExecutionCount(i.locationId));
    updated.learningSamples = completedSamples + transitionSamples;
    updated.learningConfidence = movable.isEmpty ? 0 : ((learnedDecisions / movable.length) * 0.65 + (completedSamples.clamp(0, 30) / 30) * 0.35).clamp(0.0, 1.0);
    updated.learningExplanation = learnedDecisions > 0
      ? 'Ordinea combină istoricul echipei cu optimizarea 2-opt a distanțelor GPS, inclusiv destinația finală. Toate cele ${movable.length} locații au minimum 3 execuții.'
      : 'Nu există încă tranziții repetate; optimizarea 2-opt folosește distanțe GPS aproximative, inclusiv destinația finală. Fiecare locație are minimum 3 execuții.';
    if (mapboxSuggested) {
      updated.learningExplanation = '${updated.learningExplanation} Propunere Mapbox verificată rutier și aprobată de utilizator.';
    }
    await widget.saveSchedule(updated);
    unawaited(_recordRoutingChoice(updated, automatic ? 'automatic_route_applied' : 'assisted_route_applied'));
    final label = automatic ? 'Recalculare automată traseu' : 'Recalculare asistată traseu';
    widget.log(label, '${team.name} · ${updated.graphName} · ${formatDate(updated.date)} · ${oldKm.toStringAsFixed(1)} km → ${newKm.toStringAsFixed(1)} km');
    widget.notifyTeam(team.id, automatic ? 'Traseu recalculat automat' : 'Traseu recalculat', '${updated.graphName} · ${formatDate(updated.date)} · ${newKm.toStringAsFixed(1)} km rămași estimați.');
    if(!automatic && mounted)showSuccessMessage(context,'Noua ordine a fost salvată. Estimare traseu: ${newKm.toStringAsFixed(1)} km.');
    return true;
  }

  Future<void> _transferRemainingToNextDay(WorkSchedule day) async {
    final workDate = operationalWorkDate(DateTime.now());
    final transferable = _pendingItemsForDay(day, workDate, includeActive: false);
    if (transferable.isEmpty) { if(mounted)showErrorMessage(context,'Nu există locații neîncepute care pot fi transferate.'); return; }
    final nextDate = DateTime(day.date.year,day.date.month,day.date.day).add(const Duration(days:1));
    final ok = await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Transferă locațiile rămase'),
      content:Text('${transferable.length} locații neîncepute vor fi mutate în ${formatDate(nextDate)} și marcate ca transferate. Locația aflată în lucru/așteptare rămâne pe ziua curentă.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Transferă'))],
    ))??false;
    if(!ok)return;
    final current = _cloneSchedule(day);
    final ids = transferable.map((e)=>e.locationId).toSet();
    current.items.removeWhere((e)=>ids.contains(e.locationId));
    for(var i=0;i<current.items.length;i++)current.items[i].order=i+1;
    WorkSchedule? existingNext;
    for(final s in graphSchedules){if(sameDay(s.date,nextDate)){existingNext=s;break;}}
    final next = existingNext==null
      ? WorkSchedule(id:idNow(),teamId:day.teamId,graphId:day.graphId,graphName:day.graphName,date:nextDate,items:<ScheduleItem>[],active:true,started:day.started)
      : _cloneSchedule(existingNext);
    final moved = transferable.map((e)=>ScheduleItem(locationId:e.locationId,locationNameSnapshot:e.locationNameSnapshot,addressSnapshot:e.addressSnapshot,typeSnapshot:e.typeSnapshot,categoryIdSnapshot:e.categoryIdSnapshot,order:0,transferred:true,facadePlanned:e.facadePlanned)).toList();
    next.items = <ScheduleItem>[...moved,...next.items.where((x)=>!ids.contains(x.locationId))];
    for(var i=0;i<next.items.length;i++)next.items[i].order=i+1;
    await widget.saveSchedule(current);
    await widget.saveSchedule(next);
    widget.log('Transfer locații între zile','${team.name} · ${day.graphName} · ${formatDate(day.date)} → ${formatDate(nextDate)} · ${transferable.length} locații');
    widget.notifyTeam(team.id,'Locații transferate','${transferable.length} locații au fost mutate în ${formatDate(nextDate)}.');
    if(mounted)showSuccessMessage(context,'${transferable.length} locații au fost transferate în ziua următoare.');
  }

  void _ensureGraphSelection() {
    if (graphIds.isEmpty) { selectedGraphId = null; return; }
    if (selectedGraphId == null || !graphIds.contains(selectedGraphId)) {
      final active = teamSchedules.where((s)=>s.started && !s.closed).toList();
      selectedGraphId = active.isNotEmpty ? active.last.graphId : graphIds.first;
    }
  }

  @override Widget build(BuildContext context) {
    if (widget.teams.isEmpty) return const _Page(title:'Grafic de lucru',subtitle:'Planificare lunară simplificată',child:_Empty(icon:Icons.groups_outlined,text:'Nu există încă nicio echipă.'));
    if (teamIndex >= widget.teams.length) teamIndex = 0;
    _ensureGraphSelection();
    final can = widget.canEditProgram && widget.canEditTeam(team.id);
    final head = graphHead;
    final car = assignedCar;
    final km = estimateGraphDistanceKm(graphSchedules, widget.locations);
    final routeData = graphRoutePoints(graphSchedules, widget.locations);
    final liters = car != null && car.averageConsumption > 0 ? km * car.averageConsumption / 100 : 0.0;
    final cost = car != null && car.fuelPricePerLiter > 0 ? liters * car.fuelPricePerLiter : 0.0;
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    WorkSchedule? todayDay;
    for (final s in graphSchedules) { if (sameDay(s.date, workDate)) { todayDay = s; break; } }
    final todayPending = todayDay == null ? <ScheduleItem>[] : _pendingItemsForDay(todayDay, workDate);
    final todayTransferable = todayDay == null ? <ScheduleItem>[] : _pendingItemsForDay(todayDay, workDate, includeActive:false);
    final todayDone = todayDay == null ? 0 : todayDay.items.where((i)=>_latestRecordForItem(i, workDate)?.completed==true).length;
    final todayFailed = todayDay == null ? 0 : todayDay.items.where((i){final r=_latestRecordForItem(i,workDate);return r?.status==WorkAttemptStatus.refused||r?.status==WorkAttemptStatus.notCompleted;}).length;
    final todayEstimate = todayDay == null ? null : _estimatedEndForDay(todayDay, now);
    final planRisk = todayDay == null ? null : _planRiskReason(todayDay, now);
    final lastRecalculatedAt = todayDay?.lastRecalculatedAt;
    if (todayDay != null && planRisk != null && !_planAlertInFlight.contains(todayDay.id) &&
        (todayDay.planAlertAt == null || now.difference(todayDay.planAlertAt!).inMinutes >= 60) &&
        (todayDay.planAlertReason != planRisk || todayDay.planAlertAt == null || now.difference(todayDay.planAlertAt!).inHours >= 4)) {
      final alertSchedule = todayDay;
      final alertReason = planRisk;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_maybeRaisePlanAlert(alertSchedule, alertReason));
        }
      });
    }
    return _Page(
      title:'Grafic de lucru',
      subtitle:'Creezi zilele una după alta, finalizezi o singură dată, apoi ai tot graficul într-o singură listă.',
      actions:[if(can) FilledButton.icon(onPressed:_newGraph,icon:const Icon(Icons.add),label:const Text('Creează grafic'))],
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _TeamSelector(teams:widget.teams,selected:teamIndex,onChanged:(v)=>setState((){teamIndex=v;selectedGraphId=null;})),
        const SizedBox(height:10),
        if(graphIds.isNotEmpty) DropdownButtonFormField<String>(
          value:selectedGraphId,
          decoration:const InputDecoration(labelText:'Grafic de lucru'),
          items:graphIds.map((id){final first=teamSchedules.firstWhere((x)=>x.graphId==id);final days=teamSchedules.where((x)=>x.graphId==id).length;return DropdownMenuItem(value:id,child:Text('${first.graphName} · $days zile'));}).toList(),
          onChanged:(v)=>setState(()=>selectedGraphId=v),
        ) else const _InfoCard(icon:Icons.calendar_month,title:'Niciun grafic creat',text:'Apasă „Creează grafic”. Alegi sălile pentru Ziua 1, apoi mergi direct la Ziua 2 fără să închizi fereastra.'),
        if(head!=null)...[
          const SizedBox(height:12),
          Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(head.graphName,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),Chip(label:Text(head.closed?'Închis':head.paused?'Pauză':head.started?'Activ':'Pregătit'))]),
            Text('${formatDate(graphSchedules.first.date)} → ${formatDate(graphSchedules.last.date)}'),
            const SizedBox(height:10),
            Wrap(spacing:8,runSpacing:8,children:[
              _StatMini(label:'Zile',value:'${graphSchedules.length}',icon:Icons.calendar_view_week),
              _StatMini(label:'Locații',value:'${graphSchedules.fold<int>(0,(a,b)=>a+b.items.length)}',icon:Icons.storefront),
              _StatMini(label:'Km GPS (linie dreaptă)',value:'${km.toStringAsFixed(1)} km',icon:Icons.route),
              _StatMini(label:'Consum',value:liters>0?'${liters.toStringAsFixed(1)} l':'nesetat',icon:Icons.local_gas_station),
              _StatMini(label:'Cost carburant',value:cost>0?'${cost.toStringAsFixed(2)} lei':'nesetat',icon:Icons.payments_outlined),
              if(todayDay!=null)_StatMini(label:'Azi',value:'$todayDone/${todayDay.items.length} făcute',icon:Icons.task_alt),
              if(todayFailed>0)_StatMini(label:'Probleme azi',value:'$todayFailed',icon:Icons.warning_amber_rounded),
              if(todayEstimate!=null&&todayPending.isNotEmpty)_StatMini(label:'Final estimat',value:timeText(todayEstimate),icon:Icons.schedule_send),
            ]),
            if(planRisk!=null)...[
              const SizedBox(height:10),
              Card(color:Theme.of(context).colorScheme.errorContainer,child:ListTile(leading:Icon(Icons.warning_amber_rounded,color:Theme.of(context).colorScheme.error),title:const Text('Planul zilei este în risc',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(planRisk))),
            ],
            if(todayDay != null && lastRecalculatedAt != null)...[const SizedBox(height:6),Text('Ultima recalculare: ${formatDate(lastRecalculatedAt)} ${timeText(lastRecalculatedAt)} · ${todayDay.recalculationCount} recalculări',style:Theme.of(context).textTheme.bodySmall)],
            const SizedBox(height:8),
            if(car==null) const Text('Mașina nu este atribuită echipei. Seteaz-o din Admin → Mașini / Echipe.',style:TextStyle(fontSize:12)),
            if(car!=null) Text('${car.plate}${car.makeModel.isEmpty?'':' · ${car.makeModel}'} · ${car.fuelType} · ${car.averageConsumption>0?'${car.averageConsumption.toStringAsFixed(1)} l/100 km':'consum nesetat'} · ${car.fuelPricePerLiter>0?'${car.fuelPricePerLiter.toStringAsFixed(2)} lei/l':'preț carburant nesetat'}',style:const TextStyle(fontSize:12)),
            const SizedBox(height:10),
            Wrap(spacing:8,runSpacing:8,children:[
              FilledButton.tonalIcon(onPressed:_exportPdf,icon:const Icon(Icons.picture_as_pdf),label:const Text('Exportă PDF')),
              OutlinedButton.icon(onPressed:_exportJpeg,icon:const Icon(Icons.image_outlined),label:const Text('Exportă JPEG')),
              OutlinedButton.icon(onPressed:_openOmv,icon:const Icon(Icons.local_gas_station_outlined),label:const Text('Verifică preț OMV')),
            ]),
            if(can)...[
              const SizedBox(height:10),
              Wrap(spacing:8,runSpacing:8,children:[
                if(!head.started&&!head.closed) FilledButton.icon(onPressed:_startGraph,icon:const Icon(Icons.play_arrow),label:const Text('START GRAFIC')),
                if(head.started&&!head.closed&&!head.paused) OutlinedButton.icon(onPressed:_pauseGraph,icon:const Icon(Icons.pause),label:const Text('Pauză')),
                if(head.started&&!head.closed&&head.paused) FilledButton.tonalIcon(onPressed:_resumeGraph,icon:const Icon(Icons.play_circle_outline),label:const Text('Reia')),
                if(head.started&&!head.closed) OutlinedButton.icon(onPressed:_postponeGraph,icon:const Icon(Icons.event_repeat),label:const Text('Amână program')),
                if(todayDay!=null&&!head.closed) OutlinedButton.icon(onPressed:todayTransferable.length<2?null:()=>_recalculateRemainingRoute(todayDay!),icon:const Icon(Icons.alt_route),label:const Text('Recalculează traseul rămas')),
                if(todayDay!=null&&!head.closed) OutlinedButton.icon(onPressed:todayTransferable.isEmpty?null:()=>_transferRemainingToNextDay(todayDay!),icon:const Icon(Icons.move_down),label:const Text('Transferă rămase')),
                if(!head.closed) FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Theme.of(context).colorScheme.error,foregroundColor:Theme.of(context).colorScheme.onError),onPressed:_closeGraph,icon:const Icon(Icons.stop),label:const Text('STOP GRAFIC')),
              ]),
            ],
          ]))),
          const SizedBox(height:12),
          RepaintBoundary(key:_graphCaptureKey,child:_graphOverview()),
          if(can&&!head.closed)...[
            const SizedBox(height:12),
            ExpansionTile(
              title:const Text('Editare zile',style:TextStyle(fontWeight:FontWeight.bold)),
              subtitle:const Text('Adaugă, scoate sau schimbă ordinea locațiilor după finalizarea graficului.'),
              children:graphSchedules.map((s)=>Padding(padding:const EdgeInsets.only(bottom:10),child:_ScheduleCardFull(
                schedule:s,locations:widget.locations,categories:widget.categories,records:widget.records,canEdit:can,
                onAdd:()=>_addLocations(s),onRemove:(item)=>unawaited(_removeItem(s,item)),onReorder:(a,b)=>unawaited(_reorder(s,a,b)),
              ))).toList(),
            ),
          ],
          const SizedBox(height:8),
          if (!routeData.complete) Card(child: ListTile(leading: const Icon(Icons.warning_amber_rounded), title: const Text('Traseu GPS incomplet'), subtitle: Text('Completează coordonatele pentru: ${[if(routeData.missingDeparture) 'plecare', ...routeData.missingLocations, if(routeData.missingDestination) 'destinație'].join(', ')}. Km și consumul nu pot fi estimate corect.'))),
          if (routeData.complete && routeData.points.length >= 2)
            FutureBuilder<double?>(
              future: _roadDistanceForGraph(graphSchedules),
              builder: (context, snapshot) {
                final roadKm = snapshot.data;
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ListTile(
                    leading: Icon(Icons.route),
                    title: Text('Se calculează kilometrii rutieri…'),
                  );
                }
                if (roadKm == null) {
                  return const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Rutarea rutieră nu este disponibilă'),
                    subtitle: Text('Valorile de mai sus sunt în linie dreaptă, nu kilometri rutieri. Consumul real poate fi mai mare.'),
                  );
                }
                final roadLiters = car != null && car.averageConsumption > 0
                    ? roadKm * car.averageConsumption / 100 : null;
                final roadCost = roadLiters != null && car != null && car.fuelPricePerLiter > 0
                    ? roadLiters * car.fuelPricePerLiter : null;
                return _InfoCard(
                  icon: Icons.route,
                  title: 'Traseu rutier complet',
                  text: '${roadKm.toStringAsFixed(1)} km pe drumuri · '
                      'Consum: ${roadLiters?.toStringAsFixed(1) ?? 'nesetat'} L · '
                      'Cost: ${roadCost?.toStringAsFixed(2) ?? 'nesetat'} lei. '
                      'Include plecarea, toate sălile și destinația finală.',
                );
              },
            ),
          _InfoCard(icon:Icons.info_outline,title:'Estimare traseu complet',text:head.departureName.isNotEmpty&&head.returnName.isNotEmpty?'${head.departureName} → toate sălile din grafic → ${head.returnName}. ${km.toStringAsFixed(1)} km estimați; plecarea și întoarcerea sunt folosite numai la deplasare și nu intră în Centralizator.':'La START GRAFIC alegi plecarea și punctul final. Km, consumul și costul se calculează pe întregul traseu. Numărul de zile rămâne strict numărul zilelor de lucru.'),
        ],
      ]),
    );
  }

  Widget _graphOverview(){
    final days=[...graphSchedules]..sort((a,b)=>a.date.compareTo(b.date));
    return Container(
      width:double.infinity,
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(18),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(graphHead?.graphName??'Grafic',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        ...days.asMap().entries.map((entry){
          final day=entry.value;final ordered=[...day.items]..sort((a,b)=>a.order.compareTo(b.order));
          return Padding(padding:const EdgeInsets.only(bottom:12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[CircleAvatar(radius:15,child:Text('${entry.key+1}')),const SizedBox(width:8),Expanded(child:Text('Ziua ${entry.key+1} · ${formatDate(day.date)}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16)))]),
            const SizedBox(height:5),
            ...ordered.asMap().entries.map((x)=>InkWell(
              onTap:()=>_navigateToItem(x.value),
              borderRadius:BorderRadius.circular(8),
              child:Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:4),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                SizedBox(width:28,child:Text('${x.key+1}.',style:const TextStyle(fontWeight:FontWeight.bold))),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.value.locationNameSnapshot,style:const TextStyle(fontWeight:FontWeight.w700)),Text(x.value.addressSnapshot,style:Theme.of(context).textTheme.bodySmall)])),
                const Icon(Icons.navigation_outlined,size:18),
              ])),
            )),
          ]));
        }),
      ]),
    );
  }

  Future<void> _newGraph() async {
    final available=widget.locations.where((l)=>l.selectableForProgram).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final days=<List<String>>[<String>[]];
    var dayIndex=0; var query='';
    final drafted=await showDialog<List<List<String>>>(context:context,barrierDismissible:false,builder:(dialogContext)=>StatefulBuilder(builder:(c,setD){
      final selected=days[dayIndex];
      final filtered=available.where((l){final q=query.trim().toLowerCase();return q.isEmpty||l.name.toLowerCase().contains(q)||l.address.toLowerCase().contains(q)||categoryName(widget.categories,l.categoryId,fallbackType:l.type).toLowerCase().contains(q);}).toList();
      return AlertDialog(
        title:Text('Creează grafic · Ziua ${dayIndex+1}'),
        content:SizedBox(width:760,height:MediaQuery.sizeOf(c).height*.72,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Wrap(spacing:6,runSpacing:6,children:days.asMap().entries.map((e)=>ChoiceChip(label:Text('Ziua ${e.key+1} · ${e.value.length}'),selected:e.key==dayIndex,onSelected:(_)=>setD((){dayIndex=e.key;query='';}))).toList()),
          const SizedBox(height:8),
          if(selected.isNotEmpty) Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(c).colorScheme.primaryContainer.withValues(alpha:.45),borderRadius:BorderRadius.circular(12)),child:Wrap(spacing:6,runSpacing:6,children:selected.asMap().entries.map((e){final l=available.firstWhere((x)=>x.id==e.value);return Chip(label:Text('${e.key+1}. ${l.name}'),onDeleted:()=>setD(()=>selected.remove(e.value)));}).toList())),
          const SizedBox(height:8),
          TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Caută sală / adresă / categorie'),onChanged:(v)=>setD(()=>query=v)),
          const SizedBox(height:8),
          Expanded(child:ListView(children:filtered.map((l)=>CheckboxListTile(
            value:selected.contains(l.id),
            secondary: categoryBrandWidget(l.categoryId, size: 28, fallbackColor: categoryColor(widget.categories,l.categoryId,fallbackType:l.type)),
            title:Text(l.name),subtitle:Text('${categoryName(widget.categories,l.categoryId,fallbackType:l.type)} · ${l.address}'),
            onChanged:(v)=>setD((){if(v==true){if(!selected.contains(l.id))selected.add(l.id);}else{selected.remove(l.id);}}),
          )).toList())),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),
          if(dayIndex>0) OutlinedButton.icon(onPressed:()=>setD((){dayIndex--;query='';}),icon:const Icon(Icons.arrow_back),label:const Text('Ziua anterioară')),
          FilledButton.tonalIcon(onPressed:selected.isEmpty?null:()=>setD((){if(dayIndex==days.length-1)days.add(<String>[]);dayIndex++;query='';}),icon:const Icon(Icons.arrow_forward),label:const Text('Următoarea zi')),
          FilledButton.icon(onPressed:days.where((d)=>d.isNotEmpty).isEmpty?null:()=>Navigator.pop(c,days.where((d)=>d.isNotEmpty).map((d)=>[...d]).toList()),icon:const Icon(Icons.done_all),label:const Text('Finalizare')),
        ],
      );
    }));
    if(drafted==null||drafted.isEmpty)return;

    // Planificarea fațadei este legată de intervenție, nu de locație în general.
    final facadePlanKeys=<String>{};
    final facadeAccepted=await showDialog<bool>(
      context:context,
      barrierDismissible:false,
      builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
        title:const Text('Planificare fațade'),
        content:SizedBox(
          width:680,
          height:MediaQuery.sizeOf(c).height*.62,
          child:ListView(children:[
            const Padding(
              padding:EdgeInsets.only(bottom:10),
              child:Text('Bifează intervențiile la care este planificată și curățarea fațadei. La ieșirea din locație răspunsul DA/NU va fi obligatoriu.'),
            ),
            ...drafted.asMap().entries.expand((dayEntry){
              final day=dayEntry.key;
              return <Widget>[
                Padding(padding:const EdgeInsets.fromLTRB(4,12,4,4),child:Text('Ziua ${day+1}',style:const TextStyle(fontWeight:FontWeight.w900))),
                ...dayEntry.value.map((id){
                  final l=available.firstWhere((x)=>x.id==id);
                  final key='$day:${l.id}';
                  return CheckboxListTile(
                    value:facadePlanKeys.contains(key),
                    title:Text(l.name),
                    subtitle:Text(l.facadeM2>0?'Fațadă înregistrată: ${l.facadeM2.toStringAsFixed(l.facadeM2%1==0?0:1)} m²':'Fațadă fără suprafață setată'),
                    onChanged:(v)=>setD((){if(v==true){facadePlanKeys.add(key);}else{facadePlanKeys.remove(key);}}),
                  );
                }),
              ];
            }),
          ]),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Înapoi')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Continuă')),
        ],
      )),
    );
    if(facadeAccepted!=true)return;

    DateTime startDate=operationalWorkDate(DateTime.now());
    final name=TextEditingController(text:graphDefaultName(startDate));
    final meta=await showDialog<Map<String,dynamic>>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD){
      final endDate=DateTime(startDate.year,startDate.month,startDate.day).add(Duration(days:drafted.length-1));
      return AlertDialog(title:const Text('Finalizează Graficul de lucru'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Nume grafic')),
        const SizedBox(height:12),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.play_circle_outline),title:const Text('Data început'),subtitle:Text(formatDate(startDate)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:c,firstDate:DateTime(2025),lastDate:DateTime(2035),initialDate:startDate);if(d!=null)setD(()=>startDate=d);}),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.flag_outlined),title:const Text('Data final'),subtitle:Text(formatDate(endDate))),
        Text('${drafted.length} zile · ${drafted.fold<int>(0,(a,b)=>a+b.length)} locații selectate'),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Înapoi')),FilledButton(onPressed:()=>Navigator.pop(c,{'name':name.text.trim().isEmpty?graphDefaultName(startDate):name.text.trim(),'start':startDate}),child:const Text('Creează graficul'))]);
    }));
    name.dispose();
    if(meta==null)return;
    final graphId=idNow();final graphName=meta['name'] as String;final start=meta['start'] as DateTime;
    try{
      for(var d=0;d<drafted.length;d++){
        final date=DateTime(start.year,start.month,start.day).add(Duration(days:d));
        final ids=drafted[d];
        final items=<ScheduleItem>[];
        for(var i=0;i<ids.length;i++){final l=available.firstWhere((x)=>x.id==ids[i]);items.add(ScheduleItem(locationId:l.id,locationNameSnapshot:l.name,addressSnapshot:l.address,typeSnapshot:l.type,categoryIdSnapshot:l.categoryId,order:i+1,facadePlanned:facadePlanKeys.contains('$d:${l.id}')));}
        await widget.saveSchedule(WorkSchedule(id:idNow(),teamId:team.id,graphId:graphId,graphName:graphName,date:date,items:items));
      }
      widget.log('Grafic de lucru creat','$graphName · ${drafted.length} zile · ${team.name}');
      widget.notifyTeam(team.id,'Grafic de lucru creat','$graphName · ${drafted.length} zile.');
      if(mounted){setState(()=>selectedGraphId=graphId);showSuccessMessage(context,'Graficul a fost creat cu ${drafted.length} zile.');}
    }catch(e){if(mounted)showErrorMessage(context,'Graficul nu a putut fi creat: $e');}
  }

  Future<void> _addLocations(WorkSchedule s) async {
    final picked=await _locationDialog(s.items.map((i)=>i.locationId).toList());
    if(picked==null)return;
    final additions=picked.where((l)=>!s.items.any((i)=>i.locationId==l.id)).toList();
    if(additions.isEmpty)return;
    final facadeIds=<String>{};
    final accepted=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:const Text('Fațadă pentru locațiile adăugate'),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:additions.map((l)=>CheckboxListTile(
        value:facadeIds.contains(l.id),
        title:Text(l.name),
        subtitle:Text(l.facadeM2>0?'Fațadă înregistrată: ${l.facadeM2.toStringAsFixed(l.facadeM2%1==0?0:1)} m²':'Bifează dacă fațada este planificată la această intervenție.'),
        onChanged:(v)=>setD((){if(v==true){facadeIds.add(l.id);}else{facadeIds.remove(l.id);}}),
      )).toList()))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Adaugă')),
      ],
    )));
    if(accepted!=true)return;
    final updated=_cloneSchedule(s);var order=updated.items.length+1;
    for(final l in additions){updated.items.add(ScheduleItem(locationId:l.id,locationNameSnapshot:l.name,addressSnapshot:l.address,typeSnapshot:l.type,categoryIdSnapshot:l.categoryId,order:order++,facadePlanned:facadeIds.contains(l.id)));}
    await _saveWithFeedback(updated,success:'Locațiile au fost adăugate în ziua selectată.',auditAction:'Locații adăugate în Grafic');
  }
  WorkSchedule _cloneSchedule(WorkSchedule s)=>WorkSchedule(id:s.id,teamId:s.teamId,graphId:s.graphId,graphName:s.graphName,date:s.date,items:s.items.map((i)=>ScheduleItem(locationId:i.locationId,locationNameSnapshot:i.locationNameSnapshot,addressSnapshot:i.addressSnapshot,typeSnapshot:i.typeSnapshot,categoryIdSnapshot:i.categoryIdSnapshot,order:i.order,transferred:i.transferred,facadePlanned:i.facadePlanned)).toList(),active:s.active,closed:s.closed,started:s.started,paused:s.paused,postponed:s.postponed,autoProposed:s.autoProposed,planAlertAt:s.planAlertAt,planAlertReason:s.planAlertReason,lastRecalculatedAt:s.lastRecalculatedAt,recalculationCount:s.recalculationCount,learningExplanation:s.learningExplanation,learningConfidence:s.learningConfidence,learningSamples:s.learningSamples,departureName:s.departureName,departureLatitude:s.departureLatitude,departureLongitude:s.departureLongitude,returnName:s.returnName,returnLatitude:s.returnLatitude,returnLongitude:s.returnLongitude);
  Future<void> _saveWithFeedback(WorkSchedule s,{required String success,required String auditAction})async{try{await widget.saveSchedule(s);widget.log(auditAction,'${team.name} · ${s.graphName} · ${formatDate(s.date)}');widget.notifyTeam(team.id,'Grafic de lucru modificat','${s.graphName} · ${formatDate(s.date)} a fost actualizat.');if(mounted)showSuccessMessage(context,success);}catch(e){if(mounted)showErrorMessage(context,'Graficul nu a putut fi salvat: $e');}}
  Future<void> _applyGraphState({bool? started,bool? closed,bool? paused})async{final items=graphSchedules.map(_cloneSchedule).toList();for(final x in items){if(started!=null)x.started=started;if(closed!=null)x.closed=closed;if(paused!=null)x.paused=paused;await widget.saveSchedule(x);}widget.onChanged();}
  Future<Map<String,dynamic>?> _geocodeTripPoint(String query) async {
    final clean=query.trim();
    if(clean.isEmpty)return null;

    Map<String,dynamic>? parsePoint(Object? raw){
      if(raw is! Map)return null;
      final lat=double.tryParse((raw['lat']??'').toString());
      final lon=double.tryParse((raw['lon']??'').toString());
      if(lat==null||lon==null)return null;
      return {'name':(raw['name']??clean).toString(),'lat':lat,'lon':lon};
    }

    Future<Map<String,dynamic>?> viaServer() async {
      try{
        final token=await FirebaseAuth.instance.currentUser?.getIdToken();
        if(token==null||token.isEmpty)return null;
        final response=await http.post(
          Uri.parse(_geocodeRomaniaPlaceUrl),
          headers:{'Content-Type':'application/json','Authorization':'Bearer $token'},
          body:jsonEncode({'query':clean}),
        ).timeout(const Duration(seconds:12));
        if(response.statusCode!=200||response.body.isEmpty)return null;
        final decoded=jsonDecode(response.body);
        return parsePoint(decoded);
      }catch(e){debugPrint('[geocode] Server fallback: $e');return null;}
    }

    Future<Map<String,dynamic>?> viaNominatim(String value) async {
      try{
        final uri=Uri.https('nominatim.openstreetmap.org','/search',{
          'format':'jsonv2','q':value,'limit':'1','countrycodes':'ro','accept-language':'ro','addressdetails':'1'
        });
        final headers=<String,String>{'Accept':'application/json','Accept-Language':'ro'};
        if(!kIsWeb)headers['User-Agent']='AndiCarpeta/2.0.8 (internal operations app)';
        final response=await http.get(uri,headers:headers).timeout(const Duration(seconds:10));
        if(response.statusCode!=200||response.body.isEmpty)return null;
        final decoded=jsonDecode(response.body);
        if(decoded is! List||decoded.isEmpty)return null;
        return parsePoint(decoded.first);
      }catch(e){debugPrint('[geocode] Nominatim $value: $e');return null;}
    }

    // În browser cererea directă către Nominatim poate fi blocată/intermediată
    // diferit față de Android. Web folosește întâi proxy-ul nostru Firebase.
    if(kIsWeb){
      final server=await viaServer();
      if(server!=null)return server;
    }

    final candidates=<String>[clean];
    if(!clean.toLowerCase().contains('românia')&&!clean.toLowerCase().contains('romania'))candidates.add('$clean, România');
    for(final candidate in candidates){
      final direct=await viaNominatim(candidate);
      if(direct!=null)return direct;
    }

    if(!kIsWeb)return viaServer();
    return null;
  }

  Future<void> _startGraph()async{
    final head=graphHead;if(head==null)return;
    final departure=TextEditingController(text:head.departureName);
    final destination=TextEditingController(text:head.returnName);
    final choice=await showDialog<Map<String,String>>(context:context,barrierDismissible:false,builder:(c)=>AlertDialog(
      title:const Text('Pornește Graficul de lucru'),
      content:SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Alege punctul real de plecare și punctul în care se termină deplasarea. Acestea sunt folosite numai pentru traseu, kilometri și consum; nu apar în Centralizator.'),
        const SizedBox(height:14),
        TextField(controller:departure,decoration:const InputDecoration(labelText:'Plecare',hintText:'Ex: Brăila')),
        const SizedBox(height:10),
        TextField(controller:destination,decoration:const InputDecoration(labelText:'Întoarcere / destinație finală',hintText:'Ex: Brăila')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,{'departure':departure.text.trim(),'return':destination.text.trim()}),child:const Text('START'))],
    ));
    departure.dispose();destination.dispose();
    if(choice==null)return;
    final departureText=(choice['departure']??'').trim();final returnText=(choice['return']??'').trim();
    if(departureText.isEmpty||returnText.isEmpty){if(mounted)showErrorMessage(context,'Completează atât plecarea, cât și punctul final.');return;}
    if(mounted)showSuccessMessage(context,'Identific punctele de plecare și întoarcere…');
    final startPoint=await _geocodeTripPoint(departureText);
    final endPoint=departureText.toLowerCase()==returnText.toLowerCase()?startPoint:await _geocodeTripPoint(returnText);
    if(startPoint==null||endPoint==null){if(mounted)showErrorMessage(context,'Nu am putut identifica una dintre localități. Scrie localitatea mai explicit, de exemplu „Brăila, România”.');return;}
    final items=graphSchedules.map(_cloneSchedule).toList();
    for(final x in items){
      x.started=true;x.closed=false;x.paused=false;
      x.departureName=departureText;x.departureLatitude=startPoint['lat'] as double;x.departureLongitude=startPoint['lon'] as double;
      x.returnName=returnText;x.returnLatitude=endPoint['lat'] as double;x.returnLongitude=endPoint['lon'] as double;
      await widget.saveSchedule(x);
    }
    widget.onChanged();
    final km=estimateGraphDistanceKm(items,widget.locations);
    widget.log('Grafic pornit','${team.name} · ${head.graphName} · $departureText → $returnText · ${km.toStringAsFixed(1)} km estimați');
    if(mounted)showSuccessMessage(context,'Grafic pornit. Traseu complet: $departureText → săli → $returnText · ${km.toStringAsFixed(1)} km estimați.');
  }
  Future<void> _pauseGraph()async{await _applyGraphState(paused:true);widget.log('Grafic pus pe pauză','${team.name} · ${graphHead?.graphName??''}');if(mounted)showSuccessMessage(context,'Graficul a fost pus pe pauză.');}
  Future<void> _resumeGraph()async{await _applyGraphState(paused:false);widget.log('Grafic reluat','${team.name} · ${graphHead?.graphName??''}');if(mounted)showSuccessMessage(context,'Graficul a fost reluat.');}
  Future<void> _closeGraph()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('STOP Grafic de lucru'),content:const Text('Graficul complet va fi închis. Istoricul și Centralizatorul rămân păstrate.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('STOP'))]))??false;if(!ok)return;await _applyGraphState(closed:true,paused:false);widget.log('Grafic închis','${team.name} · ${graphHead?.graphName??''}');if(mounted)showSuccessMessage(context,'Graficul a fost închis.');}
  Future<void> _postponeGraph()async{
    if(graphSchedules.isEmpty)return;DateTime selected=graphSchedules.firstWhere((x)=>!x.date.isBefore(operationalWorkDate(DateTime.now())),orElse:()=>graphSchedules.first).date;
    final chosen=await showDialog<DateTime>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(title:const Text('Amână programul'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Alege ziua de la care vrei să deplasezi graficul cu +1 zi.'),const SizedBox(height:10),DropdownButtonFormField<DateTime>(value:selected,items:graphSchedules.map((x)=>DropdownMenuItem(value:x.date,child:Text(formatDate(x.date)))).toList(),onChanged:(v){if(v!=null)setD(()=>selected=v);})]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,selected),child:const Text('Amână cu 1 zi'))])));
    if(chosen==null)return;final affected=graphSchedules.where((x)=>!x.date.isBefore(DateTime(chosen.year,chosen.month,chosen.day))).map(_cloneSchedule).toList()..sort((a,b)=>b.date.compareTo(a.date));for(final x in affected){x.date=DateTime(x.date.year,x.date.month,x.date.day).add(const Duration(days:1));await widget.saveSchedule(x);}widget.log('Grafic amânat','${team.name} · de la ${formatDate(chosen)} · +1 zi');if(mounted)showSuccessMessage(context,'Graficul s-a actualizat în timp real: zilele au fost mutate cu +1 zi.');
  }
  Future<void> _removeItem(WorkSchedule s,ScheduleItem item)async{final updated=_cloneSchedule(s);updated.items.removeWhere((x)=>x.locationId==item.locationId&&x.order==item.order);for(int i=0;i<updated.items.length;i++)updated.items[i].order=i+1;await _saveWithFeedback(updated,success:'Locația a fost eliminată.',auditAction:'Locație eliminată din Grafic');}
  Future<void> _reorder(WorkSchedule s,int oldIndex,int newIndex)async{final updated=_cloneSchedule(s);if(newIndex>oldIndex)newIndex--;final item=updated.items.removeAt(oldIndex);updated.items.insert(newIndex,item);for(int i=0;i<updated.items.length;i++)updated.items[i].order=i+1;await _saveWithFeedback(updated,success:'Ordinea zilei a fost salvată.',auditAction:'Ordine Grafic modificată');unawaited(_recordRoutingChoice(updated,'manual_order'));}
  Future<List<Location>?> _locationDialog(List<String> already) async {
    final selected = already.toSet();
    return showDialog<List<Location>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) {
          final available = widget.locations.where((l) => l.selectableForProgram).toList();
          return AlertDialog(
            title: const Text('Alege locațiile'),
            content: SizedBox(
              width: 520,
              height: 500,
              child: ListView(
                children: available.map((l) => CheckboxListTile(
                  value: selected.contains(l.id),
                  secondary: categoryBrandWidget(l.categoryId, size: 28, fallbackColor: categoryColor(widget.categories, l.categoryId, fallbackType: l.type)),
                  title: Text(l.name),
                  subtitle: Text('${categoryName(widget.categories, l.categoryId, fallbackType: l.type)} · ${l.address}'),
                  onChanged: (v) => setD(() {
                    if (v == true) {
                      selected.add(l.id);
                    } else {
                      selected.remove(l.id);
                    }
                  }),
                )).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
              FilledButton(
                onPressed: () => Navigator.pop(c, available.where((l) => selected.contains(l.id)).toList()),
                child: const Text('Salvează'),
              ),
            ],
          );
        },
      ),
    );
  }


  Future<void> _navigateToItem(ScheduleItem item)async{final matches=widget.locations.where((l)=>l.id==item.locationId).toList();if(matches.isEmpty)return;await _openNavigation(matches.first);}
  Future<void> _openNavigation(Location l)async{
    final useGps=l.latitude!=null&&l.longitude!=null;
    final destination=useGps?'${l.latitude},${l.longitude}':l.address;
    final choice=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Wrap(children:[ListTile(leading:const Icon(Icons.map),title:const Text('Google Maps'),subtitle:Text(l.name),onTap:()=>Navigator.pop(c,'maps')),ListTile(leading:const Icon(Icons.navigation),title:const Text('Waze'),subtitle:Text(l.address),onTap:()=>Navigator.pop(c,'waze'))])));
    if(choice==null)return;
    final uri=choice=='maps'?Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}'):Uri.parse(useGps?'https://www.waze.com/ul?ll=${l.latitude},${l.longitude}&navigate=yes':'https://www.waze.com/ul?q=${Uri.encodeComponent(l.address)}&navigate=yes');
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)showErrorMessage(context,'Nu am putut deschide aplicația de navigație.');
  }
  Future<void> _openOmv()async{final uri=Uri.parse('https://www.omv.ro/ro/mobilitate/carburanti/localizare-statii-omv');if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)showErrorMessage(context,'Nu am putut deschide pagina OMV.');}
  Future<void> _exportPdf()async{if(graphSchedules.isEmpty)return;await downloadWorkGraphPdf(team:team,days:graphSchedules,locations:widget.locations,car:assignedCar);if(mounted)showSuccessMessage(context,'Graficul PDF a fost pregătit pentru descărcare.');}
  Future<void> _exportJpeg()async{
    try{await Future<void>.delayed(const Duration(milliseconds:80));final boundary=_graphCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;if(boundary==null)throw StateError('Previzualizarea nu este gata.');final image=await boundary.toImage(pixelRatio:1.0);final data=await image.toByteData(format:ui.ImageByteFormat.png);if(data==null)throw StateError('Nu s-a putut randă imaginea.');final decoded=img.decodeImage(data.buffer.asUint8List());if(decoded==null)throw StateError('Imagine invalidă.');final jpg=Uint8List.fromList(img.encodeJpg(decoded,quality:92));await downloadFile(jpg,'grafic_${_safeFilePart(graphHead?.graphName??'grafic')}.jpg',mimeType:'image/jpeg');if(mounted)showSuccessMessage(context,'Graficul JPEG a fost pregătit pentru descărcare.');}catch(e){if(mounted)showErrorMessage(context,'Exportul JPEG a eșuat: $e');}
  }
}

class _StatMini extends StatelessWidget{
  final String label;final String value;final IconData icon;const _StatMini({required this.label,required this.value,required this.icon});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha:.7),borderRadius:BorderRadius.circular(12)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:18),const SizedBox(width:7),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:Theme.of(context).textTheme.labelSmall),Text(value,style:const TextStyle(fontWeight:FontWeight.w800))])])) ;
}

class _MapStatusLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MapStatusLegend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}


class _VerifiedLocationFix {
  final String id;
  final double? latitude;
  final double? longitude;
  final LocationStatus? status;
  final String verifiedAddress;
  final String source = 'Google Maps / verificare web';
  final String confidence;
  final String note;
  const _VerifiedLocationFix({
    required this.id,
    this.latitude,
    this.longitude,
    this.status,
    required this.verifiedAddress,
    this.confidence = 'ridicată',
    this.note = '',
  });

  bool get hasGps => latitude != null && longitude != null;
}

// Puncte verificate pentru import controlat. Importul NU mută niciodată un marker
// care are deja coordonate în Firestore. Locațiile neclare rămân în lista
// „Neașezate pe hartă”, pentru verificare manuală.
const List<_VerifiedLocationFix> _verifiedLocationFixes = <_VerifiedLocationFix>[
  _VerifiedLocationFix(id:'million10', latitude:45.1638029, longitude:26.8170091, status:LocationStatus.open, verifiedAddress:'Bulevardul Unirii 232, Buzău'),
  _VerifiedLocationFix(id:'million12', latitude:44.31286, longitude:23.82998, status:LocationStatus.open, verifiedAddress:'Calea București 80, Craiova', confidence:'adresă exactă'),
  _VerifiedLocationFix(id:'million14', latitude:44.3175, longitude:23.7927, status:LocationStatus.open, verifiedAddress:'Strada Ion Maiorescu 3, Craiova'),
  _VerifiedLocationFix(id:'million15', latitude:44.328, longitude:23.813, status:LocationStatus.open, verifiedAddress:'Bulevardul Dacia / Piața Gării, Craiova', confidence:'adresă exactă'),
  _VerifiedLocationFix(id:'million16', latitude:44.33663, longitude:23.77756, status:LocationStatus.open, verifiedAddress:'Bulevardul George Enescu 76, Craiova'),
  _VerifiedLocationFix(id:'million17', status:LocationStatus.open, verifiedAddress:'Bulevardul Oltenia 50, Craiova'),
  _VerifiedLocationFix(id:'million18', status:LocationStatus.open, verifiedAddress:'Bulevardul Henri Coandă 59A, Craiova'),
  _VerifiedLocationFix(id:'million20', status:LocationStatus.open, verifiedAddress:'Brazda lui Novac / Strada Lămâiței, Craiova'),
  _VerifiedLocationFix(id:'million21', status:LocationStatus.open, verifiedAddress:'Bulevardul 1 Mai, Craiova'),
  _VerifiedLocationFix(id:'million23', status:LocationStatus.open, verifiedAddress:'Bulevardul 1 Decembrie 1918, Constanța', confidence:'locație verificată; număr neclar'),
  _VerifiedLocationFix(id:'million24', latitude:44.20162, longitude:28.62783, status:LocationStatus.open, verifiedAddress:'Strada Soveja 66A, Constanța'),
  _VerifiedLocationFix(id:'million25', latitude:44.2132, longitude:28.60471, status:LocationStatus.open, verifiedAddress:'Bulevardul Tomis 391, Constanța'),
  _VerifiedLocationFix(id:'million26', latitude:44.17632, longitude:28.61381, status:LocationStatus.temporarilyClosed, verifiedAddress:'Strada Dezrobirii 143, Constanța'),
  _VerifiedLocationFix(id:'million27', status:LocationStatus.temporarilyClosed, verifiedAddress:'Strada Constanței 17, Năvodari'),
  _VerifiedLocationFix(id:'million28', latitude:45.7034, longitude:27.2059, status:LocationStatus.open, verifiedAddress:'Calea Moldovei 32, Focșani'),
  _VerifiedLocationFix(id:'million29', latitude:45.68829, longitude:27.19558, status:LocationStatus.open, verifiedAddress:'Bulevardul Brăilei 102, Focșani'),
  _VerifiedLocationFix(id:'million30', status:LocationStatus.temporarilyClosed, verifiedAddress:'Bulevardul Unirii 14, Focșani', note:'Google indică locația închisă temporar; spațiul apare și oferit spre închiriere.'),
  _VerifiedLocationFix(id:'million31', latitude:45.698813, longitude:27.182494, status:LocationStatus.open, verifiedAddress:'Bulevardul Unirii 65, Focșani'),
  _VerifiedLocationFix(id:'million32', latitude:47.1593, longitude:27.5888, status:LocationStatus.temporarilyClosed, verifiedAddress:'Bulevardul Anastasie Panu 31, Iași'),
  _VerifiedLocationFix(id:'million33', status:LocationStatus.open, verifiedAddress:'Iulius Mall, Bulevardul Tudor Vladimirescu, Iași', note:'Million Luxury Games verificat activ.'),
  _VerifiedLocationFix(id:'million34', latitude:47.08, longitude:21.91953, status:LocationStatus.open, verifiedAddress:'Strada Transilvaniei 24, Oradea', confidence:'adresă exactă; listarea Million apare la nr. 23'),
  _VerifiedLocationFix(id:'million35', latitude:44.8543623, longitude:24.8793545, status:LocationStatus.open, verifiedAddress:'Strada Maior Gheorghe Șonțu, bloc D2, Pitești'),
  _VerifiedLocationFix(id:'million36', latitude:44.9414298, longitude:26.0211386, status:LocationStatus.open, verifiedAddress:'Bulevardul Republicii 17-25, Ploiești'),
  _VerifiedLocationFix(id:'million37', latitude:44.95308, longitude:26.0008193, status:LocationStatus.open, verifiedAddress:'Șoseaua Nordului 1A, Ploiești'),
  _VerifiedLocationFix(id:'million38', latitude:45.10254, longitude:24.36461, status:LocationStatus.open, verifiedAddress:'Strada Regina Maria 4, Râmnicu Vâlcea'),
  _VerifiedLocationFix(id:'million39', latitude:45.1145883, longitude:24.3639193, status:LocationStatus.open, verifiedAddress:'Strada Matei Basarab 1, Râmnicu Vâlcea'),
  _VerifiedLocationFix(id:'million40', latitude:45.09482, longitude:24.37253, status:LocationStatus.open, verifiedAddress:'Strada Tineretului 6, Râmnicu Vâlcea'),
  _VerifiedLocationFix(id:'million41', latitude:45.1172197, longitude:24.368524, status:LocationStatus.open, verifiedAddress:'Strada Rapsodiei 19, Râmnicu Vâlcea'),
  _VerifiedLocationFix(id:'million42', status:LocationStatus.open, verifiedAddress:'Piața 1 Decembrie 1918 25, Sighetu Marmației'),
  _VerifiedLocationFix(id:'million43', latitude:47.9255822, longitude:23.8791908, status:LocationStatus.temporarilyClosed, verifiedAddress:'Strada Cuza Vodă 1, Sighetu Marmației'),
  _VerifiedLocationFix(id:'million44', status:LocationStatus.open, verifiedAddress:'Bulevardul Matei Basarab, bloc K1, Slobozia'),
  _VerifiedLocationFix(id:'million45', latitude:45.776474, longitude:24.170716, status:LocationStatus.open, verifiedAddress:'Shopping City Sibiu, Șelimbăr'),
  _VerifiedLocationFix(id:'million46', latitude:45.79736, longitude:24.16200, status:LocationStatus.open, verifiedAddress:'Promenada Sibiu, Strada Lector 1-3A'),
  _VerifiedLocationFix(id:'million47', status:LocationStatus.temporarilyClosed, verifiedAddress:'Strada Alexandru Ioan Cuza 2, Satu Mare'),
  _VerifiedLocationFix(id:'million48', latitude:47.78610, longitude:22.87159, status:LocationStatus.open, verifiedAddress:'Strada Careiului 17, Satu Mare'),
  _VerifiedLocationFix(id:'million49', latitude:47.780055, longitude:22.892268, status:LocationStatus.temporarilyClosed, verifiedAddress:'Bulevardul Independenței 53, Satu Mare'),
  _VerifiedLocationFix(id:'million51', latitude:45.038924, longitude:23.270593, status:LocationStatus.open, verifiedAddress:'Strada Eroilor 6, Târgu Jiu'),
  _VerifiedLocationFix(id:'million52', status:LocationStatus.open, verifiedAddress:'Bulevardul 9 Mai, Târgu Jiu'),
  _VerifiedLocationFix(id:'million53', latitude:44.931007, longitude:25.4493501, status:LocationStatus.open, verifiedAddress:'Bulevardul Constantin Brâncoveanu 58, Târgoviște'),
  _VerifiedLocationFix(id:'million54', latitude:44.9248131, longitude:25.4648334, status:LocationStatus.open, verifiedAddress:'Bulevardul Independenței, bloc O2 / Nicolae Radian, Târgoviște'),
  _VerifiedLocationFix(id:'million55', latitude:44.91158, longitude:25.46367, status:LocationStatus.open, verifiedAddress:'Dâmbovița Mall, Târgoviște'),
  _VerifiedLocationFix(id:'million57', latitude:45.7592393, longitude:21.2285323, status:LocationStatus.temporarilyClosed, verifiedAddress:'Piața Mărăști 1-2, Timișoara'),
  _VerifiedLocationFix(id:'million58', latitude:44.4236549, longitude:26.1205466, status:LocationStatus.open, verifiedAddress:'Bulevardul Octavian Goga 24, București'),
  _VerifiedLocationFix(id:'million59', latitude:44.430728, longitude:26.13694, status:LocationStatus.open, verifiedAddress:'Bulevardul Decebal 24, București'),
  _VerifiedLocationFix(id:'million60', latitude:44.4522606, longitude:26.0476901, status:LocationStatus.temporarilyClosed, verifiedAddress:'Calea Crângași 29, București'),
  _VerifiedLocationFix(id:'million61', latitude:44.3943271, longitude:26.1096891, status:LocationStatus.temporarilyClosed, verifiedAddress:'Bulevardul Constantin Brâncoveanu 10, București'),
  _VerifiedLocationFix(id:'million62', status:LocationStatus.temporarilyClosed, verifiedAddress:'Calea 13 Septembrie 117, București'),
  _VerifiedLocationFix(id:'million63', latitude:44.4272246, longitude:24.3711113, status:LocationStatus.temporarilyClosed, verifiedAddress:'Bulevardul Alexandru Ioan Cuza 11, Slatina'),
  _VerifiedLocationFix(id:'million65', latitude:45.80860, longitude:24.14621, verifiedAddress:'Strada Lungă 65, Sibiu', confidence:'adresă exactă; status neverificat'),
  _VerifiedLocationFix(id:'million67', latitude:44.93908, longitude:26.02673, verifiedAddress:'Piața Victoriei 9, Ploiești', confidence:'adresă exactă; status neverificat'),
];

class MapPage extends StatefulWidget {
  final AppUser currentUser;
  final List<AppUser> users;
  final List<Team> teams;
  final List<WorkSchedule> schedules;
  final List<CentralizerRecord> records;
  final List<Location> locations;
  final List<LocationCategory> categories;
  final bool isAdmin;
  final Set<String> hiddenUserIds;
  final VoidCallback onChanged;
  final void Function(String, String) log;
  final Future<void> Function(Location) saveLocation;
  const MapPage({
    super.key,
    required this.currentUser,
    required this.users,
    required this.teams,
    required this.schedules,
    required this.records,
    required this.locations,
    required this.categories,
    required this.isAdmin,
    required this.hiddenUserIds,
    required this.onChanged,
    required this.log,
    required this.saveLocation,
  });
  @override State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  Position? _myPosition;
  String? _gpsError;
  bool _locating = false;
  bool saving = false;
  bool findingAddress = false;
  String? selectedLocationId;
  final Set<String> _selectedCategoryIds = <String>{};
  final Set<LocationStatus> _selectedStatuses = <LocationStatus>{...LocationStatus.values};
  bool _showGraphRoute = true;
  String? _routeGraphId;
  String? _roadGeometryKey;
  Future<List<List<double>>?>? _roadGeometryFuture;
  DateTime? _roadGeometryRequestedAt;

  Future<List<List<double>>?> _loadRoadGeometry(List<LatLng> points) {
    final key = points.map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}').join('|');
    final stale = _roadGeometryRequestedAt == null ||
        DateTime.now().difference(_roadGeometryRequestedAt!) > const Duration(minutes: 5);
    if (_roadGeometryKey != key || _roadGeometryFuture == null || stale) {
      _roadGeometryKey = key;
      _roadGeometryRequestedAt = DateTime.now();
      _roadGeometryFuture = _mapboxServices.drivingGeometry(
        points.map((p) => <double>[p.latitude, p.longitude]).toList(),
      );
    }
    return _roadGeometryFuture!;
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds.addAll(widget.categories.where((c) => c.active).map((c) => c.id));
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  List<LocationCategory> get visibleCategories {
    final list = widget.categories.where((c) => c.active).toList();
    list.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<String?> _reverseGeocodePoint(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toStringAsFixed(7),
        'lon': point.longitude.toStringAsFixed(7),
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'ro',
      });
      final headers = <String,String>{'Accept': 'application/json', 'Accept-Language': 'ro'};
      if (!kIsWeb) headers['User-Agent'] = 'AndiCarpeta/1.5.1 (internal operations app)';
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.body.isEmpty) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final address = decoded['address'];
      if (address is Map) {
        String first(List<String> keys) {
          for (final key in keys) {
            final value = address[key]?.toString().trim() ?? '';
            if (value.isNotEmpty) return value;
          }
          return '';
        }
        final road = first(['road','pedestrian','residential','footway','path']);
        final number = first(['house_number']);
        final locality = first(['city','town','municipality','village','suburb']);
        final county = first(['county']);
        final parts = <String>[];
        final street = [road, number].where((x) => x.isNotEmpty).join(' ');
        if (street.isNotEmpty) parts.add(street);
        if (locality.isNotEmpty && !parts.contains(locality)) parts.add(locality);
        if (county.isNotEmpty && county != locality) parts.add(county);
        if (parts.isNotEmpty) return parts.join(', ');
      }
      final display = decoded['display_name']?.toString().trim() ?? '';
      return display.isEmpty ? null : display;
    } catch (_) {
      return null;
    }
  }

  Color _color(Location l) => categoryColor(widget.categories, l.categoryId, fallbackType: l.type);
  String _categoryName(Location l) => categoryName(widget.categories, l.categoryId, fallbackType: l.type);

  // Include graficele închise în ziua de lucru: markerul rămâne verde
  // după închiderea graficului, nu dispare din hartă.
  List<WorkSchedule> get _todayOperationalSchedules {
    final workDate = operationalWorkDate(DateTime.now());
    final teamId = widget.currentUser.teamId;
    return widget.schedules.where((s) =>
      s.started && sameDay(s.date, workDate) &&
      (widget.isAdmin || (teamId != null && s.teamId == teamId))
    ).toList();
  }

  List<CentralizerRecord> _todayRecordsFor(String locationId, String teamId) {
    final workDate = operationalWorkDate(DateTime.now());
    return widget.records.where((r) =>
      r.teamId == teamId && r.locationId == locationId &&
      recordBelongsToWorkDate(r, workDate)
    ).toList();
  }

  Color? _workBadgeColor(Location l) {
    final schedules = _todayOperationalSchedules;
    if (schedules.isEmpty) return null;
    var assignments = 0;
    var finishedAssignments = 0;
    var nextOrRunning = false;
    for (final day in schedules) {
      final ordered = [...day.items]..sort((a, b) => a.order.compareTo(b.order));
      ScheduleItem? nextItem;
      for (final item in ordered) {
        final records = _todayRecordsFor(item.locationId, day.teamId);
        final done = records.any((r) => r.completed);
        final running = records.any((r) =>
          r.status == WorkAttemptStatus.running ||
          r.status == WorkAttemptStatus.waitingAccess);
        final cancelled = records.isNotEmpty && records.every((r) =>
          r.status == WorkAttemptStatus.refused ||
          r.status == WorkAttemptStatus.notCompleted);
        if (item.locationId == l.id) {
          assignments++;
          if (done) finishedAssignments++;
          if (!done && running) nextOrRunning = true;
        }
        if (nextItem == null && !done && !cancelled) nextItem = item;
      }
      if (nextItem?.locationId == l.id) nextOrRunning = true;
    }
    if (assignments == 0) return null;
    // Nu afișăm verde dacă aceeași locație mai are o intervenție restantă.
    if (finishedAssignments == assignments) return Colors.green;
    if (nextOrRunning) return Colors.orange;
    return Colors.red;
  }

  String _workBadgeText(Location l) {
    final color = _workBadgeColor(l);
    if (color == Colors.green) return ' · făcută';
    if (color == Colors.orange) return ' · urmează / în lucru';
    if (color == Colors.red) return ' · nefăcută';
    return '';
  }

  Widget _locationMarkerIcon(Location l) {
    final badge = _workBadgeColor(l);
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Opacity(
        opacity: l.status == LocationStatus.open ? 1 : .62,
        child: DecoratedBox(
          decoration: BoxDecoration(color: _color(l), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)]),
          child: SizedBox(width: 40, height: 40, child: Icon(l.status == LocationStatus.open ? Icons.location_on : l.status.icon, color: Colors.white)),
        ),
      ),
      if (badge != null)
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(color: badge, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          ),
        ),
    ]);
  }

  List<String> get _activeRouteGraphIds {
    final teamId = widget.currentUser.teamId;
    final active = widget.schedules.where((s) => s.started && !s.closed && (teamId == null || s.teamId == teamId)).toList();
    final ids = <String>[];
    for (final s in active) { if (!ids.contains(s.graphId)) ids.add(s.graphId); }
    return ids;
  }

  List<WorkSchedule> get _routeDays {
    final ids = _activeRouteGraphIds;
    if (ids.isEmpty) return <WorkSchedule>[];
    final id = (_routeGraphId != null && ids.contains(_routeGraphId)) ? _routeGraphId! : ids.first;
    return widget.schedules.where((s) => s.graphId == id && s.started && !s.closed).toList()..sort((a,b)=>a.date.compareTo(b.date));
  }

  List<Polyline> _rainbowRouteLines() {
    if (!_showGraphRoute) return const <Polyline>[];
    const colors = <Color>[Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.blue, Colors.indigo, Colors.purple];
    final route = graphRoutePoints(_routeDays, widget.locations);
    // Nu desenăm segmente false peste locațiile fără GPS.
    if (!route.complete) return const <Polyline>[];
    final lines = <Polyline>[];
    for (var i = 1; i < route.points.length; i++) {
      lines.add(Polyline(points: [route.points[i - 1], route.points[i]],
          color: colors[(i - 1) % colors.length], strokeWidth: 6));
    }
    return lines;
  }

  List<Marker> _routeEndpointMarkers() {
    if(!_showGraphRoute||_routeDays.isEmpty)return const <Marker>[];
    final head=_routeDays.first;
    final markers=<Marker>[];
    if(head.departureLatitude!=null&&head.departureLongitude!=null){
      markers.add(Marker(point:LatLng(head.departureLatitude!,head.departureLongitude!),width:54,height:54,child:Tooltip(message:'Plecare · ${head.departureName}',child:const DecoratedBox(decoration:BoxDecoration(color:Colors.teal,shape:BoxShape.circle),child:Icon(Icons.trip_origin,color:Colors.white,size:30)))));
    }
    if(head.returnLatitude!=null&&head.returnLongitude!=null){
      markers.add(Marker(point:LatLng(head.returnLatitude!,head.returnLongitude!),width:54,height:54,child:Tooltip(message:'Întoarcere · ${head.returnName}',child:const DecoratedBox(decoration:BoxDecoration(color:Colors.deepOrange,shape:BoxShape.circle),child:Icon(Icons.flag,color:Colors.white,size:28)))));
    }
    return markers;
  }

  Future<void> _startLocationTracking() async {
    if (_locating) return;
    setState(() { _locating = true; _gpsError = null; });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _gpsError = 'Serviciile de localizare sunt oprite pe dispozitiv.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsError = permission == LocationPermission.deniedForever
            ? 'Permisiunea de localizare este blocată. Activeaz-o din setările browserului/dispozitivului.'
            : 'Permisiunea de localizare nu a fost acordată.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() => _myPosition = p);
      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((position) {
        if (mounted) setState(() => _myPosition = position);
      }, onError: (Object e) {
        if (mounted) setState(() => _gpsError = 'GPS: $e');
      });
    } catch (e) {
      if (mounted) setState(() => _gpsError = 'Nu am putut citi locația: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _centerOnMe() {
    final p = _myPosition;
    if (p == null) {
      unawaited(_startLocationTracking());
      return;
    }
    mapController.move(LatLng(p.latitude, p.longitude), 17);
  }

  Location? _locationForVerifiedFix(_VerifiedLocationFix fix) {
    for (final l in widget.locations) {
      if (l.id == fix.id) return l;
    }
    return null;
  }

  Future<void> _showVerifiedImportPreview() async {
    if (!widget.isAdmin || saving) return;
    final gpsCandidates = <MapEntry<Location, _VerifiedLocationFix>>[];
    final statusCandidates = <MapEntry<Location, _VerifiedLocationFix>>[];
    final verifiedButNoGps = <MapEntry<Location, _VerifiedLocationFix>>[];
    for (final fix in _verifiedLocationFixes) {
      final l = _locationForVerifiedFix(fix);
      if (l == null) continue;
      if ((l.latitude == null || l.longitude == null) && fix.hasGps) {
        gpsCandidates.add(MapEntry(l, fix));
      }
      if (fix.status != null && l.status != fix.status) {
        statusCandidates.add(MapEntry(l, fix));
      }
      if ((l.latitude == null || l.longitude == null) && !fix.hasGps) {
        verifiedButNoGps.add(MapEntry(l, fix));
      }
    }
    final fixById = {for (final x in _verifiedLocationFixes) x.id: x};
    final unresolved = widget.locations.where((l) =>
      (l.latitude == null || l.longitude == null) && !(fixById[l.id]?.hasGps ?? false)
    ).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final changedIds = <String>{...gpsCandidates.map((e)=>e.key.id), ...statusCandidates.map((e)=>e.key.id)};
    final apply = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(children:[Icon(Icons.fact_check_outlined),SizedBox(width:10),Expanded(child:Text('Verificare GPS și status'))]),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .86 : 680,
          height: MediaQuery.sizeOf(context).height * .68,
          child: ListView(children:[
            const Text('Previzualizare înainte de import. Coordonatele existente NU sunt mutate sau suprascrise.', style: TextStyle(fontWeight:FontWeight.w700)),
            const SizedBox(height:12),
            Wrap(spacing:8,runSpacing:8,children:[
              Chip(avatar:const Icon(Icons.add_location_alt_outlined,size:18),label:Text('${gpsCandidates.length} GPS de completat')),
              Chip(avatar:const Icon(Icons.sync_alt,size:18),label:Text('${statusCandidates.length} statusuri de schimbat')),
              Chip(avatar:const Icon(Icons.gps_off,size:18),label:Text('${unresolved.length} rămân fără GPS')),
            ]),
            const SizedBox(height:12),
            if (gpsCandidates.isNotEmpty) ...[
              const Text('Coordonate care vor fi completate',style:TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              ...gpsCandidates.map((e)=>ListTile(
                dense:true,contentPadding:EdgeInsets.zero,
                leading:const Icon(Icons.add_location_alt,color:Colors.green),
                title:Text(e.key.name),
                subtitle:Text('${e.value.verifiedAddress}\n${e.value.latitude!.toStringAsFixed(6)}, ${e.value.longitude!.toStringAsFixed(6)} · ${e.value.confidence}'),
                isThreeLine:true,
              )),
            ],
            if (statusCandidates.isNotEmpty) ...[
              const Divider(),
              const Text('Statusuri care vor fi actualizate',style:TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:6),
              ...statusCandidates.map((e)=>ListTile(
                dense:true,contentPadding:EdgeInsets.zero,
                leading:Icon(e.value.status!.icon,color:e.value.status!.color),
                title:Text(e.key.name),
                subtitle:Text('${e.key.status.label} → ${e.value.status!.label}\n${e.value.verifiedAddress}${e.value.note.isEmpty?'':' · ${e.value.note}'}'),
                isThreeLine:true,
              )),
            ],
            if (verifiedButNoGps.isNotEmpty) ...[
              const Divider(),
              const Text('Verificate, dar fără punct GPS suficient de sigur',style:TextStyle(fontWeight:FontWeight.bold)),
              ...verifiedButNoGps.map((e)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.manage_search,color:Colors.orange),title:Text(e.key.name),subtitle:Text(e.value.verifiedAddress))),
            ],
            if (unresolved.isNotEmpty) ...[
              const Divider(),
              ExpansionTile(
                tilePadding:EdgeInsets.zero,
                title:Text('Necesită verificare manuală (${unresolved.length})',style:const TextStyle(fontWeight:FontWeight.bold)),
                subtitle:const Text('Nu inventăm coordonate. Aceste locații rămân în „Neașezate pe hartă”.'),
                children:unresolved.map((l)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:categoryBrandWidget(l.categoryId,size:26,fallbackColor:_color(l)),title:Text(l.name),subtitle:Text(l.address))).toList(),
              ),
            ],
          ]),
        ),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Renunță')),
          FilledButton.icon(onPressed:changedIds.isEmpty?null:()=>Navigator.pop(c,true),icon:const Icon(Icons.cloud_upload_outlined),label:Text('Aplică ${changedIds.length} locații')),
        ],
      ),
    );
    if (apply == true && mounted) await _applyVerifiedImport();
  }

  Future<void> _applyVerifiedImport() async {
    if (!widget.isAdmin || saving) return;
    setState(() => saving = true);
    var gpsCount = 0;
    var statusCount = 0;
    var touched = 0;
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      for (final fix in _verifiedLocationFixes) {
        final l = _locationForVerifiedFix(fix);
        if (l == null) continue;
        final update = <String,dynamic>{};
        var changed = false;
        if ((l.latitude == null || l.longitude == null) && fix.hasGps) {
          l.latitude = fix.latitude;
          l.longitude = fix.longitude;
          update['latitude'] = fix.latitude;
          update['longitude'] = fix.longitude;
          gpsCount++;
          changed = true;
        }
        if (fix.status != null && l.status != fix.status) {
          l.status = fix.status!;
          update['status'] = fix.status!.name;
          statusCount++;
          changed = true;
        }
        if (!changed) continue;
        update['locationVerifiedAt'] = FieldValue.serverTimestamp();
        update['verificationSource'] = fix.source;
        update['verificationConfidence'] = fix.confidence;
        update['verifiedAddress'] = fix.verifiedAddress;
        if (fix.note.isNotEmpty) update['verificationNote'] = fix.note;
        batch.set(firestore.collection('locations').doc(l.id), update, SetOptions(merge:true));
        touched++;
      }
      if (touched > 0) await batch.commit();
      if (!mounted) return;
      widget.log('Import GPS verificat', '$touched locații · $gpsCount GPS · $statusCount statusuri');
      widget.onChanged();
      setState(() {});
      showSuccessMessage(context, touched == 0
          ? 'Nu există modificări noi de aplicat.'
          : 'Import finalizat: $gpsCount coordonate GPS și $statusCount statusuri actualizate. Coordonatele existente au rămas neschimbate.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Importul GPS nu a putut fi finalizat: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positioned = widget.locations.where((l) =>
      l.latitude != null && l.longitude != null &&
      _selectedCategoryIds.contains(l.categoryId) &&
      _selectedStatuses.contains(l.status)
    ).toList();
    final unpositioned = widget.locations.where((l) =>
      (l.latitude == null || l.longitude == null) &&
      _selectedCategoryIds.contains(l.categoryId) &&
      _selectedStatuses.contains(l.status)
    ).length;
    final compact = MediaQuery.sizeOf(context).width < 650;
    return _Page(
      title: 'Hartă',
      subtitle: 'Vizualizare și poziționare. Editarea datelor se face din Admin → Locații.',
      actions: [
        IconButton(tooltip: 'Centrează pe mine', onPressed: _locating ? null : _centerOnMe, icon: const Icon(Icons.my_location)),
        if (widget.isAdmin) OutlinedButton.icon(onPressed: saving ? null : _showVerifiedImportPreview, icon: const Icon(Icons.fact_check_outlined), label: Text(compact ? 'Verificare GPS' : 'Import GPS verificat')),
        if (widget.isAdmin) FilledButton.icon(onPressed: (saving || findingAddress) ? null : () => _add(), icon: const Icon(Icons.add_location_alt), label: Text(compact ? 'Adaugă' : 'Adaugă locație')),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_gpsError != null) _InfoCard(icon: Icons.location_disabled_outlined, title: 'Locația mea', text: _gpsError!),
        if (_myPosition != null) _InfoCard(
          icon: Icons.gps_fixed,
          title: 'Locația mea este activă',
          text: 'Precizie aproximativă: ${_myPosition!.accuracy.toStringAsFixed(0)} m. Apasă markerul albastru de pe hartă pentru a memora o locație nouă aici.',
        ),
        if (saving || findingAddress) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text(findingAddress ? 'Caut adresa exactă pentru punctul ales pe hartă...' : 'Se salvează în Firestore...'),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Categorii:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...visibleCategories.map((cat) => FilterChip(
            selected: _selectedCategoryIds.contains(cat.id),
            avatar: categoryBrandWidget(cat.id, size: 22, fallbackColor: cat.color),
            label: Text(cat.name),
            onSelected: (v) => setState(() { if (v) { _selectedCategoryIds.add(cat.id); } else { _selectedCategoryIds.remove(cat.id); } }),
          )),
          TextButton(onPressed: () => setState(() { _selectedCategoryIds..clear()..addAll(visibleCategories.map((e)=>e.id)); }), child: const Text('Toate')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...LocationStatus.values.map((status) => FilterChip(
            selected: _selectedStatuses.contains(status),
            avatar: Icon(status.icon, size: 18, color: status.color),
            label: Text(status.label),
            onSelected: (v) => setState(() { if (v) { _selectedStatuses.add(status); } else { _selectedStatuses.remove(status); } }),
          )),
          TextButton(onPressed: () => setState(() { _selectedStatuses..clear()..addAll(LocationStatus.values); }), child: const Text('Toate statusurile')),
        ]),
        if (_activeRouteGraphIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilterChip(selected: _showGraphRoute, avatar: const Icon(Icons.route, size: 18), label: const Text('Traseu rutier (Mapbox)'), onSelected: (v) => setState(() => _showGraphRoute = v)),
            if (_activeRouteGraphIds.length > 1) DropdownButton<String>(
              value: (_routeGraphId != null && _activeRouteGraphIds.contains(_routeGraphId)) ? _routeGraphId : _activeRouteGraphIds.first,
              items: _activeRouteGraphIds.map((id) { final h = widget.schedules.firstWhere((s)=>s.graphId==id); return DropdownMenuItem(value:id,child:Text(h.graphName)); }).toList(),
              onChanged: (v) => setState(() => _routeGraphId = v),
            ),
          ]),
        ],
        if (_todayOperationalSchedules.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Stare azi:', style: TextStyle(fontWeight: FontWeight.bold)),
            _MapStatusLegend(color: Colors.red, label: 'Nefăcută'),
            _MapStatusLegend(color: Colors.orange, label: 'Urmează / în lucru'),
            _MapStatusLegend(color: Colors.green, label: 'Făcută'),
          ]),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: compact ? 430 : 560,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: const LatLng(45.9432, 24.9668),
                initialZoom: 6.3,
                onTap: widget.isAdmin && !saving && !findingAddress ? (_, point) => _chooseLocationAt(point) : null,
              ),
              children: [
                TileLayer(urlTemplate: kMapTileUrl, userAgentPackageName: 'ro.andicarpeta.app'),
                if (_showGraphRoute && graphRoutePoints(_routeDays, widget.locations).complete &&
                    graphRoutePoints(_routeDays, widget.locations).points.length >= 2)
                  FutureBuilder<List<List<double>>?>(
                    future: _loadRoadGeometry(graphRoutePoints(_routeDays, widget.locations).points),
                    builder: (context, snapshot) {
                      final coords = snapshot.data;
                      if (coords == null || coords.length < 2) return const SizedBox.shrink();
                      return PolylineLayer(polylines: [
                        Polyline(
                          points: coords.map((p) => LatLng(p[0], p[1])).toList(),
                          color: Colors.deepOrangeAccent,
                          strokeWidth: 6,
                        ),
                      ]);
                    },
                  ),
                MarkerLayer(markers: [
                  ..._routeEndpointMarkers(),
                  ...positioned.map((l) => Marker(
                    point: LatLng(l.latitude!, l.longitude!), width: 46, height: 46,
                    child: Tooltip(
                      message: '${_categoryName(l)} · ${l.name} · ${l.status.label}${_workBadgeText(l)}',
                      child: GestureDetector(
                        onTap: () => _details(l),
                        child: _locationMarkerIcon(l),
                      ),
                    ),
                  )),
                  if (_myPosition != null) Marker(
                    point: LatLng(_myPosition!.latitude, _myPosition!.longitude), width: 62, height: 62,
                    child: Tooltip(
                      message: 'Locația mea',
                      child: GestureDetector(
                        onTap: _showMyLocationActions,
                        onLongPress: decodeProfilePhoto(widget.currentUser.photoBase64)==null?null:()=>showProfilePhotoViewer(context,widget.currentUser.photoBase64,widget.currentUser.name),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black38)]),
                          child: CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.blue,
                            backgroundImage: decodeProfilePhoto(widget.currentUser.photoBase64)==null?null:MemoryImage(decodeProfilePhoto(widget.currentUser.photoBase64)!),
                            child: decodeProfilePhoto(widget.currentUser.photoBase64)==null?const Icon(Icons.person_pin_circle,color:Colors.white,size:34):null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('liveLocations').snapshots(),
                  builder: (context, snap) {
                    final now = DateTime.now();
                    final markers = <Marker>[];
                    for (final doc in snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                      final d = doc.data();
                      final liveUserId = (d['userId'] ?? doc.id).toString();
                      if (!widget.isAdmin && widget.hiddenUserIds.contains(liveUserId)) continue;
                      final lat = d['latitude']; final lng = d['longitude'];
                      if (lat is! num || lng is! num) continue;
                      final updated = d['updatedAt'] is Timestamp ? (d['updatedAt'] as Timestamp).toDate() : null;
                      if (updated != null && now.difference(updated) > const Duration(hours: 24)) continue;
                      final name = (d['name'] ?? 'Membru').toString();
                      final mode = (d['mode'] ?? 'economic').toString();
                      AppUser? matchedUser; for (final u in widget.users) { if (u.id == liveUserId) { matchedUser = u; break; } }
                      final photoData = (d['photoBase64'] ?? matchedUser?.photoBase64 ?? '').toString();
                      final photo = decodeProfilePhoto(photoData);
                      markers.add(Marker(
                        point: LatLng(lat.toDouble(), lng.toDouble()),
                        width: 60,
                        height: 60,
                        child: Tooltip(
                          message: '$name · ${updated == null ? 'ora necunoscută' : 'actualizat ${timeText(updated)}'} · ${mode.startsWith('operational') ? 'mod operațional · ${mode.replaceFirst('operational-', '')}' : 'mod $mode'}',
                          child: GestureDetector(
                            onTap: photo == null ? null : () => showProfilePhotoViewer(context, photoData, name),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                              ),
                              child: CircleAvatar(
                                radius: 27,
                                backgroundColor: mode.startsWith('operational') ? Colors.green : Colors.indigo,
                                backgroundImage: photo == null ? null : MemoryImage(photo),
                                child: photo == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                              ),
                            ),
                          ),
                        ),
                      ));
                    }
                    return MarkerLayer(markers: markers);
                  },
                ),
                RichAttributionWidget(attributions: [TextSourceAttribution(kMapboxEnabled ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap contributors')]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (unpositioned > 0) _InfoCard(icon: Icons.gps_off, title: '$unpositioned locații neașezate pe hartă', text: widget.isAdmin ? 'Le găsești grupate imediat mai jos. Poți poziționa fiecare locație printr-un click pe hartă.' : 'Coordonatele pot fi completate de Admin.'),
        const SizedBox(height: 12),
        Text('Locații', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _unpositionedPanel(),
        ..._categoryPanels(),
      ]),
    );
  }

  Widget _unpositionedPanel() {
    final items = widget.locations.where((l) =>
      (l.latitude == null || l.longitude == null) &&
      _selectedCategoryIds.contains(l.categoryId) &&
      _selectedStatuses.contains(l.status)
    ).toList()..sort((a,b) {
      final cat = _categoryName(a).toLowerCase().compareTo(_categoryName(b).toLowerCase());
      return cat != 0 ? cat : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    if (items.isEmpty) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.gps_fixed)),
          title: const Text('Neașezate pe hartă', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Nu există locații fără coordonate pentru filtrele selectate.'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
        ),
      );
    }
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(backgroundColor: Colors.orange.withValues(alpha:.15), child: const Icon(Icons.gps_off, color: Colors.orange)),
        title: const Text('Neașezate pe hartă', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${items.length} locații fără poziție GPS'),
        children: items.map((l) => ListTile(
          onTap: () => _details(l),
          leading: categoryBrandWidget(l.categoryId, size: 34, fallbackColor: _color(l)),
          title: Text(l.name),
          subtitle: Text('${_categoryName(l)} · ${l.address}\n${l.status.label} · fără GPS'),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Navigație după adresă',
              onPressed: () => _navigationChoice(l),
              icon: const Icon(Icons.navigation_outlined),
            ),
            if (widget.isAdmin) IconButton(
              tooltip: 'Poziționează pe hartă',
              onPressed: () {
                setState(() => selectedLocationId = l.id);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dă click pe hartă pentru a poziționa ${l.name}.')));
              },
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          ]),
        )).toList(),
      ),
    );
  }

  List<Widget> _categoryPanels() {
    final cats = <LocationCategory>[...visibleCategories];
    final known = cats.map((c) => c.id).toSet();
    final unknownIds = widget.locations.map((l) => l.categoryId).where((id) => !known.contains(id)).toSet();
    for (final id in unknownIds) {
      cats.add(LocationCategory(id: id, name: categoryName(widget.categories, id), colorValue: categoryColor(widget.categories, id).value));
    }
    return cats.map((cat) {
      final items = widget.locations.where((l) =>
        l.categoryId == cat.id &&
        l.latitude != null && l.longitude != null &&
        _selectedCategoryIds.contains(cat.id) &&
        _selectedStatuses.contains(l.status)
      ).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (items.isEmpty) return const SizedBox.shrink();
      return Card(
        child: ExpansionTile(
          leading: categoryBrandWidget(cat.id, size: 34, fallbackColor: cat.color),
          title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${items.length} locații poziționate'),
          children: items.map((l) => ListTile(
            onTap: () => _details(l),
            leading: Icon(l.status == LocationStatus.open ? Icons.location_on : l.status.icon, color: l.status == LocationStatus.open ? cat.color : l.status.color),
            title: Text(l.name),
            subtitle: Text('${l.address}\n${l.status.label} · GPS salvat'),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Deschide navigația',
                onPressed: () => _navigationChoice(l),
                icon: const Icon(Icons.navigation_outlined),
              ),
              if (widget.isAdmin) IconButton(
                tooltip: 'Mută pe hartă',
                onPressed: () {
                  setState(() => selectedLocationId = l.id);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dă click pe hartă pentru a muta ${l.name}.')));
                },
                icon: const Icon(Icons.edit_location_alt_outlined),
              ),
            ]),
          )).toList(),
        ),
      );
    }).toList();
  }

  Future<void> _navigationChoice(Location l) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('Google Maps'),
          subtitle: Text(l.latitude != null && l.longitude != null ? 'Rutare către coordonatele GPS salvate' : 'Rutare după adresa salvată'),
          onTap: () => Navigator.pop(c, 'maps'),
        ),
        ListTile(
          leading: const Icon(Icons.navigation_outlined),
          title: const Text('Waze'),
          subtitle: Text(l.latitude != null && l.longitude != null ? 'Rutare către coordonatele GPS salvate' : 'Rutare după adresa salvată'),
          onTap: () => Navigator.pop(c, 'waze'),
        ),
      ])),
    );
    if (choice != null && mounted) await _openNavigationForLocation(l, choice);
  }

  Future<void> _showMyLocationActions() async {
    final p = _myPosition;
    if (p == null) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Locația mea', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)} · precizie ${p.accuracy.toStringAsFixed(0)} m'),
        const SizedBox(height: 14),
        if (widget.isAdmin) FilledButton.icon(
          onPressed: () { Navigator.pop(c); unawaited(_add(initialPoint: LatLng(p.latitude, p.longitude))); },
          icon: const Icon(Icons.add_location_alt), label: const Text('Adaugă locație aici'),
        ) else const Text('Doar Adminul poate adăuga locații în registru.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () { Navigator.pop(c); _centerOnMe(); }, icon: const Icon(Icons.center_focus_strong), label: const Text('Centrează harta aici')),
      ]),
    )));
  }

  Location _copyLocation(Location l, {double? latitude, double? longitude}) => Location(
    id: l.id, name: l.name, address: l.address, type: l.type, categoryId: l.categoryId, status: l.status,
    latitude: latitude ?? l.latitude, longitude: longitude ?? l.longitude, phone: l.phone,
    contacts: l.contacts.map((c) => LocationContact(name: c.name, phone: c.phone, role: c.role, smsEnabled: c.smsEnabled)).toList(),
    surfaceM2: l.surfaceM2, facadeM2: l.facadeM2, notes: l.notes, active: l.active,
  );

  // Validare înainte de orice modificare a markerelor persistate.
  bool _validMapPoint(LatLng point) =>
      point.latitude.isFinite && point.longitude.isFinite &&
      point.latitude >= -90 && point.latitude <= 90 &&
      point.longitude >= -180 && point.longitude <= 180 &&
      !(point.latitude == 0 && point.longitude == 0);

  void _invalidMapPointNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Punct GPS invalid. Alege o poziție reală pe hartă.'),
    ));
  }

  Future<void> _chooseLocationAt(LatLng point) async {
    if (!_validMapPoint(point)) { _invalidMapPointNotice(); return; }
    if (selectedLocationId != null) {
      final selected = widget.locations.where((x) => x.id == selectedLocationId).toList();
      selectedLocationId = null;
      if (selected.isNotEmpty) { await _confirmAndPlace(selected.first, point); return; }
    }
    final search = TextEditingController();
    String query = '';
    String? chosenId;
    final choice = await showDialog<Object>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialog) {
      final available = widget.locations.where((l) {
        final q = query.trim().toLowerCase();
        return q.isEmpty || l.name.toLowerCase().contains(q) || l.address.toLowerCase().contains(q) || _categoryName(l).toLowerCase().contains(q);
      }).toList()..sort((a,b) {
        final cat = _categoryName(a).compareTo(_categoryName(b));
        return cat != 0 ? cat : a.name.compareTo(b.name);
      });
      return AlertDialog(
        title: const Text('Ce locație se află aici?'),
        content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 620, height: MediaQuery.sizeOf(context).height * .62, child: Column(children: [
          Text('Punct: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
          const SizedBox(height: 10),
          TextField(controller: search, autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Caută locația'), onChanged: (v) => setDialog(() => query = v)),
          const SizedBox(height: 10),
          Expanded(child: available.isEmpty ? const Center(child: Text('Nu am găsit locația.')) : ListView.builder(itemCount: available.length, itemBuilder: (_, i) {
            final l = available[i];
            return RadioListTile<String>(
              value: l.id, groupValue: chosenId, onChanged: (v) => setDialog(() => chosenId = v),
              secondary: CircleAvatar(backgroundColor: _color(l), child: const Icon(Icons.location_on, color: Colors.white)),
              title: Text('${_categoryName(l)} · ${l.name}'),
              subtitle: Text('${l.address}${l.latitude != null ? ' · are GPS' : ''} · ${l.status.label}'),
            );
          })),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Anulează')),
          OutlinedButton.icon(onPressed: () => Navigator.pop(dialogContext, 'new'), icon: const Icon(Icons.add_location_alt), label: const Text('Adaugă locație nouă aici')),
          FilledButton(onPressed: chosenId == null ? null : () => Navigator.pop(dialogContext, widget.locations.firstWhere((x) => x.id == chosenId)), child: const Text('Salvează aici')),
        ],
      );
    }));
    search.dispose();
    if (choice == null) return;
    if (choice == 'new') { await _add(initialPoint: point); return; }
    await _confirmAndPlace(choice as Location, point);
  }

  Future<void> _confirmAndPlace(Location chosen, LatLng point) async {
    if (!_validMapPoint(point)) { _invalidMapPointNotice(); return; }
    if (chosen.latitude != null && chosen.longitude != null && mounted) {
      final replace = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Locația are deja coordonate'),
        content: Text('${chosen.name} este deja poziționată la ${chosen.latitude!.toStringAsFixed(6)}, ${chosen.longitude!.toStringAsFixed(6)}.\nNoua poziție: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}.\nMuți markerul?'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nu')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Da, mută'))],
      ));
      if (replace != true) return;
    }
    await _placeLocation(chosen, point);
  }

  Future<void> _placeLocation(Location source, LatLng point) async {
    if (!widget.isAdmin || saving || !_validMapPoint(point)) {
      _invalidMapPointNotice();
      return;
    }
    final updated = _copyLocation(source, latitude: point.latitude, longitude: point.longitude);
    setState(() => saving = true);
    try {
      await widget.saveLocation(updated);
      widget.log('Coordonate salvate din hartă', '${updated.name}: ${point.latitude}, ${point.longitude}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updated.name} a fost poziționată pe hartă.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Locația NU a fost salvată: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> _details(Location l) async {
    await showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: Row(children: [CircleAvatar(backgroundColor: _color(l), child: const Icon(Icons.location_on, color: Colors.white)), const SizedBox(width: 10), Expanded(child: Text(l.name))]),
      content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text(_categoryName(l)), avatar: categoryBrandWidget(l.categoryId, size: 22, fallbackColor: _color(l))), Chip(label: Text(l.status.label), avatar: Icon(l.status.icon, size: 17, color: l.status.color))]),
        const SizedBox(height: 8),
        Text(l.address, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (l.surfaceM2 > 0) Text('Mochetă / suprafață de lucru: ${l.surfaceM2.toStringAsFixed(0)} m²'),
        if (l.facadeM2 > 0) Text('Fațadă: ${l.facadeM2.toStringAsFixed(0)} m²'),
        if (l.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Notă: ${l.notes}')),
        const SizedBox(height: 14),
        const Text('Contacte', style: TextStyle(fontWeight: FontWeight.bold)),
        if (l.contacts.isEmpty) const Text('Nu există contact salvat.'),
        ...l.contacts.map((x) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_outline), title: Text(x.name), subtitle: Text(x.phone), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Trimite mesaj', onPressed: () async { final uri = Uri(scheme: 'sms', path: x.phone); if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) { await Clipboard.setData(ClipboardData(text: x.phone)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numărul a fost copiat: ${x.phone}'))); } }, icon: const Icon(Icons.message_outlined)),
          IconButton(tooltip: 'Copiază telefonul', onPressed: () async { await Clipboard.setData(ClipboardData(text: x.phone)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Telefon copiat: ${x.phone}'))); }, icon: const Icon(Icons.copy)),
        ]))),
        if (l.latitude != null && l.longitude != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('GPS: ${l.latitude!.toStringAsFixed(6)}, ${l.longitude!.toStringAsFixed(6)}')),
      ]))),
      actions: [
        if (widget.isAdmin && l.latitude != null && l.longitude != null)
          OutlinedButton.icon(
            onPressed: () { Navigator.pop(c); unawaited(_adjustLocation(l)); },
            icon: const Icon(Icons.open_with_rounded),
            label: const Text('Ajustează locația'),
          ),
        OutlinedButton.icon(onPressed: () { Navigator.pop(c); unawaited(_openNavigationForLocation(l, 'maps')); }, icon: const Icon(Icons.map_outlined), label: const Text('Maps')),
        OutlinedButton.icon(onPressed: () { Navigator.pop(c); unawaited(_openNavigationForLocation(l, 'waze')); }, icon: const Icon(Icons.navigation_outlined), label: const Text('Waze')),
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Închide')),
      ],
    ));
  }

  Future<void> _adjustLocation(Location l) async {
    final result = await Navigator.of(context).push<LatLng>(MaterialPageRoute(builder: (_) => LocationAdjustPage(location: l, color: _color(l))));
    if (result == null) return;
    final updated = _copyLocation(l, latitude: result.latitude, longitude: result.longitude);
    setState(() => saving = true);
    try {
      await widget.saveLocation(updated);
      widget.log('Locație ajustată pe hartă', updated.name);
      if (mounted) showSuccessMessage(context, 'Locația ${updated.name} a fost repoziționată pe hartă.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu am putut salva noua poziție: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openNavigationForLocation(Location l, String app) async {
    final useGps = l.latitude != null && l.longitude != null;
    final destination = useGps ? '${l.latitude},${l.longitude}' : l.address;
    final uri = app == 'maps'
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}')
        : Uri.parse(useGps ? 'https://www.waze.com/ul?ll=${l.latitude},${l.longitude}&navigate=yes' : 'https://www.waze.com/ul?q=${Uri.encodeComponent(l.address)}&navigate=yes');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) showErrorMessage(context, 'Nu am putut deschide navigația.');
  }

  Future<void> _add({LatLng? initialPoint}) async {
    String? initialAddress;
    if (initialPoint != null) {
      if (mounted) setState(() => findingAddress = true);
      initialAddress = await _reverseGeocodePoint(initialPoint);
      if (mounted) setState(() => findingAddress = false);
    }
    final r = await _newLocationForm(initialPoint: initialPoint, initialAddress: initialAddress);
    if (r == null) return;
    setState(() => saving = true);
    try {
      await widget.saveLocation(r);
      widget.log('Locație adăugată', r.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r.name} a fost adăugată și salvată.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Locația NU a fost adăugată: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<Location?> _newLocationForm({LatLng? initialPoint, String? initialAddress}) async {
    final formKey = GlobalKey<FormState>();
    final n = TextEditingController(), a = TextEditingController(text: initialAddress ?? ''), p = TextEditingController(), m = TextEditingController(), f = TextEditingController(), note = TextEditingController();
    String categoryId = visibleCategories.isNotEmpty ? visibleCategories.first.id : 'horeca';
    final result = await showDialog<Location>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('Locație nouă'),
      content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 560, child: Form(key: formKey, child: SingleChildScrollView(child: Column(children: [
        TextFormField(controller: n, decoration: const InputDecoration(labelText: 'Nume *'), validator: (v) => v == null || v.trim().isEmpty ? 'Numele este obligatoriu.' : null),
        const SizedBox(height: 8),
        TextFormField(
          controller: a,
          decoration: InputDecoration(
            labelText: 'Adresă *',
            helperText: initialPoint == null
                ? null
                : (initialAddress == null ? 'Adresa nu a putut fi identificată automat. O poți completa manual.' : 'Adresă preluată automat din punctul ales pe hartă.'),
            suffixIcon: initialPoint == null ? null : const Icon(Icons.location_searching),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Adresa este obligatorie.' : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: categoryId, decoration: const InputDecoration(labelText: 'Categorie'), items: visibleCategories.map((x) => DropdownMenuItem(value: x.id, child: Row(children: [categoryBrandWidget(x.id, size: 24, fallbackColor: x.color), const SizedBox(width: 8), Text(x.name)]))).toList(), onChanged: (v) { if (v != null) setD(() => categoryId = v); }),
        const SizedBox(height: 8),
        TextField(controller: p, decoration: const InputDecoration(labelText: 'Telefon principal')),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: TextFormField(controller: m, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Suprafață m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; })), const SizedBox(width: 8), Expanded(child: TextFormField(controller: f, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fațadă m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; }))]),
        const SizedBox(height: 8),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
        if (initialPoint != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('GPS preluat: ${initialPoint.latitude.toStringAsFixed(6)}, ${initialPoint.longitude.toStringAsFixed(6)}')),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')), FilledButton(onPressed: () {
        if (!(formKey.currentState?.validate() ?? false)) return;
        final phone = p.text.trim();
        Navigator.pop(c, Location(
          id: idNow(), name: n.text.trim(), address: a.text.trim(), type: legacyTypeForCategory(categoryId), categoryId: categoryId,
          latitude: initialPoint?.latitude, longitude: initialPoint?.longitude, phone: phone.isEmpty ? null : phone,
          contacts: phone.isEmpty ? <LocationContact>[] : <LocationContact>[LocationContact(name: 'Contact locație', phone: phone)],
          surfaceM2: double.tryParse(m.text.replaceAll(',', '.')) ?? 0, facadeM2: double.tryParse(f.text.replaceAll(',', '.')) ?? 0,
          notes: note.text.trim(), status: LocationStatus.open, active: true,
        ));
      }, child: const Text('Salvează'))],
    )));
    n.dispose(); a.dispose(); p.dispose(); m.dispose(); f.dispose(); note.dispose();
    return result;
  }
}


class LocationAdjustPage extends StatefulWidget {
  final Location location;
  final Color color;
  const LocationAdjustPage({super.key, required this.location, required this.color});

  @override
  State<LocationAdjustPage> createState() => _LocationAdjustPageState();
}

class _LocationAdjustPageState extends State<LocationAdjustPage> {
  late final MapController _controller;
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    _center = LatLng(widget.location.latitude ?? 45.9432, widget.location.longitude ?? 24.9668);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajustează · ${widget.location.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mută harta cu degetul până când pinul fix din centru ajunge exact pe locația corectă, apoi apasă Salvează.', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Coordonate curente: ${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}'),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 17,
                    onPositionChanged: (position, _) {
                      if (mounted) setState(() => _center = position.center);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: kMapTileUrl,
                      userAgentPackageName: 'com.example.andi_carpeta',
                    ),
                    RichAttributionWidget(attributions: [TextSourceAttribution(kMapboxEnabled ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap contributors')]),
                  ],
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 50, color: widget.color),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(context, _center), icon: const Icon(Icons.save_outlined), label: const Text('Salvează poziția'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ManualAppDocument {
  final String id;
  String title;
  String category;
  DateTime date;
  String notes;
  ManualAppDocument({required this.id, required this.title, required this.category, required this.date, this.notes = ''});
}

class DocumentsPage extends StatefulWidget {
  final bool isAdmin;
  const DocumentsPage({super.key,required this.isAdmin});
  @override State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  Future<void> _exportPvMagic() async {
    try {
      final data = await rootBundle.load('assets/pv_magic.pdf');
      await downloadFile(data.buffer.asUint8List(), 'PV_MAGIC.pdf', mimeType: 'application/pdf');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PDF-ul a fost generat pentru descărcare.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nu am putut exporta PV MAGIC: $e')));
    }
  }

  Future<void> _addDocument() async {
    final formKey=GlobalKey<FormState>();
    final title = TextEditingController();
    final notes = TextEditingController();
    String category = 'Alte documente';
    DateTime date = DateTime.now();
    final result = await showDialog<ManualAppDocument>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Adaugă document permanent'),
          content: Form(key:formKey,child:SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 520, child: SingleChildScrollView(child: Column(children: [
            TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Denumire document'),validator:(v)=>v==null||v.trim().isEmpty?'Denumirea este obligatorie.':null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Categorie'),
              items: const [
                DropdownMenuItem(value: 'Proces verbal', child: Text('Proces verbal')),
                DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                DropdownMenuItem(value: 'Anexă', child: Text('Anexă')),
                DropdownMenuItem(value: 'Alte documente', child: Text('Alte documente')),
              ],
              onChanged: (v) { if (v != null) setD(() => category = v); },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data documentului'),
              subtitle: Text(formatDate(date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(context: c, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: date);
                if (d != null) setD(() => date = d);
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Observații / detalii')),
          ])))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
            FilledButton(
              onPressed: () {
                if(!(formKey.currentState?.validate()??false))return;
                Navigator.pop(c, ManualAppDocument(id: idNow(), title: title.text.trim(), category: category, date: date, notes: notes.text.trim()));
              },
              child: const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );
    title.dispose(); notes.dispose();
    if(result==null)return;
    try {
      await FirebaseFirestore.instance.collection('documents').doc(result.id).set({
        'title':result.title,'category':result.category,'date':Timestamp.fromDate(result.date),'notes':result.notes,'createdAt':FieldValue.serverTimestamp(),
      });
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nu s-a putut salva documentul: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Documente',
    subtitle: 'Bibliotecă permanentă de documente',
    actions: [if(widget.isAdmin)FilledButton.icon(onPressed: _addDocument, icon: const Icon(Icons.note_add_outlined), label: const Text('Adaugă document'))],
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.description_outlined, size: 30)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Proces verbal MAGIC GAMES AB', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Document fix păstrat în aplicație. La apăsare se descarcă PDF-ul; nu se arhivează copii generate în Firebase.'),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: _exportPvMagic, icon: const Icon(Icons.picture_as_pdf), label: const Text('Exportă PDF')),
            ])),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Text('Alte documente permanente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection('documents').orderBy('date',descending:true).snapshots(),
        builder:(context,snap){
          if(snap.hasError)return _InfoCard(icon:Icons.error_outline,title:'Documente',text:'Eroare: ${snap.error}');
          if(!snap.hasData)return const Center(child:Padding(padding:EdgeInsets.all(20),child:CircularProgressIndicator()));
          final docs=snap.data!.docs;
          if(docs.isEmpty)return const _Empty(icon:Icons.folder_open,text:'Nu sunt încă alte documente permanente. Când trimiți al doilea PV și celelalte documente, le adăugăm aici.');
          return Column(children:docs.map((doc){final d=doc.data();final date=d['date'] is Timestamp?(d['date'] as Timestamp).toDate():DateTime.now();return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.insert_drive_file_outlined)),title:Text((d['title']??'Document').toString()),subtitle:Text('${d['category']??'Document'} · ${formatDate(date)}${(d['notes']??'').toString().isEmpty?'':'\n${d['notes']}'}'),isThreeLine:(d['notes']??'').toString().isNotEmpty,trailing:widget.isAdmin?IconButton(tooltip:'Șterge',onPressed:() async {await doc.reference.delete();},icon:const Icon(Icons.delete_outline)):null));}).toList());
        },
      ),
      const SizedBox(height: 12),
      const _InfoCard(icon: Icons.info_outline, title: 'Regulă documente', text: 'PDF-urile operaționale (Centralizator, Decont, rapoarte) se generează la cerere și se descarcă; nu se păstrează în Firebase. În bibliotecă rămân numai documentele fixe.'),
    ]),
  );
}

class CentralizerPage extends StatefulWidget {
  final AppUser currentUser;
  final List<Team> teams;
  final List<Location> locations;
  final List<LocationCategory> categories;
  final List<WorkSchedule> schedules;
  final List<CentralizerRecord> records;
  final bool isAdmin;
  final bool Function(String) canEditTeam;
  final bool canEditCentralizer;
  final VoidCallback onChanged;
  final void Function(String,String) log;
  final Future<void> Function(CentralizerRecord) saveRecord;
  const CentralizerPage({super.key,required this.currentUser,required this.teams,required this.locations,required this.categories,required this.schedules,required this.records,required this.isAdmin,required this.canEditTeam,required this.canEditCentralizer,required this.onChanged,required this.log,required this.saveRecord});
  @override State<CentralizerPage> createState()=>_CentralizerPageState();
}

class _CentralizerPageState extends State<CentralizerPage> {
  int typeIndex = 0;
  bool exporting = false;
  final searchController=TextEditingController();
  String? teamFilter;
  WorkAttemptStatus? statusFilter;
  DateTime? fromDate;
  DateTime? toDate;
  @override void dispose(){searchController.dispose();super.dispose();}
  LocationType get type => typeIndex == 0 ? LocationType.magic : LocationType.million;
  String teamName(String id) => widget.teams.firstWhere((t)=>t.id==id,orElse:()=>Team(id:'x',name:'Echipă necunoscută',members:[])).name;

  List<CentralizerRecord> _filteredRecords(){
    final q=searchController.text.trim().toLowerCase();
    final start=fromDate==null?null:DateTime(fromDate!.year,fromDate!.month,fromDate!.day);
    final finish=toDate==null?null:DateTime(toDate!.year,toDate!.month,toDate!.day,23,59,59,999);
    return widget.records.where((r){
      if(r.type!=type)return false;
      if(teamFilter!=null&&r.teamId!=teamFilter)return false;
      if(statusFilter!=null&&r.status!=statusFilter)return false;
      final when=recordEventTime(r);
      if(start!=null&&when.isBefore(start))return false;
      if(finish!=null&&when.isAfter(finish))return false;
      if(q.isNotEmpty&&!r.locationNameSnapshot.toLowerCase().contains(q)&&!r.addressSnapshot.toLowerCase().contains(q))return false;
      return true;
    }).toList();
  }

  List<WorkSchedule> _scheduledWithoutExecutionForLocation(String locationId){
    if(statusFilter!=null)return <WorkSchedule>[];
    final q=searchController.text.trim().toLowerCase();
    final start=fromDate==null?null:DateTime(fromDate!.year,fromDate!.month,fromDate!.day);
    final finish=toDate==null?null:DateTime(toDate!.year,toDate!.month,toDate!.day,23,59,59,999);
    final out=<WorkSchedule>[];
    for(final schedule in widget.schedules){
      if(teamFilter!=null&&schedule.teamId!=teamFilter)continue;
      if(start!=null&&schedule.date.isBefore(start))continue;
      if(finish!=null&&schedule.date.isAfter(finish))continue;
      final item=schedule.items.where((i)=>i.locationId==locationId&&i.typeSnapshot==type).toList();
      if(item.isEmpty)continue;
      if(q.isNotEmpty&&!item.first.locationNameSnapshot.toLowerCase().contains(q)&&!item.first.addressSnapshot.toLowerCase().contains(q))continue;
      final hasRecord=widget.records.any((r)=>r.teamId==schedule.teamId&&r.locationId==locationId&&recordBelongsToWorkDate(r,schedule.date));
      if(!hasRecord)out.add(schedule);
    }
    out.sort((a,b)=>a.date.compareTo(b.date));
    return out;
  }

  Set<String> _scheduledOnlyLocationIds(){
    if(statusFilter!=null)return <String>{};
    final ids=<String>{};
    for(final l in widget.locations.where((l)=>l.type==type)){
      if(_scheduledWithoutExecutionForLocation(l.id).isNotEmpty)ids.add(l.id);
    }
    return ids;
  }

  Future<void> _pickFilterDate(bool from)async{
    final current=from?(fromDate??DateTime.now()):(toDate??DateTime.now());
    final picked=await showDatePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now().add(const Duration(days:366)),initialDate:current);
    if(picked!=null)setState((){if(from){fromDate=picked;if(toDate!=null&&toDate!.isBefore(picked))toDate=picked;}else{toDate=picked;if(fromDate!=null&&fromDate!.isAfter(picked))fromDate=picked;}});
  }

  @override
  Widget build(BuildContext context) {
    final filtered=_filteredRecords();
    final scheduledOnlyIds=_scheduledOnlyLocationIds();
    final ids=<String>{...filtered.map((r)=>r.locationId),...scheduledOnlyIds};
    final locs=widget.locations.where((l)=>l.type==type&&ids.contains(l.id)).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final scheduledOnlyCount=locs.fold<int>(0,(sum,l)=>sum+_scheduledWithoutExecutionForLocation(l.id).length);
    return _Page(
      title:'Centralizator',subtitle:'Comun tuturor echipelor · MAGIC / Million',
      actions:[
        if(widget.isAdmin || widget.canEditCentralizer)OutlinedButton.icon(onPressed:()=>_addManualExecution(),icon:const Icon(Icons.add),label:const Text('Adaugă execuție')),
        FilledButton.icon(onPressed:exporting?null:_pdf,icon:exporting?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.picture_as_pdf),label:Text(exporting?'Se generează...':'Generează PDF ${type.label}')),
      ],
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SegmentedButton<int>(segments:[ButtonSegment(value:0,icon:categoryBrandWidget('magic',size:22,fallbackColor:Colors.black87),label:const Text('MAGIC')),ButtonSegment(value:1,icon:categoryBrandWidget('million',size:22,fallbackColor:Colors.red),label:const Text('Million'))],selected:{typeIndex},onSelectionChanged:(v)=>setState(()=>typeIndex=v.first)),
        const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:10,runSpacing:10,crossAxisAlignment:WrapCrossAlignment.center,children:[
          SizedBox(width:260,child:TextField(controller:searchController,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Nume sau adresă'))),
          SizedBox(width:220,child:DropdownButtonFormField<String?>(value:teamFilter,decoration:const InputDecoration(labelText:'Echipă'),items:[const DropdownMenuItem<String?>(value:null,child:Text('Toate echipele')),...widget.teams.map((t)=>DropdownMenuItem<String?>(value:t.id,child:Text(t.name)))],onChanged:(v)=>setState(()=>teamFilter=v))),
          SizedBox(width:220,child:DropdownButtonFormField<WorkAttemptStatus?>(value:statusFilter,decoration:const InputDecoration(labelText:'Stare'),items:[const DropdownMenuItem<WorkAttemptStatus?>(value:null,child:Text('Toate stările')),const DropdownMenuItem(value:WorkAttemptStatus.completed,child:Text('Finalizată')),const DropdownMenuItem(value:WorkAttemptStatus.running,child:Text('În lucru')),const DropdownMenuItem(value:WorkAttemptStatus.waitingAccess,child:Text('Așteptare acces')),const DropdownMenuItem(value:WorkAttemptStatus.refused,child:Text('Refuzată')),const DropdownMenuItem(value:WorkAttemptStatus.notCompleted,child:Text('Nerealizată'))],onChanged:(v)=>setState(()=>statusFilter=v))),
          OutlinedButton.icon(onPressed:()=>_pickFilterDate(true),icon:const Icon(Icons.date_range),label:Text(fromDate==null?'De la':formatDate(fromDate!))),
          OutlinedButton.icon(onPressed:()=>_pickFilterDate(false),icon:const Icon(Icons.event),label:Text(toDate==null?'Până la':formatDate(toDate!))),
          if(fromDate!=null||toDate!=null||teamFilter!=null||statusFilter!=null||searchController.text.isNotEmpty)TextButton.icon(onPressed:()=>setState((){fromDate=null;toDate=null;teamFilter=null;statusFilter=null;searchController.clear();}),icon:const Icon(Icons.filter_alt_off),label:const Text('Șterge filtre')),
        ]))),
        const SizedBox(height:8),
        Text('${filtered.length} execuții · $scheduledOnlyCount programări fără execuție · ${locs.length} locații',style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:8),
        if(locs.isEmpty)const _Empty(icon:Icons.table_chart_outlined,text:'Nu există execuții sau programări pentru filtrele selectate.'),
        ...locs.map((l)=>_centralLocation(l,filtered)),
      ]),
    );
  }

  Widget _centralLocation(Location l,List<CentralizerRecord> source) {
    final rs=source.where((r)=>r.locationId==l.id).toList()
      ..sort((a,b)=>recordEventTime(a).compareTo(recordEventTime(b)));
    final scheduledOnly=_scheduledWithoutExecutionForLocation(l.id);
    return Card(child:ExpansionTile(
      leading: categoryBrandWidget(l.categoryId, size: 38, fallbackColor: categoryColor(widget.categories,l.categoryId,fallbackType:l.type)),
      title:Text(l.name),
      subtitle:Text('${l.address}${l.surfaceM2>0?' · mochetă ${l.surfaceM2.toStringAsFixed(l.surfaceM2%1==0?0:1)} m²':''}${l.facadeM2>0?' · fațadă ${l.facadeM2.toStringAsFixed(l.facadeM2%1==0?0:1)} m²':''}'),
      trailing:(widget.isAdmin || widget.canEditCentralizer)?IconButton(tooltip:'Adaugă încă o execuție',onPressed:()=>_addManualExecution(location:l),icon:const Icon(Icons.add_circle_outline)):null,
      children:[
        ...scheduledOnly.map((schedule){
          final future=schedule.date.isAfter(DateTime.now());
          return ListTile(
            leading:Icon(future?Icons.event_outlined:Icons.radio_button_unchecked,color:future?Colors.blue:Colors.redAccent,size:18),
            title:Text('${formatDate(schedule.date)} · ${future?'Programată':'Neexecutată'}'),
            subtitle:Text('${teamName(schedule.teamId)} · ${schedule.graphName} · nu există încă o execuție înregistrată'),
          );
        }),
        ...rs.map((r){
          final color = switch(r.status){
            WorkAttemptStatus.completed => Colors.green,
            WorkAttemptStatus.running => Colors.blue,
            WorkAttemptStatus.waitingAccess => Colors.orange,
            WorkAttemptStatus.refused => Colors.red,
            WorkAttemptStatus.notCompleted => Colors.deepOrange,
          };
          final when = recordEventTime(r);
          final statusText = switch(r.status){
            WorkAttemptStatus.completed => 'Durată: ${durationText(r.duration)}${r.waitingDuration == null ? '' : ' · așteptare ${durationText(r.waitingDuration)}'}${(r.refusalReason ?? '').trim().isEmpty ? '' : ' · ${r.refusalReason}'}',
            WorkAttemptStatus.running => 'În lucru din ${timeText(r.startedAt)}${r.waitingDuration == null ? '' : ' · așteptare ${durationText(r.waitingDuration)}'}',
            WorkAttemptStatus.waitingAccess => 'Așteptare acces din ${timeText(r.waitingStartedAt)}',
            WorkAttemptStatus.refused => 'Refuzată${(r.refusalReason ?? '').trim().isEmpty ? '' : ' · ${r.refusalReason}'}',
            WorkAttemptStatus.notCompleted => 'Nerealizată${(r.refusalReason ?? '').trim().isEmpty ? '' : ' · ${r.refusalReason}'}',
          };
          return ListTile(
            leading:Icon(Icons.circle,size:10,color:color),
            title:Text('${formatDate(when)} · ${r.status == WorkAttemptStatus.waitingAccess ? timeText(r.waitingStartedAt) : '${timeText(r.startedAt)}–${timeText(r.finishedAt)}'}'),
            subtitle:Text('${teamName(r.teamId)} · $statusText'),
            trailing:(widget.isAdmin || (widget.canEditCentralizer && widget.canEditTeam(r.teamId))) && (r.status == WorkAttemptStatus.completed || r.status == WorkAttemptStatus.running)
              ? IconButton(tooltip:'Corectează START / FINAL',onPressed:()=>_editRecord(r),icon:const Icon(Icons.edit))
              : null,
          );
        }),
      ],
    ));
  }
  Future<void> _addManualExecution({Location? location}) async {
    final allowedTeams = widget.isAdmin ? widget.teams : widget.teams.where((t)=>widget.canEditTeam(t.id)).toList();
    if (allowedTeams.isEmpty) { if(mounted)showErrorMessage(context,'Nu ai o echipă în care poți adăuga execuții.'); return; }
    var selectedLocation = location;
    var selectedTeamId = allowedTeams.first.id;
    var date = DateTime.now();
    final start = TextEditingController(text:'${two((DateTime.now().subtract(const Duration(hours:1))).hour)}:${two((DateTime.now().subtract(const Duration(hours:1))).minute)}');
    final finish = TextEditingController(text:'${two(DateTime.now().hour)}:${two(DateTime.now().minute)}');
    final reason = TextEditingController();
    var facadeDone = false;
    final result = await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD){
      final choices=widget.locations.where((l)=>l.type==type).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return AlertDialog(
        title:Text(location==null?'Adaugă execuție în Centralizator':'Adaugă încă o execuție'),
        content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<String>(initialValue:selectedLocation?.id,decoration:const InputDecoration(labelText:'Locație'),items:choices.map((l)=>DropdownMenuItem(value:l.id,child:Text(l.name,overflow:TextOverflow.ellipsis))).toList(),onChanged:location!=null?null:(v)=>setD(()=>selectedLocation=v==null?null:choices.firstWhere((l)=>l.id==v))),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(initialValue:selectedTeamId,decoration:const InputDecoration(labelText:'Echipă'),items:allowedTeams.map((t)=>DropdownMenuItem(value:t.id,child:Text(t.name))).toList(),onChanged:(v){if(v!=null)setD(()=>selectedTeamId=v);}),
          const SizedBox(height:10),
          ListTile(contentPadding:EdgeInsets.zero,title:const Text('Data execuției'),subtitle:Text(formatDate(date)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:c,firstDate:DateTime(2020),lastDate:DateTime.now().add(const Duration(days:1)),initialDate:date);if(d!=null)setD(()=>date=d);}),
          Row(children:[Expanded(child:TextField(controller:start,decoration:const InputDecoration(labelText:'START HH:MM'))),const SizedBox(width:10),Expanded(child:TextField(controller:finish,decoration:const InputDecoration(labelText:'FINAL HH:MM')))]),
          const SizedBox(height:10),
          TextField(controller:reason,maxLines:2,decoration:const InputDecoration(labelText:'Observație (opțional)',hintText:'Ex.: a doua spălare / sală preluată de la altă echipă')),
          const SizedBox(height:8),
          SwitchListTile(
            contentPadding:EdgeInsets.zero,
            value:facadeDone,
            title:const Text('Fațadă realizată'),
            subtitle:const Text('Bifează numai dacă fațada a fost făcută efectiv la această intervenție.'),
            onChanged:(v)=>setD(()=>facadeDone=v),
          ),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:selectedLocation==null?null:()=>Navigator.pop(c,true),icon:const Icon(Icons.save),label:const Text('Adaugă'))],
      );
    }))??false;
    if(!result||selectedLocation==null){start.dispose();finish.dispose();reason.dispose();return;}
    final base=DateTime(date.year,date.month,date.day);
    DateTime? parse(String raw){final p=raw.trim().split(':');if(p.length!=2)return null;final h=int.tryParse(p[0]),m=int.tryParse(p[1]);if(h==null||m==null||h<0||h>23||m<0||m>59)return null;return DateTime(base.year,base.month,base.day,h,m);}
    final st=parse(start.text);var fn=parse(finish.text);start.dispose();finish.dispose();
    if(st==null||fn==null){reason.dispose();if(mounted)showErrorMessage(context,'Orele trebuie scrise HH:MM.');return;}
    if(fn.isBefore(st))fn=fn.add(const Duration(days:1));
    final note=reason.text.trim();reason.dispose();
    final l=selectedLocation!;
    final r=CentralizerRecord(id:idNow(),teamId:selectedTeamId,locationId:l.id,type:l.type,locationNameSnapshot:l.name,addressSnapshot:l.address,startedAt:st,finishedAt:fn,status:WorkAttemptStatus.completed,refusalReason:note.isEmpty?null:note,keptForLearning:true,facadePlanned:facadeDone,facadeDone:facadeDone);
    try{await widget.saveRecord(r);widget.log('Execuție manuală adăugată',l.name);if(mounted)showSuccessMessage(context,'Execuția a fost adăugată în Centralizator.');}
    catch(e){if(mounted)showErrorMessage(context,'Nu s-a putut salva execuția: $e');}
  }

  Future<void> _editRecord(CentralizerRecord r) async {
    final s = TextEditingController(text: timeText(r.startedAt));
    final f = TextEditingController(text: timeText(r.finishedAt));
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Corectează START / FINAL'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: s, decoration: const InputDecoration(labelText: 'START HH:MM')),
          TextField(controller: f, decoration: const InputDecoration(labelText: 'FINAL HH:MM')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c,false), child: const Text('Anulează')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child: const Text('Salvează')),
        ],
      ),
    );
    if(result!=true)return;
    final base = r.startedAt ?? r.finishedAt ?? DateTime.now();
    final newStart = _sameDateTime(base, s.text);
    var newFinish = _sameDateTime(newStart ?? base, f.text);
    if(newStart!=null && newFinish!=null && newFinish.isBefore(newStart)) newFinish=newFinish.add(const Duration(days:1));
    r.startedAt=newStart;
    r.finishedAt=newFinish;
    if(r.startedAt!=null&&r.finishedAt!=null)r.status=WorkAttemptStatus.completed;
    try {
      await widget.saveRecord(r);
      widget.log('START/FINAL corectat',r.locationNameSnapshot);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Corecția a fost salvată.')));
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nu s-a putut salva: $e')));
    }
  }

  DateTime? _sameDateTime(DateTime? base,String text) {
    final p=text.trim().split(':');
    if(base==null||p.length!=2)return base;
    final h=int.tryParse(p[0]),m=int.tryParse(p[1]);
    if(h==null||m==null||h<0||m<0||h>23||m>59)return base;
    return DateTime(base.year,base.month,base.day,h,m);
  }

  Future<void> _pdf() async {
    setState(()=>exporting=true);
    try {
      await downloadCentralizerPdf(type:type,locations:widget.locations,teams:widget.teams,schedules:widget.schedules,records:widget.records,teamId:teamFilter,from:fromDate,to:toDate,search:searchController.text,statusFilter:statusFilter,teamLabel:teamFilter==null?null:teamName(teamFilter!));
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PDF generat. Descărcarea a fost pornită.')));
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Eroare PDF: $e')));
    } finally {
      if(mounted)setState(()=>exporting=false);
    }
  }
}

class ExpensePage extends StatefulWidget {
  final AppUser currentUser;
  final List<Team> teams;
  final List<AppUser> users;
  final List<Expense> expenses;
  final List<PerDiemEntry> perDiems;
  final List<TeamFinance> finances;
  final List<TravelSettlement> settlements;
  final AppSettings settings;
  final bool Function(String) canEditTeam;
  final bool isAdmin;
  final bool canEditOwnDecont;
  final bool canViewOtherDecont;
  final VoidCallback onChanged;
  final void Function(String,String,String) notifyUser;
  final void Function(String,String) log;
  final Future<void> Function(Expense) saveExpense;
  final Future<void> Function(PerDiemEntry) savePerDiem;
  final Future<void> Function(TeamFinance) saveFinance;
  final Future<void> Function(TravelSettlement) saveSettlement;
  const ExpensePage({super.key,required this.currentUser,required this.teams,required this.users,required this.expenses,required this.perDiems,required this.finances,required this.settlements,required this.settings,required this.canEditTeam,required this.isAdmin,required this.canEditOwnDecont,required this.canViewOtherDecont,required this.onChanged,required this.notifyUser,required this.log,required this.saveExpense,required this.savePerDiem,required this.saveFinance,required this.saveSettlement});
  @override State<ExpensePage> createState()=>_ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  static const String _legacySettlementKey = '__legacy__';
  int teamIndex = 0;
  String? selectedSettlementId;
  bool exporting = false;
  bool scanning = false;
  final Set<String> _savingPerDiemIds = <String>{};
  final ImagePicker _imagePicker = ImagePicker();

  List<Team> get visibleTeams => (widget.isAdmin || widget.canViewOtherDecont)
      ? widget.teams
      : widget.teams.where((t) => t.members.contains(widget.currentUser.id)).toList();
  Team get team => visibleTeams[teamIndex.clamp(0, visibleTeams.length - 1)];
  List<String> get visibleTeamMemberIds {
    final visible = widget.users.map((u) => u.id).toSet();
    return team.members.where(visible.contains).toList();
  }
  String name(String id) => widget.users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: id, name: 'Membru', role: UserRole.member)).name;

  TeamFinance get finance {
    final found = widget.finances.where((f) => f.teamId == team.id);
    if (found.isNotEmpty) return found.first;
    final created = TeamFinance(teamId: team.id, managerId: team.financialManagerId, perDiemRate: widget.settings.defaultPerDiem);
    widget.finances.add(created);
    return created;
  }

  List<TravelSettlement> get teamSettlements => widget.settlements.where((s) => s.teamId == team.id).toList()
    ..sort((a, b) {
      if (a.closed != b.closed) return a.closed ? 1 : -1;
      return b.startDate.compareTo(a.startDate);
    });

  bool get hasLegacyData => widget.expenses.any((e) => e.teamId == team.id && (e.settlementId == null || e.settlementId!.isEmpty))
      || widget.perDiems.any((e) => e.teamId == team.id && (e.settlementId == null || e.settlementId!.isEmpty))
      || finance.receivedDeparture != 0
      || finance.receivedDuring != 0;

  String? _resolvedSettlementId() {
    final available = teamSettlements.map((e) => e.id).toSet();
    if (selectedSettlementId != null && (available.contains(selectedSettlementId) || (selectedSettlementId == _legacySettlementKey && hasLegacyData))) {
      return selectedSettlementId;
    }
    final open = teamSettlements.where((s) => !s.closed).toList();
    if (open.isNotEmpty) return open.first.id;
    if (teamSettlements.isNotEmpty) return teamSettlements.first.id;
    if (hasLegacyData) return _legacySettlementKey;
    return null;
  }

  TravelSettlement? get settlement {
    final id = _resolvedSettlementId();
    if (id == null || id == _legacySettlementKey) return null;
    for (final s in teamSettlements) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool get isLegacy => _resolvedSettlementId() == _legacySettlementKey;
  bool get hasSelectedDecont => _resolvedSettlementId() != null;
  bool get selectedClosed => settlement?.closed == true;
  String? get managerId => settlement?.managerId ?? finance.managerId ?? team.financialManagerId;
  double get perDiemRate => settlement?.perDiemRate ?? finance.perDiemRate;
  double get received => settlement?.totalReceived ?? finance.totalReceived;
  bool get can => widget.canEditOwnDecont && widget.canEditTeam(team.id) && hasSelectedDecont && !selectedClosed;
  bool get isManager => widget.isAdmin || (widget.canEditOwnDecont && managerId == widget.currentUser.id);

  bool _belongsToSelected(String? settlementId) {
    final id = _resolvedSettlementId();
    if (id == null) return false;
    if (id == _legacySettlementKey) return settlementId == null || settlementId.isEmpty;
    return settlementId == id;
  }

  List<Expense> get allEx => widget.expenses.where((e) => e.teamId == team.id && _belongsToSelected(e.settlementId)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  List<Expense> get ex => allEx.where((e) => e.confirmed).toList();
  List<PerDiemEntry> get di => widget.perDiems.where((e) => e.teamId == team.id && _belongsToSelected(e.settlementId)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  List<PerDiemEntry> get pendingOwnPerDiems => widget.perDiems
      .where((e) => e.memberId == widget.currentUser.id && e.status == PerDiemStatus.awaitingConfirmation && e.actualReceivedAmount == null)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  // Sold informativ pe toate deplasările, inclusiv cele închise.
  // Diferențele contestate nu sunt compensate automat.
  int _perDiemDifferenceBani(String beneficiaryId, String distributorId) {
    var balance = 0;
    for (final entry in widget.perDiems) {
      if (entry.memberId != beneficiaryId || entry.distributedBy != distributorId ||
          entry.status != PerDiemStatus.confirmed || entry.actualReceivedAmount == null) continue;
      final receivedBani = parsePerDiemBani(entry.actualReceivedAmount!.toString());
      final declaredBani = parsePerDiemBani(entry.amount.toString());
      if (receivedBani == null || declaredBani == null) continue;
      // A supplementary distribution is cash paid toward a prior debt,
      // not an additional daily allowance.
      balance += (entry.supplementaryFor == null ? declaredBani : 0) - receivedBani;
    }
    return balance;
  }

  double _perDiemDifference(String beneficiaryId, String distributorId) =>
      _perDiemDifferenceBani(beneficiaryId, distributorId) / 100;

  Widget _perDiemCarryoverCard() {
    // Soldurile urmează persoanele, nu echipa sau decontul selectat.
    // Grupăm separat fiecare pereche distribuitor-beneficiar, pentru a nu
    // amesteca obligațiile a doi distribuitori diferiți.
    final pairs = <String, MapEntry<String, String>>{};
    for (final entry in widget.perDiems) {
      final distributor = entry.distributedBy;
      if (distributor == null || distributor.isEmpty) continue;
      if (!widget.isAdmin && entry.memberId != widget.currentUser.id &&
          distributor != widget.currentUser.id) continue;
      pairs['$distributor|${entry.memberId}'] = MapEntry(distributor, entry.memberId);
    }
    final rows = <Widget>[];
    for (final pair in pairs.values) {
      final difference = _perDiemDifference(pair.value, pair.key);
      // Solicitările încă neconfirmate NU sunt datorii sau avansuri
      // validate. Le afișăm separat pentru a nu induce în eroare.
      final pending = widget.perDiems.where((entry) =>
        entry.memberId == pair.value &&
        entry.distributedBy == pair.key &&
        entry.status == PerDiemStatus.awaitingConfirmation &&
        entry.actualReceivedAmount == null).toList();
      if (difference.abs() >= 0.01) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${name(pair.key)} → ${name(pair.value)}: '
            '${difference > 0 ? 'diferență de achitat' : 'avans de verificat'} '
            '${difference.abs().toStringAsFixed(2)} lei (confirmat)'),
        ));
      }
      if (pending.isNotEmpty) {
        final pendingAmount = pending.fold<double>(0, (sum, entry) => sum + entry.amount);
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${name(pair.key)} → ${name(pair.value)}: '
            '${pending.length} ${pending.length == 1 ? 'distribuire neconfirmată' : 'distribuiri neconfirmate'} '
            '(${pendingAmount.toStringAsFixed(2)} lei declarați; nu intră în sold)'),
        ));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Solduri reportate între deconturi și echipe', style: TextStyle(fontWeight: FontWeight.bold)),
        ...rows,
        const SizedBox(height: 6),
        const Text('Sold informativ doar din încasări confirmate. Distribuirile în așteptare '
          'sunt afișate separat și nu se compensează automat. Contestațiile necesită reconciliere.'),
      ],
    )));
  }

  double get spent => ex.fold<double>(0, (a, b) => a + b.amount) + di.fold<double>(0, (a, d) => a + (d.status == PerDiemStatus.confirmed && d.received == true ? (d.actualReceivedAmount ?? 0.0) : 0.0));
  double get balance => received - spent;
  double get liters => ex.where((e) => e.category == 'Combustibil').fold<double>(0, (a, b) => a + (b.liters ?? 0));
  double get fuel => ex.where((e) => e.category == 'Combustibil').fold<double>(0, (a, b) => a + b.amount);
  List<ReceivedMoneyEntry> get receivedEntries => settlement?.receivedEntries ?? finance.receivedEntries;

  @override
  Widget build(BuildContext context) {
    if (visibleTeams.isEmpty) {
      // Confirmările rămân accesibile și după mutarea membrului în altă echipă
      // sau eliminarea temporară din echipe. Nu depind de decontul selectat.
      final pending = pendingOwnPerDiems;
      return _Page(
        title: 'Decont',
        subtitle: 'Diurne de confirmat',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (pending.isNotEmpty) ...[
            const Text('Diurne care așteaptă confirmarea ta',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...pending.map(_pendingPerDiemCard),
            const SizedBox(height: 12),
          ],
          const _InfoCard(
            icon: Icons.groups_outlined,
            title: 'Fără echipă activă',
            text: 'Nu ești atribuit unei echipe în acest moment. Confirmările de diurnă existente rămân accesibile.'),
        ]),
      );
    }
    if (teamIndex >= visibleTeams.length) teamIndex = 0;
    final resolved = _resolvedSettlementId();
    if (selectedSettlementId != resolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && selectedSettlementId != resolved) setState(() => selectedSettlementId = resolved);
      });
    }

    return _Page(
      title: 'Decont',
      subtitle: 'Separat pe deplasări · documente, diurne și sold',
      actions: [
        OutlinedButton.icon(
          onPressed: _showGeneralCalculations,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calcule generale'),
        ),
        FilledButton.icon(
          onPressed: !hasSelectedDecont || exporting ? null : _pdf,
          icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
          label: Text(exporting ? 'Se generează...' : 'Generează PDF'),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.isAdmin || widget.canViewOtherDecont)
          _TeamSelector(teams: visibleTeams, selected: teamIndex, onChanged: (v) => setState(() { teamIndex = v; selectedSettlementId = null; }))
        else
          Text('Echipă: ${team.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _settlementSelector(),
        if (pendingOwnPerDiems.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...pendingOwnPerDiems.map(_pendingPerDiemCard),
        ],
        const SizedBox(height: 14),
        if (!hasSelectedDecont) ...[
          const _Empty(icon: Icons.luggage_outlined, text: 'Nu există încă nicio deplasare. Creează prima deplasare pentru a separa corect bugetele și documentele.'),
          if (widget.canEditOwnDecont && widget.canEditTeam(team.id)) ...[
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _createSettlement, icon: const Icon(Icons.add), label: const Text('Creează deplasare')),
          ],
        ] else ...[
          if (selectedClosed)
            const _InfoCard(icon: Icons.lock_outline, title: 'Decont închis', text: 'Deplasarea este închisă. Datele rămân vizibile, dar nu se mai adaugă cheltuieli sau diurne până la redeschidere.'),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _MoneyCard(title: 'Primit la plecare', value: settlement?.departureTotal ?? finance.departureTotal, onTap: isManager && !selectedClosed ? () => _money(true) : null),
            _MoneyCard(title: 'Primit în timpul deplasării', value: settlement?.duringTotal ?? finance.duringTotal, onTap: isManager && !selectedClosed ? () => _money(false) : null),
            _MoneyCard(title: 'Total primit', value: received),
            _MoneyCard(title: 'Total cheltuieli', value: spent),
            _MoneyCard(title: 'Buget rămas', value: balance),
          ]),
          if (receivedEntries.isNotEmpty) ...[
            const SizedBox(height:10),
            Card(child:ExpansionTile(
              leading:const Icon(Icons.account_balance_wallet_outlined),
              title:const Text('Desfășurător sume primite',style:TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('${receivedEntries.length} tranșe'),
              children:(<ReceivedMoneyEntry>[...receivedEntries]..sort((a,b)=>a.date.compareTo(b.date))).map((e)=>ListTile(
                dense:true,
                leading:Icon(e.method=='Transfer'?Icons.account_balance_outlined:Icons.payments_outlined),
                title:Text('${e.amount.toStringAsFixed(2)} lei · ${e.method}'),
                subtitle:Text('${e.kind=='departure'?'La plecare':'În timpul deplasării'} · de la ${e.fromName} · ${two(e.date.day)}.${two(e.date.month)}.${e.date.year}'),
              )).toList(),
            )),
          ],
          if (balance < 0) ...[
            const SizedBox(height: 10),
            _InfoCard(icon: Icons.warning_amber_rounded, title: 'Sumă de primit', text: 'Cheltuielile depășesc banii primiți cu ${balance.abs().toStringAsFixed(2)} lei. Firma trebuie să restituie această diferență.'),
          ],
          const SizedBox(height: 16),
          Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.manage_accounts)),
            title: const Text('Gestionar financiar'),
            subtitle: Text(managerId == null ? 'Nesetat' : name(managerId!)),
            trailing: widget.isAdmin && !selectedClosed ? TextButton(onPressed: _manager, child: const Text('Schimbă')) : null,
          )),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Diurnă', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            TextButton(onPressed: isManager && !selectedClosed ? _perDiemRate : null, child: Text('${perDiemRate.toStringAsFixed(2)} lei/zi')),
          ]),
          if (isManager && !selectedClosed) Wrap(spacing: 8, children: [
            FilledButton.icon(onPressed: _distribute, icon: const Icon(Icons.payments), label: const Text('Distribuie diurnă')),
            OutlinedButton.icon(onPressed: _supplementaryPayment, icon: const Icon(Icons.add_card), label: const Text('Plată suplimentară')),
          ]),
          _perDiemCarryoverCard(),
          const SizedBox(height: 12),
          if (di.any((d) => d.supplementaryFor == null && d.status == PerDiemStatus.confirmed && d.actualReceivedAmount != null && (d.amount - d.actualReceivedAmount!).abs() >= 0.01))
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Diferențe diurne declarate / primite', style: TextStyle(fontWeight: FontWeight.bold)),
              ...di.where((d) => d.supplementaryFor == null && d.status == PerDiemStatus.confirmed && d.actualReceivedAmount != null && (d.amount - d.actualReceivedAmount!).abs() >= 0.01).map((d) {
                final difference = d.amount - d.actualReceivedAmount!;
                return Text('${name(d.memberId)}: ${difference > 0 ? 'Diferență neachitată' : 'Avans declarat'} ${difference.abs().toStringAsFixed(2)} lei');
              }),
              ...di.where((d) => d.supplementaryFor == null && d.status == PerDiemStatus.confirmed && d.actualReceivedAmount != null && (d.amount - d.actualReceivedAmount!).abs() >= 0.01).map(_perDiemDisputeActions),
              const Text('Diferențele sunt informative până la reconcilierea soldurilor între deconturi.'),
            ]))),
          ...di.map((d) => ListTile(
            leading: Icon(d.received == false ? Icons.report_outlined : d.status == PerDiemStatus.confirmed ? Icons.check_circle : Icons.schedule, color: d.received == false ? Colors.red : d.status == PerDiemStatus.confirmed ? Colors.green : Colors.orange),
            title: Text('${d.supplementaryFor == null ? 'Diurnă' : 'Plată suplimentară'} · ${name(d.memberId)} · ${formatDate(d.date)}'),
            subtitle: Text('${d.amount.toStringAsFixed(2)} lei declarați · ${d.actualReceivedAmount == null ? d.status.label : '${d.actualReceivedAmount!.toStringAsFixed(2)} lei primiți${d.actualReceivedAmount == 0 ? ' (neprimită)' : ''}'} · ${d.method?.label ?? ''}'),
            trailing: d.memberId == widget.currentUser.id && d.status == PerDiemStatus.awaitingConfirmation && d.actualReceivedAmount == null
              ? IconButton(tooltip: 'Confirmă primirea', icon: const Icon(Icons.fact_check_outlined), onPressed: () => _confirmPerDiemAmount(d)) : null,
          )),
          const Divider(height: 32),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(onPressed: can && !scanning ? _scan : null, icon: scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.document_scanner), label: Text(scanning ? 'Se citește...' : 'Scanează bon / factură')),
            OutlinedButton.icon(onPressed: can ? _manual : null, icon: const Icon(Icons.add), label: const Text('Introducere manuală')),
          ]),
          const SizedBox(height: 16),
          _InfoCard(icon: Icons.local_gas_station, title: 'Combustibil', text: '${fuel.toStringAsFixed(2)} lei · ${liters.toStringAsFixed(2)} L · preț mediu ${liters > 0 ? (fuel / liters).toStringAsFixed(2) : '0.00'} lei/L'),
          const SizedBox(height: 10),
          ..._groupedExpenses(),
          const SizedBox(height: 12),
          const _InfoCard(icon: Icons.picture_as_pdf, title: 'PDF Decont', text: 'PDF-ul folosește doar deplasarea selectată. Ordine: combustibil → facturi → diurne → alte cheltuieli. Un document ocupă un singur rând; fotografiile nu sunt salvate.'),
        ],
      ]),
    );
  }

  Widget _settlementSelector() {
    final items = <DropdownMenuItem<String>>[];
    for (final s in teamSettlements) {
      items.add(DropdownMenuItem(value: s.id, child: Text('${s.name} · ${_shortDate(s.startDate)}${s.closed ? ' · închisă' : ''}')));
    }
    if (hasLegacyData) items.add(const DropdownMenuItem(value: _legacySettlementKey, child: Text('Istoric anterior · date fără deplasare')));
    final value = _resolvedSettlementId();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Deplasare / Decont', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        if (widget.canEditOwnDecont && widget.canEditTeam(team.id))
          FilledButton.tonalIcon(onPressed: _createSettlement, icon: const Icon(Icons.add), label: const Text('Nouă')),
      ]),
      const SizedBox(height: 8),
      if (items.isNotEmpty)
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(labelText: 'Selectează deplasarea'),
          items: items,
          onChanged: (v) => setState(() => selectedSettlementId = v),
        )
      else
        const Text('Nu există deplasări.'),
      if (settlement != null) ...[
        const SizedBox(height: 8),
        Text('Perioadă: ${_shortDate(settlement!.startDate)}${settlement!.endDate == null ? '' : ' – ${_shortDate(settlement!.endDate!)}'} · ${settlement!.closed ? 'Închisă' : 'Activă'}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (isManager || widget.isAdmin) OutlinedButton.icon(onPressed: _editSettlement, icon: const Icon(Icons.edit_outlined), label: const Text('Editează deplasarea')),
          if (isManager || widget.isAdmin) OutlinedButton.icon(onPressed: _toggleSettlementClosed, icon: Icon(settlement!.closed ? Icons.lock_open : Icons.lock_outline), label: Text(settlement!.closed ? 'Redeschide' : 'Închide decontul')),
        ]),
      ],
      if (isLegacy) ...[
        const SizedBox(height: 8),
        const Text('Aceste date au fost create înainte de separarea pe deplasări. Rămân intacte și pot fi exportate separat.', style: TextStyle(fontSize: 12)),
      ],
    ])));
  }

  String _shortDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

  Future<void> _createSettlement() async {
    var start = DateTime.now();
    DateTime? end;
    final nameC = TextEditingController(text: 'Deplasare ${_shortDate(start)}');
    final result = await showDialog<TravelSettlement>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: const Text('Deplasare nouă'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Denumire')), const SizedBox(height: 10),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Data început'), subtitle: Text(_shortDate(start)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start); if (x != null) setD(() { start = x; if (end != null && end!.isBefore(start)) end = start; }); }, child: const Text('Alege'))),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_available), title: const Text('Data final (opțional)'), subtitle: Text(end == null ? 'Nesetată' : _shortDate(end!)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: start, lastDate: DateTime(2100), initialDate: end ?? start); if (x != null) setD(() => end = x); }, child: const Text('Alege'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: () { final n = nameC.text.trim(); if (n.isEmpty) return; Navigator.pop(d, TravelSettlement(id: idNow(), teamId: team.id, name: n, startDate: start, endDate: end, managerId: finance.managerId ?? team.financialManagerId ?? (team.members.contains(widget.currentUser.id) ? widget.currentUser.id : null), perDiemRate: finance.perDiemRate)); }, child: const Text('Creează'))],
    )));
    nameC.dispose();
    if (result == null) return;
    try {
      await widget.saveSettlement(result);
      widget.log('Deplasare creată', '${team.name} · ${result.name}');
      if (mounted) setState(() => selectedSettlementId = result.id);
    } catch (e) { if (mounted) showErrorMessage(context, 'Deplasarea nu a putut fi creată: $e'); }
  }

  Future<void> _editSettlement() async {
    final s = settlement; if (s == null) return;
    var start = s.startDate; var end = s.endDate;
    final nameC = TextEditingController(text: s.name);
    final ok = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: const Text('Editează deplasarea'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Denumire')), const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Început'), subtitle: Text(_shortDate(start)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start); if (x != null) setD(() => start = x); }, child: const Text('Alege'))),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Final'), subtitle: Text(end == null ? 'Nesetat' : _shortDate(end!)), trailing: Wrap(children: [TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: start, lastDate: DateTime(2100), initialDate: end ?? start); if (x != null) setD(() => end = x); }, child: const Text('Alege')), if (end != null) IconButton(onPressed: () => setD(() => end = null), icon: const Icon(Icons.clear))])),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Salvează'))],
    )));
    if (ok == true) {
      s.name = nameC.text.trim().isEmpty ? s.name : nameC.text.trim(); s.startDate = start; s.endDate = end;
      try { await widget.saveSettlement(s); widget.log('Deplasare modificată', s.name); } catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
    }
    nameC.dispose();
  }

  Future<void> _toggleSettlementClosed() async {
    final s = settlement; if (s == null) return;
    final next = !s.closed;
    if (next) {
      final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Închizi decontul?'), content: const Text('Nu se vor mai putea adăuga documente sau diurne până la redeschidere.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Închide'))])) ?? false;
      if (!ok) return;
    }
    s.closed = next;
    if (next && s.endDate == null) s.endDate = DateTime.now();
    try { await widget.saveSettlement(s); widget.log(next ? 'Decont închis' : 'Decont redeschis', s.name); if (mounted) setState(() {}); } catch (e) { s.closed = !next; if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
  }

  Future<void> _showGeneralCalculations() async {
    final years=<int>{};
    for(final e in widget.expenses.where((x)=>x.teamId==team.id)){years.add(e.date.year);}
    for(final d in widget.perDiems.where((x)=>x.teamId==team.id)){years.add((d.confirmedAt ?? d.date).year);}
    for(final st in widget.settlements.where((x)=>x.teamId==team.id)){years.add(st.startDate.year);}
    final orderedYears=years.toList()..sort((a,b)=>b.compareTo(a));
    int? selectedYear=orderedYears.isEmpty?DateTime.now().year:orderedYears.first;
    bool allTime=false;

    Map<String,double> calculate(){
      bool dateOk(DateTime d)=>allTime||d.year==selectedYear;
      final expenseIds=<String>{};
      final teamExpenses=widget.expenses.where((e)=>e.teamId==team.id&&e.confirmed&&
          e.amount.isFinite&&e.amount>=0&&dateOk(e.date)&&expenseIds.add(e.id)).toList();
      final paymentIds=<String>{};
      final teamPerDiems=widget.perDiems.where((d)=>d.teamId==team.id&&
          d.status==PerDiemStatus.confirmed&&d.received==true&&
          d.actualReceivedAmount!=null&&d.actualReceivedAmount!.isFinite&&
          d.actualReceivedAmount!>=0&&dateOk(d.confirmedAt??d.date)&&paymentIds.add(d.id)).toList();
      final fuelTotal=teamExpenses.where((e)=>e.category=='Combustibil').fold<double>(0,(a,b)=>a+b.amount);
      final invoiceTotal=teamExpenses.where((e)=>e.category!='Combustibil'&&(e.documentType==ExpenseDocumentType.invoice||e.category=='Facturi')).fold<double>(0,(a,b)=>a+b.amount);
      final otherTotal=teamExpenses.where((e)=>e.category!='Combustibil'&&e.documentType!=ExpenseDocumentType.invoice&&e.category!='Facturi').fold<double>(0,(a,b)=>a+b.amount);
      final perDiemTotal=teamPerDiems.fold<double>(0,(a,b)=>a+b.actualReceivedAmount!);

      // Deduplicate individual transfers across legacy team finances and
      // settlement records. Historical aggregate-only records have no transfer
      // identifiers and therefore cannot be safely deduplicated.
      double receivedTotal=0;
      final seenTransferIds=<String>{};
      void addTransfers(List<ReceivedMoneyEntry> transfers){
        for(final transfer in transfers){
          if(!dateOk(transfer.date) || !transfer.amount.isFinite || transfer.amount < 0) continue;
          if(!seenTransferIds.add(transfer.id)) continue;
          receivedTotal+=transfer.amount;
        }
      }
      for(final st in widget.settlements.where((x)=>x.teamId==team.id)){
        if(st.receivedEntries.isNotEmpty){
          addTransfers(st.receivedEntries);
        }else if(dateOk(st.startDate)){
          receivedTotal+=st.totalReceived;
        }
      }
      final f=widget.finances.where((x)=>x.teamId==team.id).toList();
      if(f.isNotEmpty){
        final tf=f.first;
        if(tf.receivedEntries.isNotEmpty){
          addTransfers(tf.receivedEntries);
        }else if(allTime){
          // Legacy totals without dates appear only in the all-time report.
          receivedTotal+=tf.totalReceived;
        }
      }
      final totalSpent=fuelTotal+invoiceTotal+otherTotal+perDiemTotal;
      return {
        'fuel':fuelTotal,'invoice':invoiceTotal,'perDiem':perDiemTotal,'other':otherTotal,
        'spent':totalSpent,'received':receivedTotal,
        'budget':(receivedTotal-totalSpent).clamp(0,double.infinity).toDouble(),
        'due':(totalSpent-receivedTotal).clamp(0,double.infinity).toDouble(),
      };
    }

    await showDialog<void>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD){
      final c=calculate();
      Widget row(String label,double value,{bool strong=false})=>Padding(
        padding:const EdgeInsets.symmetric(vertical:4),
        child:Row(children:[
          Expanded(child:Text(label,style:TextStyle(fontWeight:strong?FontWeight.w900:FontWeight.w600))),
          Text('${value.toStringAsFixed(2)} lei',style:TextStyle(fontWeight:strong?FontWeight.w900:FontWeight.w700)),
        ]),
      );
      return AlertDialog(
        title:const Text('Calcule generale'),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          SegmentedButton<bool>(
            segments:const[
              ButtonSegment(value:false,label:Text('Anual'),icon:Icon(Icons.calendar_month)),
              ButtonSegment(value:true,label:Text('Total general'),icon:Icon(Icons.all_inclusive)),
            ],
            selected:<bool>{allTime},
            onSelectionChanged:(v)=>setD(()=>allTime=v.first),
          ),
          if(!allTime)...[
            const SizedBox(height:12),
            DropdownButtonFormField<int>(
              value:selectedYear,
              decoration:const InputDecoration(labelText:'An'),
              items:(orderedYears.isEmpty?<int>[DateTime.now().year]:orderedYears).map((y)=>DropdownMenuItem(value:y,child:Text('$y'))).toList(),
              onChanged:(v){if(v!=null)setD(()=>selectedYear=v);},
            ),
          ],
          const SizedBox(height:16),
          Text('${team.name} · ${allTime?'toată perioada':selectedYear}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
          const Divider(),
          row('Combustibil',c['fuel']!),
          row('Facturi',c['invoice']!),
          row('Diurne',c['perDiem']!),
          row('Alte cheltuieli',c['other']!),
          const Divider(),
          row('Total primit',c['received']!,strong:true),
          row('Total cheltuit',c['spent']!,strong:true),
          row('Buget rămas',c['budget']!,strong:true),
          row('Sumă de primit',c['due']!,strong:true),
          if(!allTime&&widget.finances.any((f)=>f.teamId==team.id&&f.receivedEntries.isEmpty&&f.totalReceived!=0))
            const Padding(padding:EdgeInsets.only(top:10),child:Text('Notă: sumele legacy fără dată sunt incluse doar în „Total general”.',style:TextStyle(fontSize:12))),
        ]))),
        actions:[FilledButton(onPressed:()=>Navigator.pop(d),child:const Text('Închide'))],
      );
    }));
  }

  Future<void> _money(bool departure) async {
    final amountC=TextEditingController();
    final fromC=TextEditingController();
    String method='Cash';
    final now=DateTime.now();
    final result=await showDialog<ReceivedMoneyEntry>(
      context:context,
      builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
        title:Text(departure?'Adaugă sumă primită la plecare':'Adaugă sumă primită în timpul deplasării'),
        content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(
            controller:amountC,
            autofocus:true,
            keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'Valoare',suffixText:'lei'),
          ),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:method,
            decoration:const InputDecoration(labelText:'Metodă'),
            items:const[
              DropdownMenuItem(value:'Cash',child:Text('Cash')),
              DropdownMenuItem(value:'Transfer',child:Text('Transfer')),
            ],
            onChanged:(v){if(v!=null)setD(()=>method=v);},
          ),
          const SizedBox(height:10),
          TextField(controller:fromC,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'De la cine')),
          const SizedBox(height:10),
          ListTile(
            contentPadding:EdgeInsets.zero,
            leading:const Icon(Icons.event_outlined),
            title:const Text('Data'),
            subtitle:Text('${two(now.day)}.${two(now.month)}.${now.year} · completată automat'),
          ),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Anulează')),
          FilledButton(onPressed:(){
            final amount=double.tryParse(amountC.text.trim().replaceAll(',','.'));
            final from=fromC.text.trim();
            if(amount==null||amount<=0||from.isEmpty)return;
            Navigator.pop(d,ReceivedMoneyEntry(
              id:idNow(),
              kind:departure?'departure':'during',
              amount:amount,
              method:method,
              fromName:from,
              date:now,
            ));
          },child:const Text('Adaugă')),
        ],
      )),
    );
    amountC.dispose();fromC.dispose();
    if(result==null)return;
    try{
      if(settlement!=null){
        settlement!.receivedEntries.add(result);
        settlement!.receivedDeparture=settlement!.departureTotal;
        settlement!.receivedDuring=settlement!.duringTotal;
        await widget.saveSettlement(settlement!);
        widget.log('Sumă primită adăugată','${settlement!.name} · ${result.amount.toStringAsFixed(2)} lei · ${result.fromName} · ${result.method}');
      }else{
        finance.receivedEntries.add(result);
        finance.receivedDeparture=finance.departureTotal;
        finance.receivedDuring=finance.duringTotal;
        await widget.saveFinance(finance);
        widget.log('Sumă primită adăugată','${team.name} · ${result.amount.toStringAsFixed(2)} lei · ${result.fromName} · ${result.method}');
      }
      if(mounted){setState((){});showSuccessMessage(context,'Suma primită a fost adăugată.');}
    }catch(e){if(mounted)showErrorMessage(context,'Nu s-a putut salva suma: $e');}
  }

  Widget _pendingPerDiemCard(PerDiemEntry entry) {
    final source = entry.distributedBy == null ? 'Gestionar financiar' : name(entry.distributedBy!);
    final method = entry.method?.label ?? 'Metodă nespecificată';
    final alreadyReportedMissing = entry.received == false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.payments_outlined, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text('Confirmare diurnă', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          Text('${entry.amount.toStringAsFixed(2)} lei · $method · de la $source'),
          Text('Data distribuirii: ${formatDate(entry.distributedAt ?? entry.date)}'),
          if (alreadyReportedMissing) ...[
            const SizedBox(height: 6),
            const Text('Ai raportat că nu ai primit banii. Solicitarea rămâne deschisă; confirmă suma doar după încasare.', style: TextStyle(fontWeight: FontWeight.w700)),
          ] else ...[
            const SizedBox(height: 6),
            const Text('Confirmă dacă ai primit efectiv suma.', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => _confirmPerDiemAmount(entry),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmă suma primită'),
            ),
            if (!alreadyReportedMissing)
              OutlinedButton.icon(
                onPressed: () => _answerPerDiem(entry, 0),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Nu am primit'),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirmPerDiemAmount(PerDiemEntry entry) async {
    // O confirmare trebuie să reflecte suma verificată de beneficiar, nu o valoare precompletată.
    final controller = TextEditingController();
    final value = await showDialog<double>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmare sumă primită'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Distribuitorul a declarat ${entry.amount.toStringAsFixed(2)} lei.'),
        const SizedBox(height: 12),
        TextField(controller: controller, autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Suma primită efectiv', hintText: 'Introdu suma numărată', suffixText: 'lei')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Anulează')),
        FilledButton(onPressed: () {
          final bani = parsePerDiemBani(controller.text);
          if (bani == null) {
            showErrorMessage(dialogContext, 'Introdu o sumă validă, cu maximum două zecimale.');
            return;
          }
          Navigator.pop(dialogContext, bani / 100);
        }, child: const Text('Confirmă')),
      ],
    ));
    controller.dispose();
    if (value == null) return;
    // Diferențele sunt confirmate explicit pentru a evita greșelile de tastare.
    if ((value - entry.amount).abs() >= 0.01) {
      if (!mounted) return;
      final difference = value - entry.amount;
      final accepted = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
        title: Text(difference > 0 ? 'Atenție: plată în avans' : 'Atenție: sumă incompletă'),
        content: Text(difference > 0
          ? 'Ai introdus ${value.toStringAsFixed(2)} lei, cu ${difference.toStringAsFixed(2)} lei peste suma declarată. Diferența va apărea ca avans de verificat.'
          : 'Ai introdus ${value.toStringAsFixed(2)} lei, cu ${difference.abs().toStringAsFixed(2)} lei sub suma declarată. Diferența va apărea ca restanță de verificat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Corectează')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirmă diferența')),
        ],
      )) ?? false;
      if (!accepted) return;
    }
    await _answerPerDiem(entry, value);
  }

  Future<void> _answerPerDiem(PerDiemEntry entry, double amountReceived) async {
    // Previne confirmări duble și rescrierea unei plăți deja confirmate.
    if (entry.memberId != widget.currentUser.id ||
        entry.status != PerDiemStatus.awaitingConfirmation ||
        entry.actualReceivedAmount != null ||
        _savingPerDiemIds.contains(entry.id)) {
      if (mounted) showErrorMessage(context, 'Această diurnă nu mai poate fi confirmată din contul curent.');
      return;
    }
    if (!amountReceived.isFinite || amountReceived < 0 || amountReceived > 100000000 || (amountReceived * 100 - (amountReceived * 100).round()).abs() > 0.000001) return;
    if (amountReceived == 0 && entry.received == false) {
      if (mounted) showErrorMessage(context, 'Neprimirea a fost deja declarată. Poți confirma ulterior suma încasată.');
      return;
    }
    _savingPerDiemIds.add(entry.id);
    final previousReceived = entry.received;
    final previousStatus = entry.status;
    final previousConfirmedAt = entry.confirmedAt;
    final previousAmount = entry.actualReceivedAmount;
    // Zero lei este un refuz, nu o confirmare definitivă: solicitarea
    // rămâne deschisă și poate fi confirmată după plata efectivă.
    // Nu marcăm zero ca sumă încasată, pentru a nu bloca plata ulterioară.
    entry.actualReceivedAmount = amountReceived == 0 ? null : amountReceived;
    entry.received = amountReceived > 0;
    entry.status = amountReceived == 0
        ? PerDiemStatus.awaitingConfirmation
        : PerDiemStatus.confirmed;
    entry.confirmedAt = amountReceived == 0 ? null : DateTime.now();
    final difference = entry.amount - amountReceived;
    try {
      await widget.savePerDiem(entry);
      widget.log(amountReceived == 0 ? 'Diurnă: primire refuzată' : 'Diurnă: sumă efectiv primită',
        '${name(entry.memberId)} · declarat ${entry.amount.toStringAsFixed(2)} lei · primit ${amountReceived.toStringAsFixed(2)} lei · diferență ${difference.toStringAsFixed(2)} lei');
      if (entry.distributedBy != null && (amountReceived == 0 || difference.abs() >= 0.01)) {
        final title = amountReceived == 0 ? 'Diurnă declarată neprimită' : 'Diferență diurnă';
        final detail = amountReceived == 0
            ? '${name(entry.memberId)} a declarat că nu a primit diurna de ${entry.amount.toStringAsFixed(2)} lei. Solicitarea rămâne deschisă.'
            : '${name(entry.memberId)} a confirmat ${amountReceived.toStringAsFixed(2)} lei față de ${entry.amount.toStringAsFixed(2)} lei declarați. ${difference > 0 ? 'Diferență de plată' : 'Posibil avans'}: ${difference.abs().toStringAsFixed(2)} lei. Verifică situația în Decont.';
        widget.notifyUser(entry.distributedBy!, title, detail);
      }
      widget.onChanged();
      if (mounted) {
        setState(() {});
        showSuccessMessage(context, difference.abs() < 0.01
          ? 'Diurna a fost confirmată integral.'
          : amountReceived == 0
            ? 'Neprimirea diurnei a fost înregistrată. Distribuitorul a fost notificat.'
            : 'Suma efectiv primită a fost salvată. Diferența a fost semnalată.');
      }
    } catch (e) {
      entry.received = previousReceived;
      entry.status = previousStatus;
      entry.confirmedAt = previousConfirmedAt;
      entry.actualReceivedAmount = previousAmount;
      if (mounted) {
        setState(() {});
        showErrorMessage(context, 'Nu s-a putut salva confirmarea diurnei: $e');
      }
    } finally {
      _savingPerDiemIds.remove(entry.id);
    }
  }

  Future<void> _manager() async {
    String? selected = managerId;
    final r = await showDialog<String>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(title: const Text('Gestionar financiar'), content: Column(mainAxisSize: MainAxisSize.min, children: visibleTeamMemberIds.map((id) => RadioListTile<String>(value: id, groupValue: selected, title: Text(name(id)), onChanged: (v) => setD(() => selected = v))).toList()), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: selected == null ? null : () => Navigator.pop(d, selected), child: const Text('Salvează'))])));
    if (r == null) return;
    if (settlement != null) {
      settlement!.managerId = r;
      try { await widget.saveSettlement(settlement!); widget.log('Gestionar financiar schimbat', '${settlement!.name} · ${name(r)}'); } catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
    } else {
      finance.managerId = r; team.financialManagerId = r; await _saveFinance(finance, 'Gestionar financiar schimbat'); widget.onChanged();
    }
  }

  Future<void> _perDiemRate() async {
    final c = TextEditingController(text: perDiemRate.toStringAsFixed(2));
    final r = await showDialog<double>(context: context, builder: (d) => AlertDialog(title: const Text('Valoare diurnă'), content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'lei/zi')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('Salvează'))]));
    c.dispose(); if (r == null || r < 0) return;
    if (settlement != null) {
      settlement!.perDiemRate = r;
      try { await widget.saveSettlement(settlement!); widget.log('Valoare diurnă modificată', settlement!.name); } catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
    } else { finance.perDiemRate = r; await _saveFinance(finance, 'Valoare diurnă modificată'); }
  }

  Future<void> _saveFinance(TeamFinance value, String auditAction) async {
    try { await widget.saveFinance(value); widget.log(auditAction, team.name); if (mounted) setState(() {}); }
    catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva: $e'); }
  }

  Future<void> _respondToPerDiemDifference(PerDiemEntry entry, {required bool dispute}) async {
    if (entry.distributedBy != widget.currentUser.id && !widget.isAdmin) return;
    if (entry.supplementaryFor != null || entry.status != PerDiemStatus.confirmed ||
        entry.actualReceivedAmount == null ||
        (entry.amount - entry.actualReceivedAmount!).abs() < 0.01) return;
    String reason = '';
    if (dispute) {
      final controller = TextEditingController();
      final response = await showDialog<String>(context: context, builder: (d) => AlertDialog(
        title: const Text('Contestă diferența de diurnă'),
        content: TextField(controller: controller, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motiv obligatoriu')),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
          FilledButton(onPressed: () {
            if (controller.text.trim().isEmpty) {
              showErrorMessage(d, 'Motivul este obligatoriu.'); return;
            }
            Navigator.pop(d, controller.text.trim());
          }, child: const Text('Contestă'))]));
      controller.dispose();
      if (response == null) return;
      reason = response;
    }
    final ref = FirebaseFirestore.instance.collection('perDiemDisputes').doc(entry.id);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final previous = await tx.get(ref);
        if (previous.exists) throw StateError('Diferența are deja o decizie sau contestație.');
        tx.set(ref, {
          'perDiemId': entry.id,
          'distributorId': entry.distributedBy,
          'beneficiaryId': entry.memberId,
          'declaredBani': parsePerDiemBani(entry.amount.toString()),
          'receivedBani': parsePerDiemBani(entry.actualReceivedAmount!.toString()),
          'status': dispute ? 'disputed' : 'accepted',
          'reason': reason,
          'actorUid': widget.currentUser.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      widget.notifyUser(entry.memberId, dispute ? 'Diferență contestată' : 'Diferență acceptată',
        dispute ? 'Distribuitorul a contestat diferența de diurnă. Motiv: $reason' :
          'Distribuitorul a acceptat diferența de diurnă.');
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu s-a putut înregistra decizia: $e');
    }
  }

  Future<void> _resolvePerDiemDispute(PerDiemEntry entry, String decision) async {
    if (!widget.isAdmin) return;
    final ref = FirebaseFirestore.instance.collection('perDiemDisputes').doc(entry.id);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists || snap.data()?['status'] != 'disputed') {
          throw StateError('Contestația nu mai este deschisă.');
        }
        tx.update(ref, {
          'status': decision,
          'resolvedBy': widget.currentUser.id,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      });
      widget.notifyUser(entry.memberId, 'Contestație diurnă soluționată',
        'Adminul a soluționat contestația: $decision. Suma confirmată rămâne nemodificată.');
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu s-a putut soluționa contestația: $e');
    }
  }

  Widget _perDiemDisputeActions(PerDiemEntry entry) {
    if (entry.supplementaryFor != null || entry.status != PerDiemStatus.confirmed ||
        entry.actualReceivedAmount == null ||
        (entry.amount - entry.actualReceivedAmount!).abs() < 0.01) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('perDiemDisputes').doc(entry.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Contestația nu poate fi încărcată.');
        if (!snapshot.hasData) return const SizedBox.shrink();
        final dispute = snapshot.data!.data();
        if (dispute == null && (entry.distributedBy == widget.currentUser.id || widget.isAdmin)) {
          return Wrap(spacing: 4, children: [
            TextButton(onPressed: () => _respondToPerDiemDifference(entry, dispute: false),
              child: const Text('Accept diferența')),
            TextButton(onPressed: () => _respondToPerDiemDifference(entry, dispute: true),
              child: const Text('Contest diferența')),
          ]);
        }
        if (dispute == null) return const SizedBox.shrink();
        final status = (dispute['status'] ?? '').toString();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Diferență: $status${(dispute['reason'] ?? '').toString().isEmpty ? '' : ' · ${dispute['reason']}'}'),
          if (widget.isAdmin && status == 'disputed')
            Wrap(spacing: 4, children: [
              TextButton(onPressed: () => _resolvePerDiemDispute(entry, 'resolved_accepted'),
                child: const Text('Validează diferența')),
              TextButton(onPressed: () => _resolvePerDiemDispute(entry, 'resolved_rejected'),
                child: const Text('Respinge contestația')),
            ]),
        ]);
      });
  }

  Future<void> _supplementaryPayment() async {
    if (!isManager || managerId == null || selectedClosed) return;
    final eligible = widget.perDiems.where((e) =>
      e.distributedBy == managerId && e.memberId != managerId &&
      e.supplementaryFor == null && e.status == PerDiemStatus.confirmed &&
      e.actualReceivedAmount != null && e.amount > e.actualReceivedAmount!).toList();
    if (eligible.isEmpty) {
      if (mounted) showErrorMessage(context, 'Nu există diferențe confirmate pentru acest distribuitor.');
      return;
    }
    PerDiemEntry original = eligible.first;
    final amount = TextEditingController();
    String method = 'Numerar';
    final payment = await showDialog<PerDiemEntry>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) =>
      AlertDialog(title: const Text('Plată suplimentară diurnă'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: original.id,
            decoration: const InputDecoration(labelText: 'Diferența inițială'),
            items: eligible.map((e) => DropdownMenuItem(value: e.id,
              child: Text('${name(e.memberId)} · ${e.id.substring(0, e.id.length > 8 ? 8 : e.id.length)}'))).toList(),
            onChanged: (v) => setD(() => original = eligible.firstWhere((e) => e.id == v))),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Sumă trimisă', suffixText: 'lei')),
          DropdownButtonFormField<String>(initialValue: method,
            items: const [DropdownMenuItem(value: 'Numerar', child: Text('Numerar')),
              DropdownMenuItem(value: 'Transfer bancar', child: Text('Transfer bancar'))],
            onChanged: (v) { if (v != null) setD(() => method = v); }),
        ]), actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
          FilledButton(onPressed: () {
            final bani = parsePerDiemBani(amount.text, allowZero: false);
            if (bani == null) { showErrorMessage(d, 'Introdu o sumă pozitivă validă.'); return; }
            Navigator.pop(d, PerDiemEntry(id: idNow(), teamId: team.id,
              settlementId: settlement?.id, memberId: original.memberId,
              date: DateTime.now(), amount: bani / 100,
              status: PerDiemStatus.awaitingConfirmation,
              distributedBy: managerId, distributedAt: DateTime.now(),
              method: method == 'Numerar' ? PerDiemPaymentMethod.cash : PerDiemPaymentMethod.bankTransfer,
              supplementaryFor: original.id));
          }, child: const Text('Trimite')), ])));
    amount.dispose();
    if (payment == null) return;
    try {
      await widget.savePerDiem(payment);
      widget.notifyUser(payment.memberId, 'Plată suplimentară de confirmat',
        'Ai o plată suplimentară de ${payment.amount.toStringAsFixed(2)} lei de confirmat.');
      widget.onChanged();
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Plata suplimentară nu a putut fi salvată: $e');
    }
  }

  Future<void> _distribute() async {
    if (managerId == null) { if (mounted) showErrorMessage(context, 'Setează mai întâi gestionarul financiar.'); return; }
    String? beneficiary = visibleTeamMemberIds.where((x) => x != managerId).isEmpty ? null : visibleTeamMemberIds.where((x) => x != managerId).first;
    String method = 'Numerar';
    final amount = TextEditingController(text: perDiemRate.toStringAsFixed(2));
    final r = await showDialog<PerDiemEntry>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(title: const Text('Distribuire diurnă'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: beneficiary, decoration: const InputDecoration(labelText: 'Trimite către'), items: visibleTeamMemberIds.map((id) => DropdownMenuItem(value: id, child: Text(name(id)))).toList(), onChanged: (v) => setD(() => beneficiary = v)), const SizedBox(height: 8), TextField(controller: amount, decoration: const InputDecoration(labelText: 'Sumă'), keyboardType: const TextInputType.numberWithOptions(decimal: true)), const SizedBox(height: 8), DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'Metodă'), items: const [DropdownMenuItem(value: 'Numerar', child: Text('Numerar')), DropdownMenuItem(value: 'Transfer bancar', child: Text('Transfer bancar'))], onChanged: (v) { if (v != null) setD(() => method = v); })]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')), FilledButton(onPressed: beneficiary == null ? null : () { final bani = parsePerDiemBani(amount.text, allowZero: false);
      if (bani == null) { showErrorMessage(d, 'Suma trebuie să fie pozitivă și să aibă maximum două zecimale.'); return; }
      if (beneficiary == managerId) { showErrorMessage(d, 'Distribuitorul nu poate fi propriul beneficiar.'); return; }
      final value = bani / 100;
      Navigator.pop(d, PerDiemEntry(id: idNow(), teamId: team.id, settlementId: settlement?.id, memberId: beneficiary!, date: DateTime.now(), amount: value, status: PerDiemStatus.awaitingConfirmation, method: method == 'Numerar' ? PerDiemPaymentMethod.cash : PerDiemPaymentMethod.bankTransfer, distributedBy: managerId, distributedAt: DateTime.now())); }, child: const Text('Distribuie'))])));
    amount.dispose(); if (r == null) return;
    if (r.distributedBy == r.memberId || r.amount <= 0 || !r.amount.isFinite ||
        (r.amount * 100 - (r.amount * 100).round()).abs() > 0.000001) {
      if (mounted) showErrorMessage(context, 'Distribuirea nu este validă.');
      return;
    }
    final carryover = _perDiemDifference(r.memberId, managerId!);
    if (carryover.abs() >= 0.01) {
      final proceed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(carryover < 0 ? 'Atenție: avans existent' : 'Atenție: diferență restantă'),
        content: Text('${name(r.memberId)} are ${carryover.abs().toStringAsFixed(2)} lei '
          '${carryover < 0 ? 'avans înregistrat' : 'diferență de achitat'} '
          'din confirmări anterioare. Verifică soldul înainte de o nouă distribuire. '
          'Noua distribuire nu va compensa automat această diferență.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Anulează')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continuă')),
        ],
      )) ?? false;
      if (!proceed) return;
    }
    try { await widget.savePerDiem(r); widget.notifyUser(r.memberId, 'Diurnă de confirmat', 'Ai primit ${r.amount.toStringAsFixed(2)} lei diurnă pentru ${settlement?.name ?? 'decontul anterior'}.'); widget.log('Diurnă distribuită', '${name(r.memberId)} · ${settlement?.name ?? 'istoric anterior'}'); }
    catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva diurna: $e'); }
  }

  Future<XFile?> _pickDocumentImage({bool allowNoImage = false}) async {
    final source = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Fotografiază acum'), onTap: () => Navigator.pop(c, 'camera')),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Alege din galerie'), onTap: () => Navigator.pop(c, 'gallery')),
      if (allowNoImage) ListTile(leading: const Icon(Icons.edit_note), title: const Text('Fără fotografie'), onTap: () => Navigator.pop(c, 'none')),
    ])));
    if (source == null || source == 'none') return null;
    try {
      return await _imagePicker.pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 92, maxWidth: 2400, maxHeight: 2400);
    } catch (e) { if (mounted) showErrorMessage(context, 'Imaginea nu a putut fi deschisă: $e'); return null; }
  }

  Uint8List _compressDocumentImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) { if (bytes.length <= 550000) return bytes; throw const FormatException('Imagine prea mare sau format nesuportat.'); }
    var work = img.bakeOrientation(decoded);
    int longest = work.width > work.height ? work.width : work.height;
    if (longest > 1400) {
      work = work.width >= work.height ? img.copyResize(work, width: 1400) : img.copyResize(work, height: 1400);
    }
    var encoded = Uint8List.fromList(img.encodeJpg(work, quality: 68));
    if (encoded.length > 480000) {
      work = work.width >= work.height ? img.copyResize(work, width: 1050) : img.copyResize(work, height: 1050);
      encoded = Uint8List.fromList(img.encodeJpg(work, quality: 56));
    }
    if (encoded.length > 480000) {
      work = work.width >= work.height ? img.copyResize(work, width: 800) : img.copyResize(work, height: 800);
      encoded = Uint8List.fromList(img.encodeJpg(work, quality: 48));
    }
    return encoded;
  }

  String _fingerprint(Uint8List bytes) {
    var h = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final b in bytes) {
      h ^= BigInt.from(b);
      h = (h * prime) & mask;
    }
    return h.toRadixString(16).padLeft(16, '0');
  }

  String _normalizedDocNo(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Expense? _duplicateOf(Expense candidate) {
    for (final e in widget.expenses) {
      if (e.teamId != candidate.teamId) continue;
      final sameSettlement = (e.settlementId ?? '') == (candidate.settlementId ?? '');
      if (!sameSettlement) continue;
      if (candidate.imageFingerprint.isNotEmpty && e.imageFingerprint == candidate.imageFingerprint) return e;
      final n1 = _normalizedDocNo(candidate.documentNumber), n2 = _normalizedDocNo(e.documentNumber);
      if (n1.isNotEmpty && n1 == n2 && sameDay(candidate.date, e.date) && (candidate.amount - e.amount).abs() < .02) return e;
    }
    return null;
  }

  Future<bool> _duplicateAllowed(Expense candidate) async {
    final learning = widget.settings.learning['conflicts'];
    if (learning?.enabled != true) return true;
    final duplicate = _duplicateOf(candidate);
    if (duplicate == null) return true;
    if (learning!.mode == LearningMode.automatic) {
      if (mounted) showErrorMessage(context, 'Document duplicat blocat automat: ${duplicate.documentNumber.isEmpty ? duplicate.description : duplicate.documentNumber}.');
      widget.log('Duplicat financiar blocat', candidate.documentNumber);
      return false;
    }
    return await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Posibil document duplicat'), content: Text('Există deja un document foarte asemănător: ${duplicate.documentNumber.isEmpty ? 'fără număr' : duplicate.documentNumber}, ${duplicate.amount.toStringAsFixed(2)} lei, ${formatDate(duplicate.date)}.\n\nSalvezi totuși?'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Nu, oprește')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Da, salvează'))])) ?? false;
  }

  Future<void> _manual() async {
    final picked = await _pickDocumentImage(allowNoImage: true);
    Uint8List? raw;
    FiscalOcrData? parsed;
    if (picked != null) {
      raw = await picked.readAsBytes();
      final ocrSetting = widget.settings.learning['ocr'];
      if (raw.isNotEmpty && ocrSetting?.enabled == true && ocrSetting?.mode == LearningMode.automatic) {
        setState(() => scanning = true);
        try {
          final text = await recognizeTextFromImage(raw, path: picked.path);
          parsed = parseFiscalOcr(text);
          widget.log('OCR automat la atașare', '${team.name} · încredere ${(parsed.confidence * 100).round()}%');
        } catch (_) {
          // În modul automat, eșecul OCR nu blochează introducerea manuală.
        } finally {
          if (mounted) setState(() => scanning = false);
        }
      }
    }
    final e = await _expenseDialog(ocr: parsed, imageBytes: raw);
    if (e != null) await _saveNewExpense(e);
  }

  Future<void> _scan() async {
    final ocrSetting = widget.settings.learning['ocr'];
    if (ocrSetting?.enabled != true) { if (mounted) showErrorMessage(context, 'OCR financiar este dezactivat din Learning Center.'); return; }
    final picked = await _pickDocumentImage();
    if (picked == null) return;
    final raw = await picked.readAsBytes();
    if (raw.isEmpty) return;
    setState(() => scanning = true);
    FiscalOcrData parsed;
    try {
      final text = await recognizeTextFromImage(raw, path: picked.path);
      parsed = parseFiscalOcr(text);
      widget.log('OCR document procesat', '${team.name} · încredere ${(parsed.confidence * 100).round()}%');
    } catch (e) {
      parsed = const FiscalOcrData(rawText: '');
      if (mounted) showErrorMessage(context, 'OCR-ul nu a putut citi documentul. Poți completa manual; fotografia nu se salvează în baza de date. Detalii: $e');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
    final expense = await _expenseDialog(ocr: parsed, imageBytes: raw);
    if (expense != null) await _saveNewExpense(expense);
  }

  // Monetary input is validated as decimal text before conversion to double.
  // This prevents NaN, infinity, exponential notation and sub-ban amounts.
  int? _expenseAmountBani(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?\$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final lei = int.tryParse(parts.first);
    if (lei == null) return null;
    final bani = parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
    final total = lei * 100 + bani;
    return total > 0 ? total : null;
  }

  Future<Expense?> _expenseDialog({FiscalOcrData? ocr, Uint8List? imageBytes}) async {
    final formKey = GlobalKey<FormState>();
    final number = TextEditingController(text: ocr?.documentNumber ?? '');
    final amount = TextEditingController(text: ocr?.amount == null ? '' : ocr!.amount!.toStringAsFixed(2));
    final supplier = TextEditingController(text: ocr?.supplier ?? '');
    final desc = TextEditingController();
    final litersC = TextEditingController(text: ocr?.liters == null ? '' : ocr!.liters!.toStringAsFixed(2));
    final priceC = TextEditingController(text: ocr?.pricePerLiter == null ? '' : ocr!.pricePerLiter!.toStringAsFixed(2));
    String cat = ocr?.looksLikeFuel == true ? 'Combustibil' : 'Alte cheltuieli';
    ExpenseDocumentType docType = (ocr?.rawText.toUpperCase().contains('FACTUR') ?? false) ? ExpenseDocumentType.invoice : ExpenseDocumentType.fiscalReceipt;
    DateTime docDate = ocr?.date ?? DateTime.now();
    Uint8List? compressed;
    if(imageBytes!=null){
      try{compressed=_compressDocumentImage(imageBytes);}catch(e){if(mounted)showErrorMessage(context,'Fotografia nu a putut fi comprimată și nu va fi atașată: $e');}
    }
    // Fotografia este utilizată numai în memorie pentru OCR/previzualizare.
    // În Firestore salvăm doar un fingerprint mic pentru deduplicare.
    const photoBase64 = '';
    final fingerprint = imageBytes == null ? '' : _fingerprint(imageBytes);

    final result = await showDialog<Expense>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: Text(ocr == null ? 'Introducere document' : 'Verifică datele citite prin OCR'),
      content: SizedBox(width: 620, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (compressed != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(compressed, height: 180, fit: BoxFit.contain)),
          const SizedBox(height: 8),
        ],
        if (ocr != null) ...[
          _InfoCard(icon: Icons.document_scanner, title: 'OCR ${(ocr.confidence * 100).round()}%', text: ocr.rawText.isEmpty ? 'Textul nu a putut fi extras. Completează manual.' : 'Datele au fost completate automat. Verifică-le înainte de salvare. Fotografia este temporară și nu va fi salvată.'),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<ExpenseDocumentType>(initialValue: docType, decoration: const InputDecoration(labelText: 'Tip document'), items: const [DropdownMenuItem(value: ExpenseDocumentType.fiscalReceipt, child: Text('Bon Fiscal')), DropdownMenuItem(value: ExpenseDocumentType.invoice, child: Text('Factură'))], onChanged: (v) { if (v != null) setD(() { docType = v; if (v == ExpenseDocumentType.invoice && cat == 'Alte cheltuieli') cat = 'Facturi'; if (v == ExpenseDocumentType.fiscalReceipt && cat == 'Facturi') cat = 'Alte cheltuieli'; }); }),
        const SizedBox(height: 8),
        TextFormField(controller: number, decoration: InputDecoration(labelText: docType == ExpenseDocumentType.fiscalReceipt ? 'Nr. bon' : 'Nr. factură'), validator: (v) => v == null || v.trim().isEmpty ? 'Numărul documentului este obligatoriu.' : null),
        const SizedBox(height: 8),
        TextFormField(controller: supplier, decoration: const InputDecoration(labelText: 'Furnizor / comerciant')),
        const SizedBox(height: 8),
        TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sumă', suffixText: 'lei'), validator: (v) => _expenseAmountBani(v ?? '') == null ? 'Introdu o sumă pozitivă, cu maximum 2 zecimale.' : null),
        const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Data documentului'), subtitle: Text(_shortDate(docDate)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: docDate); if (x != null) setD(() => docDate = x); }, child: const Text('Alege'))),
        DropdownButtonFormField<String>(initialValue: cat, decoration: const InputDecoration(labelText: 'Categorie'), items: const [DropdownMenuItem(value: 'Combustibil', child: Text('Combustibil')), DropdownMenuItem(value: 'Facturi', child: Text('Facturi')), DropdownMenuItem(value: 'Alte cheltuieli', child: Text('Alte cheltuieli'))], onChanged: (v) { if (v != null) setD(() => cat = v); }),
        if (cat == 'Combustibil') ...[
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextFormField(controller: litersC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litri'))), const SizedBox(width: 8), Expanded(child: TextFormField(controller: priceC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preț / litru')))]),
        ],
        const SizedBox(height: 8),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Specificație / descriere (opțional)')),
        if (ocr != null && ocr.rawText.isNotEmpty) ExpansionTile(title: const Text('Text OCR brut'), children: [Padding(padding: const EdgeInsets.all(8), child: SelectableText(ocr.rawText, style: const TextStyle(fontSize: 11)))]),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
        FilledButton(onPressed: () {
          if (!(formKey.currentState?.validate() ?? false)) return;
          if (docDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
            ScaffoldMessenger.of(d).showSnackBar(const SnackBar(content: Text('Data documentului nu poate fi în viitor.')));
            return;
          }
          final bani = _expenseAmountBani(amount.text);
          if (bani == null) return;
          final value = bani / 100.0;
          Navigator.pop(d, Expense(
            id: idNow(), teamId: team.id, settlementId: settlement?.id, category: cat,
            description: desc.text.trim().isEmpty ? cat : desc.text.trim(), amount: value, date: docDate,
            documentType: docType, documentNumber: number.text.trim(), supplier: supplier.text.trim(),
            liters: double.tryParse(litersC.text.replaceAll(',', '.')), pricePerLiter: double.tryParse(priceC.text.replaceAll(',', '.')),
            documentImageBase64: photoBase64, imageFingerprint: fingerprint, ocrRawText: '', ocrConfidence: ocr?.confidence ?? 0,
            confirmed: isManager,
          ));
        }, child: Text(isManager ? 'Confirmă' : 'Trimite spre confirmare')),
      ],
    )));
    for (final c in [number, amount, supplier, desc, litersC, priceC]) { c.dispose(); }
    return result;
  }

  Future<void> _saveNewExpense(Expense e) async {
    if (!await _duplicateAllowed(e)) return;
    try {
      await widget.saveExpense(e);
      widget.log('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} introdus', '${e.category} · ${settlement?.name ?? 'istoric anterior'}');
      if (mounted) showSuccessMessage(context, e.confirmed ? 'Documentul a fost salvat.' : 'Documentul a fost trimis gestionarului pentru confirmare.');
    } catch (err) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva documentul: $err'); }
  }

  List<Widget> _groupedExpenses() {
    const groups = ['Combustibil', 'Facturi', 'Alte cheltuieli'];
    final out = <Widget>[];
    for (final g in groups) {
      final items = allEx.where((e) => e.category == g).toList();
      if (items.isEmpty) continue;
      out.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(g, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));
      out.addAll(items.map((e) => Card(child: ListTile(
        leading: e.hasImage ? InkWell(onTap: () => _showExpenseImage(e), child: ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.memory(base64Decode(e.documentImageBase64), width: 48, height: 48, fit: BoxFit.cover))) : const CircleAvatar(child: Icon(Icons.receipt_long)),
        title: Text('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} nr ${e.documentNumber.isEmpty ? '—' : e.documentNumber}'),
        subtitle: Text('${formatDate(e.date)} · ${e.amount.toStringAsFixed(2)} lei${e.supplier.isEmpty ? '' : ' · ${e.supplier}'}${e.description == g ? '' : '\n${e.description}'}${e.ocrRawText.isEmpty ? '' : ' · OCR ${(e.ocrConfidence * 100).round()}%'}'),
        isThreeLine: e.description != g,
        trailing: e.confirmed ? const Chip(label: Text('Confirmat')) : isManager ? FilledButton(onPressed: () => _confirmExpense(e), child: const Text('Confirmă')) : const Chip(label: Text('În așteptare')),
      ))));
    }
    return out;
  }

  Future<void> _showExpenseImage(Expense e) async {
    if (!e.hasImage) return;
    Uint8List? bytes;
    try { bytes = base64Decode(e.documentImageBase64); } catch (_) {}
    if (bytes == null) return;
    await showDialog<void>(context: context, builder: (d) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800), child: Column(mainAxisSize: MainAxisSize.min, children: [AppBar(title: Text(e.documentNumber.isEmpty ? 'Document' : e.documentNumber), automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => Navigator.pop(d), icon: const Icon(Icons.close))]), Flexible(child: InteractiveViewer(minScale: .5, maxScale: 5, child: Image.memory(bytes!, fit: BoxFit.contain)))]))));
  }

  Future<void> _confirmExpense(Expense e) async {
    e.confirmed = true;
    try { await widget.saveExpense(e); widget.log('Cheltuială confirmată', e.documentNumber); }
    catch (err) { e.confirmed = false; if (mounted) showErrorMessage(context, 'Confirmarea a eșuat: $err'); }
  }

  Future<void> _pdf() async {
    setState(() => exporting = true);
    try {
      await downloadDecontPdf(team: team, users: widget.users, expenses: widget.expenses, perDiems: widget.perDiems, finance: finance, settlement: settlement, legacyOnly: isLegacy);
      if (mounted) showSuccessMessage(context, 'PDF generat. Descărcarea a fost pornită.');
    } catch (e) { if (mounted) showErrorMessage(context, 'Eroare PDF: $e'); }
    finally { if (mounted) setState(() => exporting = false); }
  }
}




class MessagesContactsPage extends StatefulWidget {
  final List<Location> locations;
  final AppSettings settings;
  final bool canEditContacts;
  final bool canManageTemplates;
  final VoidCallback onChanged;
  final void Function(String,String) log;
  const MessagesContactsPage({super.key,required this.locations,required this.settings,required this.canEditContacts,required this.canManageTemplates,required this.onChanged,required this.log});
  @override State<MessagesContactsPage> createState()=>_MessagesContactsPageState();
}

class _MessagesContactsPageState extends State<MessagesContactsPage>{
  final search=TextEditingController();
  String query='';
  @override void dispose(){search.dispose();super.dispose();}

  Future<void> _call(String phone) async {
    final clean=phone.trim();
    if(clean.isEmpty)return;
    final uri=Uri(scheme:'tel',path:clean);
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)showErrorMessage(context,'Telefonul nu poate deschide apelul pentru $clean.');
  }

  Future<LocationContact?> _contactDialog([LocationContact? existing]) async {
    final name=TextEditingController(text:existing?.name??'');
    final phone=TextEditingController(text:existing?.phone??'');
    var role=(existing?.role.trim().isNotEmpty??false)?existing!.role:'Manager';
    if(!const ['Manager','Casierie','Alt contact'].contains(role))role='Alt contact';
    var smsEnabled=existing?.smsEnabled??true;
    final result=await showDialog<LocationContact>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(existing==null?'Adaugă număr locație':'Editează contact'),
      content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Tip contact'),items:const[
          DropdownMenuItem(value:'Manager',child:Text('Manager')),
          DropdownMenuItem(value:'Casierie',child:Text('Casierie')),
          DropdownMenuItem(value:'Alt contact',child:Text('Alt contact')),
        ],onChanged:(v){if(v!=null)setD(()=>role=v);}),
        const SizedBox(height:8),
        TextField(controller:name,decoration:InputDecoration(labelText:role=='Casierie'?'Nume / denumire (opțional)':'Nume contact')),
        const SizedBox(height:8),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Telefon *')),
        const SizedBox(height:4),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:smsEnabled,onChanged:(v)=>setD(()=>smsEnabled=v),title:const Text('Primește SMS automat'),subtitle:const Text('Dacă este oprit, numărul rămâne disponibil pentru apel, dar nu primește mesajele automate ale graficului.')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:(){
        if(phone.text.trim().isEmpty){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Completează numărul de telefon.')));return;}
        final displayName=name.text.trim().isEmpty?role:name.text.trim();
        Navigator.pop(c,LocationContact(name:displayName,phone:phone.text.trim(),role:role,smsEnabled:smsEnabled));
      },child:const Text('Salvează'))],
    )));
    name.dispose();phone.dispose();return result;
  }

  Future<void> _saveContacts(Location location,List<LocationContact> contacts) async {
    try{
      await FirebaseFirestore.instance.collection('locations').doc(location.id).set({
        'contacts':contacts.map((c)=>{'name':c.name,'phone':c.phone,'role':c.role,'smsEnabled':c.smsEnabled}).toList(),
        'phone':contacts.isEmpty?null:contacts.first.phone,
        'updatedAt':FieldValue.serverTimestamp(),
      },SetOptions(merge:true));
      location.contacts=contacts;
      location.phone=contacts.isEmpty?null:contacts.first.phone;
      widget.onChanged();
      widget.log('Contacte locație modificate',location.name);
      if(mounted)showSuccessMessage(context,'Contactele pentru ${location.name} au fost salvate.');
    }catch(e){if(mounted)showErrorMessage(context,'Contactele nu au putut fi salvate: $e');}
  }

  Future<void> _editLocationContacts(Location location) async {
    if(!widget.canEditContacts)return;
    final work=location.contacts.map((c)=>LocationContact(name:c.name,phone:c.phone,role:c.role,smsEnabled:c.smsEnabled)).toList();
    final save=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(location.name),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(location.address,style:Theme.of(c).textTheme.bodySmall),
        const SizedBox(height:12),
        Row(children:[const Expanded(child:Text('Telefoane locație',style:TextStyle(fontWeight:FontWeight.w800))),FilledButton.tonalIcon(onPressed:()async{final x=await _contactDialog();if(x!=null)setD(()=>work.add(x));},icon:const Icon(Icons.add_call),label:const Text('Adaugă'))]),
        if(work.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('Nu există telefoane salvate.')),
        ...List.generate(work.length,(i){final x=work[i];return ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(backgroundColor:Colors.green.withValues(alpha:.16),child:const Icon(Icons.phone,color:Colors.green)),title:Text('${x.role} · ${x.name}'),subtitle:Text('${x.phone}${x.smsEnabled?' · SMS automat':' · doar apel'}'),trailing:Wrap(spacing:2,children:[IconButton(tooltip:'Sună',onPressed:()=>_call(x.phone),icon:const Icon(Icons.call,color:Colors.green)),IconButton(tooltip:'Editează',onPressed:()async{final next=await _contactDialog(x);if(next!=null)setD(()=>work[i]=next);},icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Șterge',onPressed:()=>setD(()=>work.removeAt(i)),icon:const Icon(Icons.delete_outline))]));}),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvează'))],
    )))??false;
    if(save)await _saveContacts(location,work);
  }

  Future<void> _editTemplates() async {
    if(!widget.canManageTemplates)return;
    final initial=TextEditingController(text:widget.settings.smsTemplates['initial']??'');
    final rescheduled=TextEditingController(text:widget.settings.smsTemplates['rescheduled']??'');
    final postponed=TextEditingController(text:widget.settings.smsTemplates['postponed']??'');
    final save=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Șabloane SMS automate'),
      content:SizedBox(width:760,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _InfoCard(icon:Icons.data_object,title:'Variabile disponibile',text:'Folosește [data exactă] pentru data programată și [locație] dacă vrei să incluzi numele sălii. Mesajul inițial se trimite în ziua calendaristică anterioară intervenției, la ora ${widget.settings.smsPreviousDayTime} setată de Admin.'),
        const SizedBox(height:10),
        TextField(controller:initial,minLines:3,maxLines:6,decoration:InputDecoration(labelText:'Mesaj inițial · ziua precedentă la ${widget.settings.smsPreviousDayTime}')),
        const SizedBox(height:10),
        TextField(controller:rescheduled,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Mesaj reprogramare pe altă dată')),
        const SizedBox(height:10),
        TextField(controller:postponed,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Mesaj amânare')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvează'))],
    ))??false;
    if(save){
      widget.settings.smsTemplates['initial']=initial.text.trim();
      widget.settings.smsTemplates['rescheduled']=rescheduled.text.trim();
      widget.settings.smsTemplates['postponed']=postponed.text.trim();
      try{
        await FirebaseFirestore.instance.collection('meta').doc('uiSettings').set({'smsTemplates':widget.settings.smsTemplates,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
        widget.log('Șabloane SMS modificate','Mesaje automate locații');
        widget.onChanged();
        if(mounted)showSuccessMessage(context,'Șabloanele SMS au fost salvate.');
      }catch(e){if(mounted)showErrorMessage(context,'Șabloanele nu au putut fi salvate: $e');}
    }
    initial.dispose();rescheduled.dispose();postponed.dispose();
  }

  @override Widget build(BuildContext context){
    final needle=query.trim().toLowerCase();
    final list=widget.locations.where((l){if(!l.active)return false;if(needle.isEmpty)return true;return '${l.name} ${l.address} ${l.contacts.map((e)=>'${e.name} ${e.phone} ${e.role}').join(' ')}'.toLowerCase().contains(needle);}).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _Page(title:'Mesaje & Contacte',subtitle:'Telefoane locații și mesaje automate Andi Carpet',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:TextField(controller:search,onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Caută locație, contact sau număr'))),if(widget.canManageTemplates)...[const SizedBox(width:8),FilledButton.tonalIcon(onPressed:_editTemplates,icon:const Icon(Icons.sms_outlined),label:const Text('Șabloane mesaje'))]]),
      const SizedBox(height:10),
      const _InfoCard(icon:Icons.info_outline,title:'Acces rapid',text:'Butonul verde apelează direct numărul. Contactele marcate „SMS automat” sunt cele folosite de gateway-ul Android când un grafic intră în condițiile de notificare. Editarea este controlată prin drepturile funcției.'),
      const SizedBox(height:10),
      if(list.isEmpty)const _Empty(icon:Icons.contact_phone_outlined,text:'Nu există locații pentru căutarea curentă.'),
      ...list.map((l)=>Card(child:ExpansionTile(
        leading:const CircleAvatar(backgroundColor:Color(0x1A00A86B),child:Icon(Icons.store_mall_directory_outlined,color:Colors.green)),
        title:Text(l.name,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text(l.address,maxLines:2,overflow:TextOverflow.ellipsis),
        trailing:widget.canEditContacts?IconButton(tooltip:'Editează telefoanele',onPressed:()=>_editLocationContacts(l),icon:const Icon(Icons.edit_outlined)):null,
        children:[
          if(l.contacts.isEmpty)const ListTile(title:Text('Niciun telefon salvat.')),
          ...l.contacts.map((c)=>ListTile(leading:const CircleAvatar(backgroundColor:Color(0x1A00A86B),child:Icon(Icons.phone,color:Colors.green)),title:Text('${c.role} · ${c.name}'),subtitle:Text('${c.phone}${c.smsEnabled?' · SMS automat':' · doar apel'}'),trailing:IconButton(style:IconButton.styleFrom(backgroundColor:Colors.green,foregroundColor:Colors.white),tooltip:'Sună ${c.phone}',onPressed:()=>_call(c.phone),icon:const Icon(Icons.call)))),
        ],
      ))),
    ]));
  }
}


class AppInformationPage extends StatelessWidget {
  final AppSettings settings;
  final bool isAdmin;
  const AppInformationPage({super.key,required this.settings,this.isAdmin=false});

  Widget _section(BuildContext context,String title,String text,{IconData icon=Icons.info_outline})=>Card(
    child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,color:Theme.of(context).colorScheme.primary),const SizedBox(width:9),Expanded(child:Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)))]),
      const SizedBox(height:8),Text(text,style:const TextStyle(height:1.35)),
    ])),
  );

  static const List<Map<String,String>> _builtInHistory=<Map<String,String>>[
    {'version':'3.0.0+32','title':'Finalizare v3.0.0 · mesaje automate și curățare','summary':'Mesajul automat inițial către locații se trimite în ziua calendaristică precedentă intervenției, la ora configurată de Admin (implicit 10:00), în loc de 24 de ore înainte. Data modificată anulează programarea veche înainte de trimitere.'},
    {'version':'3.0.0+31','title':'Interfață unificată, badge-uri și stickere BRC','summary':'Iconuri vizuale consistente în Dashboard, Admin Panel și navigare, badge-uri refăcute complet și previzualizare mărită la hover/tap, plus un set nou de stickere BRC disponibile în chatul comun și conversațiile private.'},
    {'version':'2.0.10+30','title':'Ecusoane premium, Chat comun și profil extins','summary':'Ecusoane semi-3D mari cu contur în culoarea funcției, ștergerea funcțiilor cu eliminare automată de la membri, Chat live comun deschis direct cu istoric limitat și retenție scurtă, plus vizualizare mărită/zoom pentru pozele de profil.'},
    {'version':'2.0.9+29','title':'Profil, Setări, Chat live și Despre','summary':'Schimbarea rapidă între conturi reîncarcă acum complet identitatea și drepturile. Profilul a fost separat de Setări, au fost adăugate statistici de angajat, poreclă pentru afișarea internă, funcție conform CIM și câmpuri/linkuri suplimentare. Chat live are acces direct și emoticoane Andi. Pagina Despre include capacitățile aplicației și istoricul update-urilor. Au fost pregătite și butoanele de instalare Android/Apple.'},
    {'version':'2.0.8+28','title':'Branding, fațade, Centralizator și Decont compact','summary':'Branding global cu logo-uri și fundaluri tematice, SMS cu data exactă a intervenției, fațadă planificată/realizată, Centralizator PDF grupat pe locație și Decont tabelar. OCR-ul păstrează doar datele structurate, nu fotografia bonului/facturii. Au fost adăugate Calcule generale anual/all-time și desfășurătorul sumelor primite.'},
    {'version':'2.0.7+27','title':'Web, conturi și fonturi','summary':'Corecții pentru geocodarea punctelor de plecare/sosire pe Web, începutul sistemului de comutare rapidă între două conturi, ascunderea contului Admin și refacerea selecției de font.'},
    {'version':'2.0.6+26','title':'Stabilizare pornire Android','summary':'Hotfix pentru crash-ul de startup WorkManager/Room produs de optimizarea R8 în release. Build-ul Android a fost stabilizat pentru utilizarea internă.'},
    {'version':'2.0.5+25','title':'Detectarea sosirii și Android release','summary':'Detectare asistată a sosirii lângă locația programată, întrebare înainte de începerea lucrului, strategie GPS economic/high accuracy și corecții pentru build-ul Android release.'},
    {'version':'2.0.4+23','title':'SMS manageri prin telefonul Android','summary':'Gateway SMS folosind SIM-ul telefonului Android, contacte de locație, mesaje automate înainte de intervenție, actualizări la reprogramare/amânare și protecție anti-dubluri.'},
    {'version':'2.0.3+22','title':'Traseu complet și Dashboard locație','summary':'Punct de plecare și punct final/retur la START, calcul complet al kilometrilor/consumului/timpului și afișarea inteligibilă a locației membrilor fără coordonate brute.'},
    {'version':'2.0.2+21','title':'Push automat și PWA','summary':'Înregistrarea automată a dispozitivului pentru notificări push și îmbunătățiri pentru experiența de instalare/utilizare PWA.'},
    {'version':'2.0.1+20','title':'Compatibilitate Web','summary':'Corecții de compilare Web pentru setările native și API-ul File Picker.'},
    {'version':'2.0.0','title':'Pachet funcțional complet','summary':'Integrarea într-un singur proiect a Learning-ului, Dashboard-ului, rutării, hărții, Centralizatorului, Decontului, OCR-ului, notificărilor și pregătirii multiplatformă.'},
    {'version':'1.9.0','title':'Localizare nativă și autentificare','summary':'Extinderea localizării pe Android/iOS și autentificare cu email, username sau telefon.'},
    {'version':'1.8.0','title':'Vizual, PDF și fundaluri','summary':'Îmbunătățiri de interfață, export PDF, branding și fundaluri.'},
    {'version':'1.7.0','title':'Dashboard și Learning extins','summary':'Dashboard operațional, explicații și indicatori Learning, estimări și istoric.'},
    {'version':'1.6.0','title':'Learning core','summary':'Baza sistemului Learning: istoric de execuție, durate, rutare, motive și reguli de încredere.'},
    {'version':'1.5.x','title':'Fundația aplicației conectate','summary':'Firebase, conturi, echipe, grafice, hartă, centralizator, decont, chat și primele notificări.'},
  ];

  Future<void> _addManualHistory(BuildContext context) async {
    if(!isAdmin)return;
    final version=TextEditingController();
    final title=TextEditingController();
    final summary=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Adaugă în istoricul update-urilor'),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:version,decoration:const InputDecoration(labelText:'Versiune',hintText:'ex: 2.0.10+30')),
        const SizedBox(height:10),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Titlu update')),
        const SizedBox(height:10),
        TextField(controller:summary,minLines:4,maxLines:8,decoration:const InputDecoration(labelText:'Ce s-a adăugat / modificat')),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:(){if(version.text.trim().isNotEmpty&&summary.text.trim().isNotEmpty)Navigator.pop(c,true);},child:const Text('Salvează'))],
    ))??false;
    if(ok){
      try{
        await FirebaseFirestore.instance.collection('updateHistory').add({
          'version':version.text.trim(),'title':title.text.trim(),'summary':summary.text.trim(),
          'createdAt':FieldValue.serverTimestamp(),'createdBy':FirebaseAuth.instance.currentUser?.uid??'',
        });
        if(context.mounted)showSuccessMessage(context,'Intrarea a fost adăugată în istoricul update-urilor.');
      }catch(e){if(context.mounted)showErrorMessage(context,'Istoricul nu a putut fi salvat: $e');}
    }
    version.dispose();title.dispose();summary.dispose();
  }

  Widget _capabilities(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[
    _section(context,'Operațiuni zilnice și Dashboard','Dashboard-ul arată ziua de lucru, echipele active, progresul pe locații, intervenția curentă, stările de așteptare/refuz/nerealizat și estimarea de final când există suficiente date. Poți porni și opri programul, urmări progresul și vedea rapid ce a rămas de făcut.',icon:Icons.dashboard_outlined),
    _section(context,'Grafice de lucru și trasee','Poți crea grafice pe una sau mai multe zile, adăuga locații, ordona intervențiile, planifica fațade și porni traseul de la un punct ales până la punctul final/retur. Aplicația calculează distanțe, timp estimat, consum și cost de combustibil și poate recalcula traseul rămas când apar întârzieri sau schimbări.',icon:Icons.route_outlined),
    _section(context,'Execuție în locație','Pentru fiecare sală pot fi înregistrate START/STOP, așteptarea pentru acces, refuzul, nerealizarea și motivul. La final se confirmă obligatoriu dacă fațada a fost realizată atunci când modulul de fațade este folosit. Evenimentele intră în istoric și pot alimenta Learning-ul.',icon:Icons.play_circle_outline),
    _section(context,'Hartă, GPS și detectarea sosirii','Harta păstrează locațiile firmei, coordonatele lor și pozițiile live ale echipelor. Localizarea poate funcționa economic sau cu precizie ridicată, iar aplicația crește temporar precizia când te apropii de următoarea locație. La sosire poate întreba dacă începi lucrul, ești în așteptare sau nu încă.',icon:Icons.map_outlined),
    _section(context,'Centralizator și documente PDF','Intervențiile sunt centralizate pe locație și dată, cu ore, suprafață și fațadă. Exportul PDF este tabelar și compact: aceeași locație nu se repetă inutil, iar intervențiile ei sunt grupate cronologic pentru printare cu cât mai puține pagini.',icon:Icons.table_chart_outlined),
    _section(context,'Decont, OCR și calcule financiare','Bonurile și facturile pot fi scanate cu OCR. Aplicația extrage numărul, data și valoarea, clasifică documentele în combustibil/facturi/alte cheltuieli și nu păstrează fotografia scanată. Decontul include diurne, sume primite, buget rămas, sumă de recuperat și rapoarte anuale sau totale prin Calcule generale.',icon:Icons.receipt_long_outlined),
    _section(context,'Learning și estimări','Learning-ul folosește execuțiile reale, timpii, așteptările, refuzurile, ordinea aleasă, întârzierile și schimbările de traseu pentru a îmbunătăți estimările. Pentru o locație sunt necesare minimum trei execuții utile înainte ca istoricul ei să fie folosit pentru ordine și durate automate.',icon:Icons.psychology_alt_outlined),
    _section(context,'Mesaje, Chat live și notificări','Aplicația are Chat live comun pentru toți membrii, cu istoric scurt pentru economie de Firestore, mesaje necitite și emoticoane Andi. Mesajele private rămân disponibile separat din profilul membrului. Contactele managerilor/casieriei sunt legate de locații și pot fi apelate direct. Mesajele SMS automate către locații folosesc data exactă a intervenției și pot fi trimise prin telefonul Android folosit ca gateway.',icon:Icons.forum_outlined),
    _section(context,'Profil și statistici de angajat','Profilul poate conține nume, poreclă folosită în afișarea internă, telefon, data angajării, funcția din contract și câmpuri suplimentare inclusiv linkuri sociale. Statisticile personale arată perioada de angajare, zilele și orele de lucru asociate echipei și diurnele încasate.',icon:Icons.badge_outlined),
    _section(context,'Web, Android și iPhone/iPad','Aceeași aplicație poate fi folosită în browser, instalată ca APK pe Android sau adăugată pe ecranul principal din Safari pe iPhone/iPad. Datele operaționale sunt sincronizate prin Firebase între dispozitive.',icon:Icons.devices_outlined),
  ]);

  Widget _history(BuildContext context)=>Column(children:[
    if(isAdmin)Padding(padding:const EdgeInsets.fromLTRB(14,12,14,0),child:Align(alignment:Alignment.centerRight,child:FilledButton.tonalIcon(onPressed:()=>_addManualHistory(context),icon:const Icon(Icons.add),label:const Text('Adaugă manual')))),
    Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('updateHistory').orderBy('createdAt',descending:true).snapshots(),
      builder:(context,snap){
        final manual=snap.data?.docs??<QueryDocumentSnapshot<Map<String,dynamic>>>[];
        return ListView(padding:const EdgeInsets.all(14),children:[
          if(manual.isNotEmpty)...[
            const Text('Adăugate manual',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            ...manual.map((doc){final d=doc.data();final raw=d['createdAt'];final dt=raw is Timestamp?raw.toDate():null;return Card(child:ListTile(
              leading:const Icon(Icons.new_releases_outlined),
              title:Text('${(d['version']??'Versiune').toString()}${(d['title']??'').toString().trim().isEmpty?'':' · ${(d['title']??'').toString()}'}',style:const TextStyle(fontWeight:FontWeight.w900)),
              subtitle:Text('${(d['summary']??'').toString()}${dt==null?'':'\n${formatDate(dt)}'}'),isThreeLine:true,
            ));}),
            const SizedBox(height:12),
          ],
          const Text('Istoric inclus în aplicație',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          ..._builtInHistory.map((e)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${e['version']} · ${e['title']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:5),Text(e['summary']??'',style:const TextStyle(height:1.3)),
          ])))),
        ]);
      },
    )),
  ]);

  @override Widget build(BuildContext context)=>DefaultTabController(length:2,child:Scaffold(
    body:_AppBackdrop(settings:settings,child:SafeArea(child:Column(children:[
      Material(color:Theme.of(context).colorScheme.surface.withValues(alpha:.96),child:Column(children:[
        Row(children:[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back)),const Expanded(child:Text('Despre Andi Carpetă',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),Padding(padding:const EdgeInsets.only(right:12),child:Text('v$_appVersionLabel'))]),
        const TabBar(tabs:[Tab(icon:Icon(Icons.auto_awesome_outlined),text:'Capacități'),Tab(icon:Icon(Icons.history),text:'Istoric update')]),
      ])),
      Expanded(child:TabBarView(children:[_capabilities(context),_history(context)])),
    ]))),
  ));
}

class ProfilePage extends StatefulWidget {
  final AppUser user;
  final List<Team> teams;
  final List<FunctionDefinition> functionDefinitions;
  final List<CentralizerRecord> records;
  final List<PerDiemEntry> perDiems;
  const ProfilePage({super.key,required this.user,required this.teams,required this.functionDefinitions,required this.records,required this.perDiems});
  @override State<ProfilePage> createState()=>_ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>{
  Uint8List? _photoFromData(String? value){if(value==null||value.isEmpty)return null;try{return base64Decode(value);}catch(_){return null;}}
  Future<String?> _pickProfilePhoto()async{
    try{
      final picked=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1600,imageQuality:92);
      if(picked==null)return null;
      final bytes=await picked.readAsBytes();final source=img.decodeImage(bytes);if(source==null)return null;
      final square=img.copyResizeCropSquare(source,size:320);return base64Encode(img.encodeJpg(square,quality:82));
    }catch(e){if(mounted)showErrorMessage(context,'Poza nu a putut fi selectată: $e');return null;}
  }
  DateTime? _dateFromRaw(Object? raw){if(raw is Timestamp)return raw.toDate();if(raw is DateTime)return raw;if(raw is String)return DateTime.tryParse(raw);return null;}
  int _daysInMonth(int year,int month)=>DateTime(year,month+1,0).day;
  ({int years,int months,int days,int totalDays}) _employmentParts(DateTime start){
    final now=DateTime.now();
    if(start.isAfter(now))return (years:0,months:0,days:0,totalDays:0);
    var totalMonths=(now.year-start.year)*12+(now.month-start.month);
    DateTime anchorFor(int months){final y=start.year+((start.month-1+months)~/12);final m=((start.month-1+months)%12)+1;final d=math.min(start.day,_daysInMonth(y,m));return DateTime(y,m,d);}
    var anchor=anchorFor(totalMonths);if(anchor.isAfter(now)){totalMonths--;anchor=anchorFor(totalMonths);}
    return (years:totalMonths~/12,months:totalMonths%12,days:now.difference(anchor).inDays,totalDays:now.difference(start).inDays);
  }
  double _hours(Iterable<CentralizerRecord> rows)=>rows.fold<double>(0,(sum,r)=>sum+(r.duration?.inMinutes??0)/60.0);
  String _hoursText(double v)=>'${v.toStringAsFixed(v>=10?1:2)} h';
  Set<String> _workedDayKeys(Iterable<CentralizerRecord> rows)=>rows.map((r){final d=r.startedAt??r.finishedAt!;return '${d.year}-${two(d.month)}-${two(d.day)}';}).toSet();

  Future<void> _openLink(String raw)async{
    final text=raw.trim();if(text.isEmpty)return;
    final normalized=RegExp(r'^https?://',caseSensitive:false).hasMatch(text)?text:'https://$text';
    final uri=Uri.tryParse(normalized);
    if(uri==null||!await launchUrl(uri,mode:LaunchMode.externalApplication)){
      await Clipboard.setData(ClipboardData(text:text));if(mounted)showErrorMessage(context,'Linkul nu a putut fi deschis. A fost copiat.');
    }
  }

  Future<void> _editProfile(Map<String,dynamic> d)async{
    final name=TextEditingController(text:(d['name']??'').toString());
    final nickname=TextEditingController(text:(d['nickname']??'').toString());
    final phone=TextEditingController(text:(d['phone']??'').toString());
    final contractFunction=TextEditingController(text:(d['contractFunction']??'').toString());
    var useNickname=d['useNickname']==true;
    var hireDate=_dateFromRaw(d['hireDate']);
    var photo=(d['photoBase64']??'').toString();
    final fields=<Map<String,dynamic>>[];
    final rawFields=d['profileFields'];
    if(rawFields is List){for(final raw in rawFields){if(raw is Map){fields.add({'label':TextEditingController(text:(raw['label']??'').toString()),'value':TextEditingController(text:(raw['value']??'').toString()),'type':(raw['type']??'text').toString()=='link'?'link':'text'});}}}
    final saved=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:const Text('Editează profilul'),
      content:SizedBox(width:680,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Center(child:Column(children:[CircleAvatar(radius:50,backgroundImage:_photoFromData(photo)==null?null:MemoryImage(_photoFromData(photo)!),child:_photoFromData(photo)==null?const Icon(Icons.person,size:48):null),const SizedBox(height:8),Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()async{final p=await _pickProfilePhoto();if(p!=null)setD(()=>photo=p);},icon:const Icon(Icons.photo_camera_outlined),label:const Text('Poză profil')),if(photo.isNotEmpty)TextButton.icon(onPressed:()=>setD(()=>photo=''),icon:const Icon(Icons.delete_outline),label:const Text('Elimină'))])])),
        const SizedBox(height:14),
        TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Nume și prenume')),
        const SizedBox(height:10),
        TextField(controller:nickname,decoration:const InputDecoration(labelText:'Poreclă',hintText:'Ex.: Timi')),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:useNickname,onChanged:(v)=>setD(()=>useNickname=v==true),title:const Text('Folosește porecla în grafice, chat și afișarea internă'),subtitle:const Text('Numele complet rămâne salvat în profil.')),
        const SizedBox(height:6),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Număr telefon')),
        const SizedBox(height:10),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month_outlined),title:const Text('Data angajării'),subtitle:Text(hireDate==null?'Nesetată':formatDate(hireDate!)),trailing:OutlinedButton(onPressed:()async{final now=DateTime.now();final picked=await showDatePicker(context:c,initialDate:hireDate??DateTime(now.year,now.month,now.day),firstDate:DateTime(1990),lastDate:DateTime(now.year+1));if(picked!=null)setD(()=>hireDate=picked);},child:const Text('Alege'))),
        const SizedBox(height:6),
        TextField(controller:contractFunction,decoration:const InputDecoration(labelText:'Funcție conform contractului individual de muncă',hintText:'Ex.: Operator curățenie')),
        const Divider(height:28),
        Row(children:[const Expanded(child:Text('Alte informații',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900))),OutlinedButton.icon(onPressed:()=>setD(()=>fields.add({'label':TextEditingController(),'value':TextEditingController(),'type':'text'})),icon:const Icon(Icons.add),label:const Text('Adaugă câmp'))]),
        const SizedBox(height:6),
        const Text('Poți adăuga orice câmp. Pentru Facebook, TikTok sau alte pagini alege tipul Link; valoarea va putea fi deschisă direct din profil.'),
        const SizedBox(height:10),
        ...List.generate(fields.length,(i){final f=fields[i];return Padding(padding:const EdgeInsets.only(bottom:9),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(flex:2,child:TextField(controller:f['label'] as TextEditingController,decoration:const InputDecoration(labelText:'Denumire',hintText:'Ex.: Facebook'))),const SizedBox(width:8),
          Expanded(flex:3,child:TextField(controller:f['value'] as TextEditingController,decoration:InputDecoration(labelText:f['type']=='link'?'Link':'Valoare',hintText:f['type']=='link'?'https://...':'Text'))),const SizedBox(width:8),
          SizedBox(width:110,child:DropdownButtonFormField<String>(value:f['type'] as String,decoration:const InputDecoration(labelText:'Tip'),items:const[DropdownMenuItem(value:'text',child:Text('Text')),DropdownMenuItem(value:'link',child:Text('Link'))],onChanged:(v){if(v!=null)setD(()=>f['type']=v);})),
          IconButton(tooltip:'Șterge',onPressed:()=>setD(()=>fields.removeAt(i)),icon:const Icon(Icons.remove_circle_outline)),
        ]));}),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvează'))],
    )))??false;
    if(saved){
      final out=<Map<String,String>>[];
      for(final f in fields){final label=(f['label'] as TextEditingController).text.trim();final value=(f['value'] as TextEditingController).text.trim();if(label.isNotEmpty||value.isNotEmpty)out.add({'label':label,'value':value,'type':f['type'] as String});}
      try{
        await FirebaseFirestore.instance.collection('users').doc(widget.user.id).set({
          'name':name.text.trim(),'nickname':nickname.text.trim(),'useNickname':useNickname,'phone':phone.text.trim(),'phoneNormalized':phone.text.replaceAll(RegExp(r'[^0-9]'),''),
          'hireDate':hireDate==null?null:Timestamp.fromDate(hireDate!),'contractFunction':contractFunction.text.trim(),'photoBase64':photo,'profileFields':out,'updatedAt':FieldValue.serverTimestamp(),
        },SetOptions(merge:true));
        if(mounted)showSuccessMessage(context,'Profilul a fost actualizat.');
      }catch(e){if(mounted)showErrorMessage(context,'Profilul nu a putut fi salvat: $e');}
    }
    name.dispose();nickname.dispose();phone.dispose();contractFunction.dispose();
    for(final f in fields){(f['label'] as TextEditingController).dispose();(f['value'] as TextEditingController).dispose();}
  }

  Widget _statCard(BuildContext context,String title,String value,IconData icon)=>SizedBox(width:210,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:Theme.of(context).colorScheme.primary),const SizedBox(height:8),Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(title)]))));

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Profil')),body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('users').doc(widget.user.id).snapshots(),
    builder:(context,snap){
      final d=snap.data?.data()??<String,dynamic>{};final display=_profileDisplayName(d,fallback:widget.user.name);final photo=_photoFromData((d['photoBase64']??'').toString());
      final hire=_dateFromRaw(d['hireDate']);final employment=hire==null?null:_employmentParts(hire);
      final teamId=widget.user.teamId;final completed=widget.records.where((r)=>teamId!=null&&r.teamId==teamId&&r.completed).toList();final now=DateTime.now();
      final today=completed.where((r){final x=r.startedAt??r.finishedAt;return x!=null&&sameDay(x,now);}).toList();
      final month=completed.where((r){final x=r.startedAt??r.finishedAt;return x!=null&&x.year==now.year&&x.month==now.month;}).toList();
      final year=completed.where((r){final x=r.startedAt??r.finishedAt;return x!=null&&x.year==now.year;}).toList();
      final myPer=widget.perDiems.where((x)=>x.memberId==widget.user.id&&(x.received==true||x.status==PerDiemStatus.confirmed)).toList();
      final perMonth=myPer.where((x)=>x.date.year==now.year&&x.date.month==now.month).fold<double>(0,(a,b)=>a+b.amount);final perYear=myPer.where((x)=>x.date.year==now.year).fold<double>(0,(a,b)=>a+b.amount);final perAll=myPer.fold<double>(0,(a,b)=>a+b.amount);
      final rawFields=d['profileFields'];final fields=<Map<String,String>>[];if(rawFields is List){for(final raw in rawFields){if(raw is Map){final label=(raw['label']??'').toString().trim();final value=(raw['value']??'').toString().trim();final type=(raw['type']??'text').toString();if(label.isNotEmpty||value.isNotEmpty)fields.add({'label':label,'value':value,'type':type});}}}
      return ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          GestureDetector(
            onTap:photo==null?null:()=>showProfilePhotoViewer(context,(d['photoBase64']??'').toString(),display),
            child:CircleAvatar(radius:48,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person,size:46):null),
          ),const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(display,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),if((d['nickname']??'').toString().trim().isNotEmpty&&display!=(d['name']??'').toString())Text((d['name']??'').toString()),if((d['contractFunction']??'').toString().trim().isNotEmpty)Text((d['contractFunction']??'').toString()),Text(widget.user.email,style:Theme.of(context).textTheme.bodySmall),if((d['phone']??'').toString().trim().isNotEmpty)Text((d['phone']??'').toString()),if(widget.user.functionIds.isNotEmpty)...[const SizedBox(height:8),memberBadgeStripWidget(widget.functionDefinitions,widget.user.functionIds,size:40)]])),
          FilledButton.tonalIcon(onPressed:()=>_editProfile(d),icon:const Icon(Icons.edit_outlined),label:const Text('Editează')),
        ]))),
        if(fields.isNotEmpty)...[const SizedBox(height:10),Card(child:Column(children:fields.map((f){final link=f['type']=='link';return ListTile(leading:Icon(link?Icons.link:Icons.info_outline),title:Text(f['label']!.isEmpty?'Informație':f['label']!),subtitle:Text(f['value']??''),trailing:link?const Icon(Icons.open_in_new):null,onTap:link?()=>_openLink(f['value']??''):null);}).toList()))],
        const SizedBox(height:12),
        Text('Statistici angajat',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:8),
        if(employment==null)const _InfoCard(icon:Icons.event_outlined,title:'Perioada de angajare',text:'Completează data angajării din Editare profil pentru calculul perioadei.')
        else _InfoCard(icon:Icons.event_available_outlined,title:'Perioada de angajare',text:'${employment.years} ani · ${employment.months} luni · ${employment.days} zile  |  ${employment.totalDays} zile calendaristice de la angajare'),
        const SizedBox(height:8),
        Wrap(spacing:10,runSpacing:10,children:[
          _statCard(context,'Zile lucrate luna curentă','${_workedDayKeys(month).length}',Icons.calendar_view_month),
          _statCard(context,'Zile lucrate anul curent','${_workedDayKeys(year).length}',Icons.calendar_today_outlined),
          _statCard(context,'Ore lucrate azi',_hoursText(_hours(today)),Icons.schedule),
          _statCard(context,'Ore lucrate luna curentă',_hoursText(_hours(month)),Icons.more_time),
          _statCard(context,'Ore lucrate anul curent',_hoursText(_hours(year)),Icons.access_time_filled),
        ]),
        const SizedBox(height:10),
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Diurne încasate',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Luna curentă: ${perMonth.toStringAsFixed(2)} lei'),Text('Anul curent: ${perYear.toStringAsFixed(2)} lei'),Text('Total: ${perAll.toStringAsFixed(2)} lei')]))),
        const SizedBox(height:8),
        Text('Notă: orele și zilele de lucru sunt calculate din intervențiile finalizate ale echipei la care este alocat contul.',style:Theme.of(context).textTheme.bodySmall),
      ]);
    },
  ));
}

class SettingsPage extends StatefulWidget {
  final AppUser user;
  final List<AppNotification> notifications;
  final AppSettings settings;
  final VoidCallback onChanged;
  final VoidCallback onThemeChanged;
  final VoidCallback? onAdmin;
  final VoidCallback onLogout;
  const SettingsPage({super.key,required this.user,required this.notifications,required this.settings,required this.onChanged,required this.onThemeChanged,required this.onAdmin,required this.onLogout});
  @override State<SettingsPage> createState()=>_SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>{
  List<_QuickAccount> _quickAccounts=<_QuickAccount>[];bool _quickAccountsLoading=true;bool _quickAccountBusy=false;
  @override void initState(){super.initState();unawaited(_refreshQuickAccounts());}
  String _themeLabel(AppThemeChoice v)=>switch(v){AppThemeChoice.light=>'Luminos',AppThemeChoice.dark=>'Întunecat',AppThemeChoice.system=>'Sistem'};
  Future<void> _refreshQuickAccounts()async{try{final x=await _loadQuickAccounts();if(mounted)setState((){_quickAccounts=x;_quickAccountsLoading=false;});}catch(e){if(mounted){setState(()=>_quickAccountsLoading=false);showErrorMessage(context,'Nu pot citi conturile memorate din stocarea securizată: $e');}}}
  Future<void> _updateOwn(Map<String,dynamic> data,{String? success})async{try{await FirebaseFirestore.instance.collection('users').doc(widget.user.id).set({...data,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));if(success!=null&&mounted)showSuccessMessage(context,success);}catch(e){if(mounted)showErrorMessage(context,'Nu s-a putut salva: $e');}}
  Future<void> _rememberCurrentQuickAccount()async{
    final authUser=FirebaseAuth.instance.currentUser;final mail=(authUser?.email??widget.user.email).trim();if(authUser==null||mail.isEmpty||_quickAccountBusy)return;
    final controller=TextEditingController();final pass=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Memorează contul'),content:TextField(controller:controller,obscureText:true,decoration:InputDecoration(labelText:'Parola pentru $mail')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text),child:const Text('Memorează'))]));controller.dispose();if(pass==null||pass.isEmpty)return;
    setState(()=>_quickAccountBusy=true);try{final credential = EmailAuthProvider.credential(email:mail,password:pass);await authUser.reauthenticateWithCredential(credential);final a=await _loadQuickAccounts();a.removeWhere((x)=>x.email.toLowerCase()==mail.toLowerCase());while(a.length>=2){a.removeAt(0);}a.add(_QuickAccount(email:mail,password:pass));await _saveQuickAccounts(a);if(mounted)setState(()=>_quickAccounts=a);}on FirebaseAuthException catch(e){if(mounted)showErrorMessage(context,'Autentificare nereușită: ${e.message ?? e.code}');}catch(e){if(mounted)showErrorMessage(context,'Salvarea locală a contului a eșuat: $e');}finally{if(mounted)setState(()=>_quickAccountBusy=false);}
  }
  Future<void> _switchQuickAccount(_QuickAccount account)async{if(_quickAccountBusy)return;setState(()=>_quickAccountBusy=true);try{await FirebaseAuth.instance.signInWithEmailAndPassword(email:account.email,password:account.password);if(mounted)showSuccessMessage(context,'Cont schimbat pe ${account.email}.');}catch(e){if(mounted)showErrorMessage(context,'Nu am putut schimba contul. Memorează din nou parola dacă a fost schimbată.');}finally{if(mounted)setState(()=>_quickAccountBusy=false);}}
  Future<void> _forgetQuickAccounts()async{try{await _quickAccountStorage.delete(key:_quickAccountsStorageKey);if(mounted)setState(()=>_quickAccounts=<_QuickAccount>[]);}catch(_){if(mounted)showErrorMessage(context,'Nu am putut șterge conturile salvate din spațiul securizat al dispozitivului.');}}

  Map<String,bool> _prefs(Map<String,dynamic> d){final raw=d['notificationPreferences'];final m=<String,bool>{'chat':true,'schedule':true,'arrival':true,'decont':true,'learning':true,'general':true};if(raw is Map){for(final k in m.keys){if(raw[k] is bool)m[k]=raw[k] as bool;}}return m;}
  Future<void> _setPref(Map<String,bool> prefs,String key,bool value)async{prefs[key]=value;setState((){});await _updateOwn({'notificationPreferences':prefs},success:'Preferința de notificare a fost salvată.');}

  @override Widget build(BuildContext context)=>StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').doc(widget.user.id).snapshots(),builder:(context,snap){
    final d=snap.data?.data()??<String,dynamic>{};final locationMode=(d['locationMode']??'economic').toString();final interval=(d['locationIntervalMinutes'] is num)?(d['locationIntervalMinutes'] as num).toInt().clamp(1,60).toInt():10;final prefs=_prefs(d);
    final mine=widget.notifications.where((n)=>n.userId==widget.user.id).toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt));final unread=mine.where((n)=>!n.read).toList();
    return _Page(title:'Setări',subtitle:'Preferințe personale și cont',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Aspect',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        DropdownButtonFormField<AppThemeChoice>(value:widget.settings.theme,decoration:const InputDecoration(labelText:'Temă'),items:AppThemeChoice.values.map((v)=>DropdownMenuItem(value:v,child:Text(_themeLabel(v)))).toList(),onChanged:(v)async{if(v==null)return;setState(()=>widget.settings.theme=v);widget.onThemeChanged();await _updateOwn({'theme':v.name});}),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:_normalizeFontChoice(widget.settings.fontFamily),decoration:const InputDecoration(labelText:'Font'),items:const[DropdownMenuItem(value:'System',child:Text('System')),DropdownMenuItem(value:'Sans',child:Text('Sans')),DropdownMenuItem(value:'Serif',child:Text('Serif')),DropdownMenuItem(value:'Monospace',child:Text('Monospace')),DropdownMenuItem(value:'Cursive',child:Text('Cursive'))],onChanged:(v)async{if(v==null)return;setState(()=>widget.settings.fontFamily=v);widget.onThemeChanged();await _updateOwn({'fontFamily':v});}),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Notificări',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:4),const Text('Poți opri categoriile opționale. Mesajele trimise de Admin și notificările importante de sistem rămân active.'),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['chat']!,onChanged:(v)=>_setPref(prefs,'chat',v),title:const Text('Chat live')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['schedule']!,onChanged:(v)=>_setPref(prefs,'schedule',v),title:const Text('Grafic și traseu')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['arrival']!,onChanged:(v)=>_setPref(prefs,'arrival',v),title:const Text('Sosire și locație')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['decont']!,onChanged:(v)=>_setPref(prefs,'decont',v),title:const Text('Decont și diurne')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['learning']!,onChanged:(v)=>_setPref(prefs,'learning',v),title:const Text('Learning și recomandări')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:prefs['general']!,onChanged:(v)=>_setPref(prefs,'general',v),title:const Text('Alte notificări operaționale')),
        const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.lock_outline),title:Text('Admin & Sistem'),subtitle:Text('Întotdeauna active'),trailing:Icon(Icons.check_circle,color:Colors.green)),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Locație',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),
        DropdownButtonFormField<String>(value:['live','economic','offline'].contains(locationMode)?locationMode:'economic',decoration:const InputDecoration(labelText:'Mod locație'),items:const[DropdownMenuItem(value:'live',child:Text('Live · precizie mai mare')),DropdownMenuItem(value:'economic',child:Text('Economic')),DropdownMenuItem(value:'offline',child:Text('Offline în afara programului'))],onChanged:(v)async{if(v!=null){await _updateOwn({'locationMode':v});if(v=='offline')await FirebaseFirestore.instance.collection('liveLocations').doc(widget.user.id).delete();}}),
        const SizedBox(height:10),
        DropdownButtonFormField<int>(value:[1,2,3,5,10,15,30,60].contains(interval)?interval:10,decoration:const InputDecoration(labelText:'Interval mod economic'),items:const[1,2,3,5,10,15,30,60].map((v)=>DropdownMenuItem(value:v,child:Text('$v minute'))).toList(),onChanged:(v)async{if(v!=null)await _updateOwn({'locationIntervalMinutes':v});}),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Schimbare rapidă între conturi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:6),
        if(_quickAccountsLoading)const LinearProgressIndicator()else Builder(builder:(context){final current=(FirebaseAuth.instance.currentUser?.email??widget.user.email).toLowerCase();final saved=_quickAccounts.any((a)=>a.email.toLowerCase()==current);final others=_quickAccounts.where((a)=>a.email.toLowerCase()!=current).toList();return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          OutlinedButton.icon(onPressed:_quickAccountBusy?null:_rememberCurrentQuickAccount,icon:Icon(saved?Icons.refresh:Icons.save_outlined),label:Text(saved?'Actualizează parola contului':'Memorează contul curent')),
          ...others.map((a)=>Padding(padding:const EdgeInsets.only(top:7),child:FilledButton.icon(onPressed:_quickAccountBusy?null:()=>_switchQuickAccount(a),icon:const Icon(Icons.swap_horiz),label:Text('Comută pe ${a.email}')))),
          if(_quickAccounts.isNotEmpty)TextButton.icon(onPressed:_quickAccountBusy?null:_forgetQuickAccounts,icon:const Icon(Icons.delete_outline),label:const Text('Șterge conturile memorate')),
        ]);}),
      ]))),
      const SizedBox(height:10),
      Card(child:ExpansionTile(leading:Badge(isLabelVisible:unread.isNotEmpty,label:Text('${unread.length}'),child:const Icon(Icons.notifications_outlined)),title:const Text('Istoric notificări'),subtitle:Text('${unread.length} necitite · ${mine.length} total'),children:mine.isEmpty?[const ListTile(title:Text('Nu ai notificări.'))]:mine.take(30).map((n)=>ListTile(title:Text(n.title,style:TextStyle(fontWeight:n.read?FontWeight.w500:FontWeight.w900)),subtitle:Text('${n.message}\n${formatDate(n.createdAt)} · ${timeText(n.createdAt)}'),isThreeLine:true,onTap:n.read?null:()async{n.read=true;await FirebaseFirestore.instance.collection('notifications').doc(n.id).set({'read':true,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));widget.onChanged();})).toList())),
      const SizedBox(height:10),
      if(widget.onAdmin!=null)...[
        // Contul Admin nu poate fi făcut vizibil din profil.
        // Protecția la nivel de citire Firestore necesită migrarea interogărilor users.
        const SmsManagerGatewayCard(),const SizedBox(height:10),
      ],
      Card(child:ListTile(leading:const Icon(Icons.notifications_active_outlined),title:const Text('Diagnostic Push'),subtitle:const Text('Verifică permisiunea și înregistrarea dispozitivului.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>PushDiagnosticsPage(userId:widget.user.id))))),
      Card(child:ListTile(leading:const Icon(Icons.feedback_outlined),title:const Text('Feedback'),subtitle:const Text('Raportează o eroare sau trimite o sugestie.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>FeedbackPage(currentUser:widget.user))))),
      if(widget.onAdmin!=null)Card(child:ListTile(leading:const Icon(Icons.admin_panel_settings),title:const Text('Admin Panel'),trailing:FilledButton(onPressed:widget.onAdmin,child:const Text('Deschide')))),
      Card(child:ListTile(leading:const Icon(Icons.logout),title:const Text('Ieșire din cont'),trailing:OutlinedButton(onPressed:widget.onLogout,child:const Text('Ieși')))),
    ]));
  });
}

class SmsManagerGatewayCard extends StatefulWidget {
  const SmsManagerGatewayCard({super.key});
  @override State<SmsManagerGatewayCard> createState()=>_SmsManagerGatewayCardState();
}

class _SmsManagerGatewayCardState extends State<SmsManagerGatewayCard> {
  bool _busy=false;
  bool _enabled=false;
  bool _permission=false;
  String _deviceId='';
  String _lastError='';
  int _lastCheckAt=0;
  int _lastSentAt=0;

  bool get _androidNative => !kIsWeb && defaultTargetPlatform==TargetPlatform.android;

  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>_refresh());}

  Future<void> _refresh() async {
    if(!_androidNative||!mounted)return;
    try{
      final raw=await _smsGatewayChannel.invokeMapMethod<String,dynamic>('gatewayStatus')??<String,dynamic>{};
      if(!mounted)return;
      setState((){
        _enabled=raw['enabled']==true;
        _permission=raw['permission']==true;
        _deviceId=(raw['deviceId']??'').toString();
        _lastError=(raw['lastError']??'').toString();
        _lastCheckAt=(raw['lastCheckAt'] is num)?(raw['lastCheckAt'] as num).toInt():0;
        _lastSentAt=(raw['lastSentAt'] is num)?(raw['lastSentAt'] as num).toInt():0;
      });
    }catch(e){if(mounted)setState(()=>_lastError=e.toString());}
  }

  String _stamp(int value){
    if(value<=0)return 'niciodată';
    final d=DateTime.fromMillisecondsSinceEpoch(value);
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<http.Response> _adminPost(String url, Map<String,dynamic> body) async {
    final user=FirebaseAuth.instance.currentUser;
    final token=await user?.getIdToken(true);
    if(token==null||token.isEmpty)throw StateError('Sesiunea Admin nu este disponibilă.');
    return http.post(Uri.parse(url),headers:{'Authorization':'Bearer $token','Content-Type':'application/json'},body:jsonEncode(body));
  }

  Future<void> _enable() async {
    if(!_androidNative||_busy)return;
    setState(()=>_busy=true);
    try{
      final prepared=await _smsGatewayChannel.invokeMapMethod<String,dynamic>('prepareGateway')??<String,dynamic>{};
      final deviceId=(prepared['deviceId']??'').toString();
      final secret=(prepared['secret']??'').toString();
      if(deviceId.isEmpty||secret.isEmpty)throw StateError('Telefonul nu a generat identitatea gateway.');
      final response=await _adminPost(_registerSmsGatewayUrl,{'deviceId':deviceId,'secret':secret});
      if(response.statusCode<200||response.statusCode>=300)throw StateError('Înregistrare server: HTTP ${response.statusCode} ${response.body}');
      await _smsGatewayChannel.invokeMethod('configureGateway',{'deviceId':deviceId,'secret':secret});
      await _refresh();
      if(mounted)showSuccessMessage(context,'Telefonul este acum expeditorul automat SMS Andi Carpet.');
    }on PlatformException catch(e){
      if(mounted)showErrorMessage(context,e.message??e.code);
    }catch(e){if(mounted)showErrorMessage(context,e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _disable() async {
    if(!_androidNative||_busy)return;
    setState(()=>_busy=true);
    try{
      final response=await _adminPost(_disableSmsGatewayUrl,const{});
      if(response.statusCode<200||response.statusCode>=300)throw StateError('Dezactivare server: HTTP ${response.statusCode}');
      await _smsGatewayChannel.invokeMethod('disableGateway');
      await _refresh();
      if(mounted)showSuccessMessage(context,'Trimiterea automată SMS a fost oprită.');
    }catch(e){if(mounted)showErrorMessage(context,e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _runNow() async {
    if(!_androidNative)return;
    await _smsGatewayChannel.invokeMethod('runGatewayNow');
    if(mounted)showSuccessMessage(context,'Verificarea SMS a fost pornită.');
    await Future<void>.delayed(const Duration(seconds:2));
    await _refresh();
  }

  Future<void> _testSms() async {
    if(!_androidNative)return;
    final phone=TextEditingController();
    final result=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('SMS de test'),
      content:TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Număr telefon',hintText:'07xxxxxxxx')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,phone.text.trim()),child:const Text('Trimite'))],
    ));
    phone.dispose();
    if(result==null||result.isEmpty)return;
    try{
      await _smsGatewayChannel.invokeMethod('sendTestSms',{'phone':result,'message':'Test Andi Carpet: trimiterea automată SMS de pe telefonul gateway funcționează.'});
      if(mounted)showSuccessMessage(context,'SMS-ul de test a fost predat telefonului pentru trimitere.');
    }on PlatformException catch(e){if(mounted)showErrorMessage(context,e.message??e.code);}
  }

  @override Widget build(BuildContext context){
    if(!_androidNative){
      return Card(child:ListTile(
        leading:const Icon(Icons.sms_outlined),
        title:const Text('SMS automat manageri'),
        subtitle:const Text('Gateway-ul SMS se activează o singură dată din aplicația Android instalată pe telefonul care are SIM-ul expeditor. După activare, mesajele pleacă automat de pe acel număr.'),
      ));
    }
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(_enabled?Icons.sms:Icons.sms_outlined,color:_enabled?Colors.green:null),const SizedBox(width:10),const Expanded(child:Text('SMS automat manageri · Andi Carpet',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold))),Switch(value:_enabled,onChanged:_busy?null:(v)=>v?_enable():_disable())]),
      const SizedBox(height:5),
      Text(_enabled?'Acest Android trimite automat SMS-urile prin SIM-ul lui. Verificarea rulează și în fundal aproximativ la 15 minute.':'Activează pe telefonul Android care are numărul de pe care vrei să plece mesajele.'),
      const SizedBox(height:8),
      Text('Permisiune SMS: ${_permission?'acordată':'neacordată'} · Ultima verificare: ${_stamp(_lastCheckAt)} · Ultimul SMS: ${_stamp(_lastSentAt)}',style:Theme.of(context).textTheme.bodySmall),
      if(_deviceId.isNotEmpty)Text('Gateway: $_deviceId',style:Theme.of(context).textTheme.bodySmall),
      if(_lastError.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text('Ultima eroare: $_lastError',style:TextStyle(color:Theme.of(context).colorScheme.error,fontSize:12))),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        OutlinedButton.icon(onPressed:_enabled&&!_busy?_runNow:null,icon:const Icon(Icons.sync),label:const Text('Verifică acum')),
        OutlinedButton.icon(onPressed:_enabled&&!_busy?_testSms:null,icon:const Icon(Icons.send_outlined),label:const Text('SMS test')),
        IconButton(onPressed:_busy?null:_refresh,tooltip:'Actualizează starea',icon:_busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.refresh)),
      ]),
      const SizedBox(height:6),
      const Text('Regulă: mesaj inițial cu o zi înainte; dacă data se schimbă, locația se amână sau ETA se modifică cu cel puțin 60 de minute, managerul este informat din nou. Mesajele folosesc numele Andi Carpet.',style:TextStyle(fontSize:12)),
    ])));
  }
}

class PushDiagnosticsPage extends StatefulWidget {
  final String userId;
  const PushDiagnosticsPage({super.key, required this.userId});
  @override State<PushDiagnosticsPage> createState() => _PushDiagnosticsPageState();
}

class _PushDiagnosticsPageState extends State<PushDiagnosticsPage> {
  bool _busy = false;
  String _permission = 'Neverificat';
  String _vapid = kIsWeb ? (_webPushVapidKey.trim().isEmpty ? 'LIPSEȘTE' : 'Configurată') : 'Nu este necesară';
  String _token = 'Neverificat';
  String _firestore = 'Neverificat';
  String _details = '';

  String _tokenDocId(String token) => base64UrlEncode(utf8.encode(token)).replaceAll('=', '');
  String _authorizationLabel(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized => 'Permisă',
    AuthorizationStatus.provisional => 'Provizorie',
    AuthorizationStatus.denied => 'Refuzată',
    AuthorizationStatus.deniedPermanently => 'Refuzată permanent',
    AuthorizationStatus.notDetermined => 'Nealeasă',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnly());
  }

  Future<void> _checkOnly() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() => _permission = _authorizationLabel(settings.authorizationStatus));
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(widget.userId).collection('pushTokens').get();
      if (!mounted) return;
      setState(() {
        _firestore = snap.docs.isEmpty ? 'Niciun token salvat' : '${snap.docs.length} token(uri) salvate';
      });
    } catch (e) {
      if (mounted) setState(() => _details = 'Verificare: $e');
    }
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _details = '';
      _token = 'Se generează...';
      _firestore = 'În așteptare...';
    });
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (!mounted) return;
      setState(() => _permission = _authorizationLabel(settings.authorizationStatus));
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.deniedPermanently) {
        throw StateError('Permisiunea pentru notificări este refuzată în browser/telefon.');
      }
      if (kIsWeb && _webPushVapidKey.trim().isEmpty) {
        throw StateError('Cheia VAPID nu există în build. Recompilează cu --dart-define=FCM_WEB_VAPID_KEY=CHEIA_PUBLICĂ.');
      }
      if (kIsWeb) await Future<void>.delayed(const Duration(seconds: 1));
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _webPushVapidKey)
          : await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Firebase Messaging nu a returnat niciun token FCM.');
      }
      if (!mounted) return;
      setState(() => _token = '${token.substring(0, token.length < 18 ? token.length : 18)}… (${token.length} caractere)');

      final ref = FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('pushTokens').doc(_tokenDocId(token));
      await ref.set({
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final verify = await ref.get();
      if (!verify.exists) throw StateError('Tokenul a fost trimis către Firestore, dar documentul nu poate fi recitit.');
      if (!mounted) return;
      setState(() {
        _firestore = 'Salvat corect';
        _details = 'Dispozitivul este înregistrat pentru push. Acum poți închide aplicația și trimite o notificare de test.';
      });
      showSuccessMessage(context, 'Dispozitivul a fost înregistrat pentru notificări Push.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _token = 'Eroare';
        _firestore = e.plugin == 'cloud_firestore' ? 'Eroare Firestore' : _firestore;
        _details = '${e.plugin}/${e.code}: ${e.message ?? e.toString()}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _token = 'Eroare';
        _details = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String title, String value, {IconData? icon}) => ListTile(
    leading: Icon(icon ?? Icons.info_outline),
    title: Text(title),
    subtitle: Text(value),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notificări Push')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Diagnostic dispozitiv', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Înregistrarea se face automat la login/pornire. Pagina aceasta rămâne doar pentru diagnostic: permisiune → VAPID → token FCM → salvare Firestore.'),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        _row('Permisiune notificări', _permission, icon: Icons.notifications_outlined),
        const Divider(height: 1),
        _row('Cheie VAPID', _vapid, icon: Icons.vpn_key_outlined),
        const Divider(height: 1),
        _row('Token FCM', _token, icon: Icons.key_outlined),
        const Divider(height: 1),
        _row('Firestore / pushTokens', _firestore, icon: Icons.cloud_done_outlined),
      ])),
      if (_details.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: SelectableText(_details, style: const TextStyle(fontFamily: 'monospace')),
        )),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _register,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh),
        label: Text(_busy ? 'Se înregistrează...' : 'Reînregistrează manual (diagnostic)'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _checkOnly,
        icon: const Icon(Icons.search),
        label: const Text('Verifică din nou'),
      ),
      const SizedBox(height: 12),
      if (kIsWeb) const Text(
        'Dacă apare o eroare care menționează FCM Registration API, activează API-ul Firebase Cloud Messaging Registration pentru proiect și încearcă din nou. Pe web cheia VAPID publică trebuie inclusă la fiecare build.',
        style: TextStyle(fontSize: 12),
      ),
    ]),
  );
}

String privateChatId(String a, String b) {
  final ids = <String>[a, b]..sort();
  return '${ids[0]}__${ids[1]}';
}

Uint8List? decodeProfilePhoto(String? value) {
  if (value == null || value.isEmpty) return null;
  try { return base64Decode(value); } catch (_) { return null; }
}

Future<void> showProfilePhotoViewer(BuildContext context, String photoBase64, String displayName) async {
  final bytes = decodeProfilePhoto(photoBase64);
  if (bytes == null) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .90),
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: SizedBox(
        width: MediaQuery.sizeOf(c).width * .94,
        height: MediaQuery.sizeOf(c).height * .90,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              left: 16,
              top: 14,
              right: 62,
              child: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
            ),
            Positioned(
              right: 8,
              top: 6,
              child: IconButton.filled(
                tooltip: 'Închide',
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(c),
                icon: const Icon(Icons.close),
              ),
            ),
            const Positioned(
              left: 16,
              bottom: 12,
              child: Text('Zoom cu două degete', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      ),
    ),
  );
}

String memberFunctionsText(Map<String,dynamic> d, List<FunctionDefinition> defs) {
  final ids = d['functionIds'] is List
      ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : <String>[(d['function'] ?? '').toString()].where((e) => e.isNotEmpty).toList();
  final names = ids.map((id) => functionById(defs, id)?.name ?? id).where((e) => e.trim().isNotEmpty).toList();
  return names.isEmpty ? 'Membru' : names.join(', ');
}

String _profileDisplayName(Map<String,dynamic> d,{String fallback='Membru'}) {
  final nickname=(d['nickname']??'').toString().trim();
  final name=(d['name']??d['email']??fallback).toString().trim();
  return d['useNickname']==true && nickname.isNotEmpty ? nickname : (name.isEmpty?fallback:name);
}

const Map<String,String> _andiCustomEmojis=<String,String>{
  'mop_magic':'🧹✨',
  'clean_done':'🧼✅',
  'money_day':'💸🧽',
  'salary_late':'🥲💸',
  'coffee_shift':'☕🧹',
  'foam_party':'🫧🎉',
  'snow_clean':'❄️🧼',
  'casino_clean':'🎰🧹',
};

const Map<String,String> _andiStickerAssets=<String,String>{
  'brc_01':'assets/stickers/sticker_01.png',
  'brc_02':'assets/stickers/sticker_02.png',
  'brc_03':'assets/stickers/sticker_03.png',
  'brc_04':'assets/stickers/sticker_04.png',
  'brc_05':'assets/stickers/sticker_05.png',
  'brc_06':'assets/stickers/sticker_06.png',
  'brc_07':'assets/stickers/sticker_07.png',
  'brc_08':'assets/stickers/sticker_08.png',
  'brc_09':'assets/stickers/sticker_09.png',
  'brc_10':'assets/stickers/sticker_10.png',
  'brc_11':'assets/stickers/sticker_11.png',
  'brc_12':'assets/stickers/sticker_12.png',
  'brc_13':'assets/stickers/sticker_13.png',
  'brc_14':'assets/stickers/sticker_14.png',
  'brc_15':'assets/stickers/sticker_15.png',
  'brc_16':'assets/stickers/sticker_16.png',
  'brc_17':'assets/stickers/sticker_17.png',
  'brc_18':'assets/stickers/sticker_18.png',
  'brc_19':'assets/stickers/sticker_19.png',
  'brc_20':'assets/stickers/sticker_20.png',
  'brc_21':'assets/stickers/sticker_21.png',
  'brc_22':'assets/stickers/sticker_22.png',
  'brc_23':'assets/stickers/sticker_23.png',
  'brc_24':'assets/stickers/sticker_24.png',
  'brc_25':'assets/stickers/sticker_25.png',
  'brc_26':'assets/stickers/sticker_26.png',
  'brc_27':'assets/stickers/sticker_27.png',
  'brc_28':'assets/stickers/sticker_28.png',
  'brc_29':'assets/stickers/sticker_29.png',
  'brc_30':'assets/stickers/sticker_30.png',
  'brc_31':'assets/stickers/sticker_31.png',
  'brc_32':'assets/stickers/sticker_32.png',
};

const Map<String,String> _andiStickerFallback=<String,String>{
  'brc_01':'MU!E!',
  'brc_02':'MARȘ!',
  'brc_03':'IA-O!',
  'brc_04':'CHEF DE MUNCĂ: 0%',
  'brc_05':'NU ȘTIU...',
  'brc_06':'CAFELUȚA ȘI BĂGAȚI MOCHETA',
  'brc_07':'TU?',
  'brc_08':'TU EȘTI PROBLEMA!',
  'brc_09':'VOI SUNTEȚI PROBLEMA!',
  'brc_10':'BRC CREW',
  'brc_11':'BOSS',
  'brc_12':'ȘTII TU...',
  'brc_13':'PE BUNE?',
  'brc_14':'HAHAHA!',
  'brc_15':'VINERI!!',
  'brc_16':'ȘEFU VINE!',
  'brc_17':'FACEM?',
  'brc_18':'PSST...',
  'brc_19':'IAR MOCHETA?!',
  'brc_20':'NU E TREABA MEA',
  'brc_21':'NE MAI DUCEM O TURĂ?',
  'brc_22':'BERE?',
  'brc_23':'POFTIM?',
  'brc_24':'CE ZI DE CĂCAT...',
  'brc_25':'DU-TE-N...',
  'brc_26':'IAR?',
  'brc_27':'POWER',
  'brc_28':'WTF?',
  'brc_29':'NA, IA-O!',
  'brc_30':'MUNCĂ... MÂINE',
  'brc_31':'AM VENIT PENTRU MOCHETĂ... CICĂ',
  'brc_32':'AȘA DA!',
};

String? _andiReactionFallback(String key) => _andiStickerFallback[key] ?? _andiCustomEmojis[key];

bool _andiHasReaction(String key) => _andiStickerAssets.containsKey(key) || _andiCustomEmojis.containsKey(key);

Widget _andiReactionWidget(String key, {double size = 104}) {
  final asset = _andiStickerAssets[key];
  if (asset != null) return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  final emoji = _andiCustomEmojis[key] ?? '';
  return Text(emoji, style: TextStyle(fontSize: size * .38));
}

Future<String?> _showAndiReactionPicker(BuildContext context, {String? subtitle}) {
  final keys = <String>[..._andiStickerAssets.keys, ..._andiCustomEmojis.keys];
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final compact = MediaQuery.sizeOf(c).width < 600;
      return SafeArea(
        child: SizedBox(
          height: math.min(MediaQuery.sizeOf(c).height * .74, 680.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Stickere & emoticoane Andi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle ?? 'Set intern pentru chat și mesaje.'),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  itemCount: keys.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: compact ? 4 : 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final label = _andiReactionFallback(key) ?? 'Sticker Andi';
                    return Tooltip(
                      message: label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(c, key),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(c).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: _andiReactionWidget(key, size: compact ? 76 : 92)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      );
    },
  );
}

class PrivateChatPage extends StatefulWidget {
  final AppUser currentUser;
  final String otherUserId;
  final String otherName;
  final String otherPhotoBase64;
  const PrivateChatPage({super.key, required this.currentUser, required this.otherUserId, required this.otherName, this.otherPhotoBase64 = ''});
  @override State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  bool _sentReady = false;
  bool _receivedReady = false;
  String? _chatError;
  List<QueryDocumentSnapshot<Map<String,dynamic>>> _sentDocs = <QueryDocumentSnapshot<Map<String,dynamic>>>[];
  List<QueryDocumentSnapshot<Map<String,dynamic>>> _receivedDocs = <QueryDocumentSnapshot<Map<String,dynamic>>>[];
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _sentSubscription;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _receivedSubscription;
  String get _chatId => privateChatId(widget.currentUser.id, widget.otherUserId);

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance.collection('chatMessages');
    _sentSubscription = db.where('senderId', isEqualTo: widget.currentUser.id).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _sentReady = true;
        _sentDocs = snap.docs.where((d) => (d.data()['recipientId'] ?? '').toString() == widget.otherUserId).toList();
      });
    }, onError: (Object e) { if (mounted) setState(() { _sentReady = true; _chatError = '$e'; }); });
    _receivedSubscription = db.where('recipientId', isEqualTo: widget.currentUser.id).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _receivedReady = true;
        _receivedDocs = snap.docs.where((d) => (d.data()['senderId'] ?? '').toString() == widget.otherUserId).toList();
      });
    }, onError: (Object e) { if (mounted) setState(() { _receivedReady = true; _chatError = '$e'; }); });
  }

  List<QueryDocumentSnapshot<Map<String,dynamic>>> get _visibleDocs {
    final all = <QueryDocumentSnapshot<Map<String,dynamic>>>[..._sentDocs, ..._receivedDocs];
    final visible = all.where((d) {
      final deletedFor = d.data()['deletedFor'];
      return !(deletedFor is List && deletedFor.map((e) => e.toString()).contains(widget.currentUser.id));
    }).toList();
    visible.sort((a,b){
      final aa=a.data()['createdAt']; final bb=b.data()['createdAt'];
      final ad=aa is Timestamp?aa.toDate():DateTime.fromMillisecondsSinceEpoch(0);
      final bd=bb is Timestamp?bb.toDate():DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });
    return visible;
  }

  @override
  void dispose() {
    _sentSubscription?.cancel();
    _receivedSubscription?.cancel();
    _text.dispose(); _scroll.dispose(); super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _text.clear();
    try {
      await FirebaseFirestore.instance.collection('chatMessages').add({
        'chatId': _chatId,
        'senderId': widget.currentUser.id,
        'senderName': widget.currentUser.name,
        'recipientId': widget.otherUserId,
        'recipientName': widget.otherName,
        'participantIds': <String>[widget.currentUser.id, widget.otherUserId],
        'text': body,
        'createdAt': Timestamp.now(),
        'read': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      });
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Mesajul nu a putut fi trimis: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendCustomEmoji(String key) async {
    final display=_andiReactionFallback(key);
    if(display==null || _sending)return;
    setState(()=>_sending=true);
    try{
      await FirebaseFirestore.instance.collection('chatMessages').add({
        'chatId':_chatId,
        'senderId':widget.currentUser.id,
        'senderName':widget.currentUser.name,
        'recipientId':widget.otherUserId,
        'recipientName':widget.otherName,
        'participantIds':<String>[widget.currentUser.id,widget.otherUserId],
        'text':display,
        'customEmoji':key,
        'createdAt':Timestamp.now(),
        'read':false,
        'updatedAt':FieldValue.serverTimestamp(),
      });
    }catch(e){if(mounted)showErrorMessage(context,'Emoticonul nu a putut fi trimis: $e');}
    finally{if(mounted)setState(()=>_sending=false);}
  }

  Future<void> _openEmojiPicker() async {
    final key=await _showAndiReactionPicker(context,subtitle:'Set intern de stickere și emoticoane pentru conversațiile private.');
    if(key!=null)await _sendCustomEmoji(key);
  }

  Future<void> _markRead(List<QueryDocumentSnapshot<Map<String,dynamic>>> docs) async {
    final unread = docs.where((d) {
      final x=d.data();
      return x['recipientId'] == widget.currentUser.id && x['read'] != true;
    }).toList();
    if (unread.isEmpty) return;
    var batch = FirebaseFirestore.instance.batch();
    var count=0;
    for (final d in unread) {
      batch.update(d.reference, {'read': true, 'readAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      count++;
      if (count >= 400) { await batch.commit(); batch=FirebaseFirestore.instance.batch(); count=0; }
    }
    if (count>0) await batch.commit();
  }

  Future<void> _clearChatForMe() async {
    final docs = <QueryDocumentSnapshot<Map<String,dynamic>>>[..._sentDocs, ..._receivedDocs];
    if (docs.isEmpty) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Ștergi conversația?'),
      content: const Text('Conversația va dispărea doar pentru tine. Celălalt membru își păstrează istoricul. Mesajele noi vor apărea din nou aici.'),
      actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:()=>Navigator.pop(c,true),icon:const Icon(Icons.delete_outline),label:const Text('Șterge pentru mine'))],
    )) ?? false;
    if (!ok) return;
    try {
      var batch = FirebaseFirestore.instance.batch();
      var count = 0;
      for (final d in docs) {
        batch.set(d.reference, {'deletedFor': FieldValue.arrayUnion([widget.currentUser.id]), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        count++;
        if (count >= 400) { await batch.commit(); batch = FirebaseFirestore.instance.batch(); count = 0; }
      }
      if (count > 0) await batch.commit();
      if (mounted) showSuccessMessage(context, 'Conversația a fost ștearsă pentru tine.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Nu am putut șterge conversația: $e');
    }
  }

  Widget _conversation() {
    if (_chatError != null && !_sentReady && !_receivedReady) return Center(child: Text('Nu am putut încărca discuția: $_chatError'));
    if (!_sentReady || !_receivedReady) return const Center(child: CircularProgressIndicator());
    final docs = _visibleDocs;
    unawaited(_markRead(docs));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
    if (docs.isEmpty) return const Center(child: Text('Niciun mesaj încă. Scrie primul mesaj.'));
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: docs.length,
      itemBuilder: (context,index){
        final d=docs[index].data();
        final mine=(d['senderId']??'').toString()==widget.currentUser.id;
        final raw=d['createdAt'];
        final when=raw is Timestamp?raw.toDate():DateTime.now();
        final read=d['read']==true;
        return Align(
          alignment: mine?Alignment.centerRight:Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width*.78),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(12,8,10,6),
            decoration: BoxDecoration(
              color: mine?Theme.of(context).colorScheme.primaryContainer:Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(mine?15:3), bottomRight: Radius.circular(mine?3:15),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              if(_andiHasReaction((d['customEmoji']??'').toString()))
                _andiReactionWidget((d['customEmoji']??'').toString(),size:118)
              else
                Text((d['text']??'').toString(), style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children:[
                Text('${two(when.hour)}:${two(when.minute)}', style: Theme.of(context).textTheme.labelSmall),
                if(mine)...[const SizedBox(width:4),Icon(read?Icons.done_all:Icons.done,size:15)],
              ]),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = decodeProfilePhoto(widget.otherPhotoBase64);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          GestureDetector(
            onTap:photo==null?null:()=>showProfilePhotoViewer(context,widget.otherPhotoBase64,widget.otherName),
            child:CircleAvatar(radius: 20, backgroundImage: photo == null ? null : MemoryImage(photo), child: photo == null ? const Icon(Icons.person, size: 20) : null),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.otherName, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [IconButton(tooltip:'Șterge conversația pentru mine', onPressed:_clearChatForMe, icon:const Icon(Icons.delete_outline))],
      ),
      body: Column(children: [
        Expanded(child: _conversation()),
        SafeArea(top:false, child: Padding(
          padding: const EdgeInsets.fromLTRB(10,7,10,8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children:[
            IconButton(tooltip:'Stickere & emoticoane Andi',onPressed:_sending?null:_openEmojiPicker,icon:const Icon(Icons.emoji_emotions_outlined)),
            const SizedBox(width:4),
            Expanded(child: TextField(
              controller:_text,
              minLines:1,maxLines:5,
              textCapitalization:TextCapitalization.sentences,
              decoration: const InputDecoration(hintText:'Mesaj...', prefixIcon:Icon(Icons.chat_bubble_outline)),
              onSubmitted:(_)=>_send(),
            )),
            const SizedBox(width:8),
            IconButton.filled(onPressed:_sending?null:_send,icon:_sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send)),
          ]),
        )),
      ]),
    );
  }
}


class GroupChatPage extends StatefulWidget {
  final AppUser currentUser;
  final List<AppUser> users;
  final List<FunctionDefinition> functionDefinitions;
  const GroupChatPage({super.key, required this.currentUser, this.users = const <AppUser>[], this.functionDefinitions = const <FunctionDefinition>[]});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  static const int _historyLimit = 50;
  static const int _retentionDays = 7;
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  CollectionReference<Map<String,dynamic>> get _messages => FirebaseFirestore.instance.collection('groupChatMessages');
  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => _messages
      .orderBy('createdAt', descending: true)
      .limit(_historyLimit)
      .snapshots();

  @override
  void initState() {
    super.initState();
    unawaited(_markChatOpened());
    unawaited(_cleanupExpiredMessages());
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markChatOpened() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.currentUser.id).set({
        'lastGroupChatSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _cleanupExpiredMessages() async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: _retentionDays)));
      while (true) {
        final old = await _messages.where('createdAt', isLessThan: cutoff).limit(100).get();
        if (old.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in old.docs) { batch.delete(doc.reference); }
        await batch.commit();
        if (old.docs.length < 100) break;
      }
    } catch (_) {
      // Curățarea este best-effort; chatul rămâne funcțional chiar dacă un client nu poate șterge.
    }
  }

  Future<void> _send({String? customEmoji}) async {
    if (_sending) return;
    final body = customEmoji == null ? _text.text.trim() : (_andiReactionFallback(customEmoji) ?? 'Sticker Andi');
    if (body.isEmpty) return;
    setState(() => _sending = true);
    if (customEmoji == null) _text.clear();
    try {
      final hidden = widget.currentUser.hiddenFromMembers;
      await _messages.add({
        'senderId': widget.currentUser.id,
        'senderName': hidden ? 'Sistem' : widget.currentUser.name,
        'senderPhotoBase64': hidden ? '' : widget.currentUser.photoBase64,
        'text': body,
        if (customEmoji != null) 'customEmoji': customEmoji,
        'createdAt': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Mesajul nu a putut fi trimis: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openEmojiPicker() async {
    final key = await _showAndiReactionPicker(
      context,
      subtitle: 'Chat comun · ultimele 50 de mesaje · retenție 7 zile.',
    );
    if (key != null) await _send(customEmoji: key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat live · Toți membrii'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text('50 mesaje · 7 zile', style: Theme.of(context).textTheme.labelSmall)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Nu am putut încărca chatul live: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs.toList()
                  ..sort((a, b) {
                    final aa = a.data()['createdAt'];
                    final bb = b.data()['createdAt'];
                    final ad = aa is Timestamp ? aa.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                    final bd = bb is Timestamp ? bb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                    return ad.compareTo(bd);
                  });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                });
                if (docs.isEmpty) return const Center(child: Text('Niciun mesaj încă. Scrie primul mesaj în chatul comun.'));
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final mine = (d['senderId'] ?? '').toString() == widget.currentUser.id;
                    final when = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : DateTime.now();
                    final photoData = (d['senderPhotoBase64'] ?? '').toString();
                    final photo = decodeProfilePhoto(photoData);
                    final senderName = (d['senderName'] ?? 'Membru').toString();
                    AppUser? senderUser;
                    for (final u in widget.users) { if (u.id == (d['senderId'] ?? '').toString()) { senderUser = u; break; } }
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!mine) ...[
                              GestureDetector(
                                onTap: photo == null ? null : () => showProfilePhotoViewer(context, photoData, senderName),
                                child: CircleAvatar(radius: 18, backgroundImage: photo == null ? null : MemoryImage(photo), child: photo == null ? const Icon(Icons.person, size: 18) : null),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                                decoration: BoxDecoration(
                                  color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: Radius.circular(mine ? 15 : 3),
                                    bottomRight: Radius.circular(mine ? 3 : 15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!mine) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Text(senderName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                      ),
                                      if (senderUser != null && widget.functionDefinitions.isNotEmpty && senderUser.functionIds.isNotEmpty)
                                        Padding(padding:const EdgeInsets.only(bottom:5),child:memberBadgeStripWidget(widget.functionDefinitions,senderUser.functionIds,size:24)),
                                    ],
                                    if (_andiHasReaction((d['customEmoji'] ?? '').toString()))
                                      _andiReactionWidget((d['customEmoji'] ?? '').toString(), size: 126)
                                    else
                                      Text((d['text'] ?? '').toString(), style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 3),
                                    Text('${two(when.hour)}:${two(when.minute)}', style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(tooltip: 'Stickere & emoticoane Andi', onPressed: _sending ? null : _openEmojiPicker, icon: const Icon(Icons.emoji_emotions_outlined)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Mesaj pentru toți membrii...', prefixIcon: Icon(Icons.forum_outlined)),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MemberProfilePage extends StatelessWidget {
  final AppUser currentUser;
  final String memberId;
  final List<FunctionDefinition> functionDefinitions;
  const MemberProfilePage({super.key, required this.currentUser, required this.memberId, required this.functionDefinitions});

  Future<void> _call(BuildContext context,String phone) async {
    final uri=Uri(scheme:'tel',path:phone);
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)){
      await Clipboard.setData(ClipboardData(text:phone));
      if(context.mounted) showErrorMessage(context,'Apelarea directă nu este disponibilă aici. Numărul a fost copiat.');
    }
  }

  void _chat(BuildContext context,Map<String,dynamic>d){
    Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PrivateChatPage(
      currentUser:currentUser,
      otherUserId:memberId,
      otherName:_profileDisplayName(d),
      otherPhotoBase64:(d['photoBase64']??'').toString(),
    )));
  }

  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text('Profil membru')),body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection(currentUser.role == UserRole.director || memberId == currentUser.id ? 'users' : 'memberDirectory').doc(memberId).snapshots(),
      builder:(context,snap){
        if(snap.hasError)return Center(child:Text('Nu am putut încărca profilul: ${snap.error}'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final d=snap.data!.data()??<String,dynamic>{};
        if(currentUser.role != UserRole.director && d['hiddenFromMembers'] == true && memberId != currentUser.id){
          return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Acest profil nu este disponibil pentru membri.')));
        }
        final name=_profileDisplayName(d);
        final phone=(d['phone']??'').toString().trim();
        final photoData=(d['photoBase64']??'').toString();
        final photo=decodeProfilePhoto(photoData);
        final functionIds=d['functionIds'] is List?(d['functionIds'] as List).map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList():<String>[];
        final rawFields=d['profileFields'];
        final fields=<Map<String,String>>[];
        if(rawFields is List){for(final raw in rawFields){if(raw is Map){final l=(raw['label']??'').toString().trim();final v=(raw['value']??'').toString().trim();final t=(raw['type']??'text').toString();if(l.isNotEmpty||v.isNotEmpty)fields.add({'label':l,'value':v,'type':t});}}}
        return ListView(padding:const EdgeInsets.all(16),children:[
          Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
            GestureDetector(
              onTap:photo==null?null:()=>showProfilePhotoViewer(context,photoData,name),
              child:CircleAvatar(radius:58,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person,size:54):null),
            ),
            const SizedBox(height:12),Text(name,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
            const SizedBox(height:4),Text((d['contractFunction']??'').toString().trim().isEmpty?memberFunctionsText(d,functionDefinitions):(d['contractFunction']??'').toString()),
            if(functionIds.isNotEmpty)...[const SizedBox(height:10),memberBadgeStripWidget(functionDefinitions,functionIds,size:42)],
            if((d['email']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:5),child:Text((d['email']??'').toString())),
            const SizedBox(height:14),
            if(memberId!=currentUser.id)FilledButton.icon(onPressed:()=>_chat(context,d),icon:const Icon(Icons.chat),label:const Text('Mesaj privat')),
          ]))),
          if(phone.isNotEmpty)Card(child:ListTile(
            leading:const CircleAvatar(backgroundColor:Colors.green,child:Icon(Icons.phone,color:Colors.white)),
            title:const Text('Telefon'),subtitle:Text(phone),trailing:const Icon(Icons.call,color:Colors.green),
            onTap:()=>_call(context,phone),
          )),
          ...fields.map((f){final link=f['type']=='link';return Card(child:ListTile(title:Text(f['label']!.isEmpty?'Informație':f['label']!),subtitle:Text(f['value']??''),leading:Icon(link?Icons.link:Icons.info_outline),trailing:link?const Icon(Icons.open_in_new):null,onTap:link?()async{final raw=(f['value']??'').trim();if(raw.isEmpty)return;final normalized=RegExp(r'^https?://',caseSensitive:false).hasMatch(raw)?raw:'https://$raw';final uri=Uri.tryParse(normalized);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);}:null));}),
        ]);
      },
    ));
  }
}

class MembersDirectoryPage extends StatefulWidget {
  final AppUser currentUser;
  final List<FunctionDefinition> functionDefinitions;
  final bool chatMode;
  const MembersDirectoryPage({super.key, required this.currentUser, required this.functionDefinitions, this.chatMode=false});
  @override State<MembersDirectoryPage> createState() => _MembersDirectoryPageState();
}

class _MembersDirectoryPageState extends State<MembersDirectoryPage> {
  final Set<String> _selected = <String>{};

  void _openChat(String uid, Map<String,dynamic> d) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrivateChatPage(
      currentUser: widget.currentUser,
      otherUserId: uid,
      otherName: (d['name'] ?? d['email'] ?? 'Membru').toString(),
      otherPhotoBase64: (d['photoBase64'] ?? '').toString(),
    )));
  }

  void _openProfile(String uid) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberProfilePage(
      currentUser: widget.currentUser,
      memberId: uid,
      functionDefinitions: widget.functionDefinitions,
    )));
  }

  Future<void> _sendBulkMessage(Set<String> recipients, Map<String,Map<String,dynamic>> dataById) async {
    if (recipients.isEmpty) return;
    final message = TextEditingController();
    final ok = await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text('Mesaj către ${recipients.length} membri'),
      content:SizedBox(width:560,child:TextField(controller:message,autofocus:true,minLines:4,maxLines:8,decoration:const InputDecoration(labelText:'Mesaj',hintText:'Mesajul va intra în conversația fiecărui membru.'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton.icon(onPressed:(){if(message.text.trim().isNotEmpty)Navigator.pop(c,true);},icon:const Icon(Icons.send),label:const Text('Trimite'))],
    ))??false;
    if(!ok){message.dispose();return;}
    final body=message.text.trim();message.dispose();
    try{
      final db=FirebaseFirestore.instance;final batch=db.batch();final now=Timestamp.now();
      for(final uid in recipients){
        final d=dataById[uid]??<String,dynamic>{};
        final ref=db.collection('chatMessages').doc();
        batch.set(ref,{
          'chatId':privateChatId(widget.currentUser.id,uid),'senderId':widget.currentUser.id,'senderName':widget.currentUser.name,
          'recipientId':uid,'recipientName':_profileDisplayName(d),'participantIds':<String>[widget.currentUser.id,uid],'text':body,'createdAt':now,'read':false,'updatedAt':FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if(!mounted)return;setState(()=>_selected.removeAll(recipients));showSuccessMessage(context,'Mesajul a fost adăugat în conversațiile selectate.');
    }catch(e){if(mounted)showErrorMessage(context,'Mesajul nu a putut fi trimis: $e');}
  }

  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:Text(widget.chatMode?'Chat live':'Membrii')),body:SafeArea(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:(widget.currentUser.role == UserRole.director ? FirebaseFirestore.instance.collection('users') : FirebaseFirestore.instance.collection('memberDirectory')).where('active',isEqualTo:true).snapshots(),
      builder:(context,snap){
        if(snap.hasError)return Center(child:Text('Nu am putut încărca membrii: ${snap.error}'));
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final docs=snap.data!.docs.where((doc){
          final d=doc.data();
          if(widget.currentUser.role == UserRole.director || doc.id == widget.currentUser.id) return true;
          return !((d['role']??'').toString() == 'admin' && d['hiddenFromMembers'] == true);
        }).toList()..sort((a,b)=>(a.data()['name']??a.data()['email']??'').toString().toLowerCase().compareTo((b.data()['name']??b.data()['email']??'').toString().toLowerCase()));
        final dataById=<String,Map<String,dynamic>>{for(final d in docs)d.id:d.data()};
        return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: FirebaseFirestore.instance.collection('chatMessages').where('recipientId', isEqualTo: widget.currentUser.id).snapshots(),
          builder: (context, messageSnap) {
            final unreadBySender=<String,int>{};
            if(messageSnap.hasData){
              for(final m in messageSnap.data!.docs){
                final md=m.data();final deletedFor=md['deletedFor'];
                if(md['read']==true || (deletedFor is List && deletedFor.map((e)=>e.toString()).contains(widget.currentUser.id)))continue;
                final sender=(md['senderId']??'').toString();if(sender.isNotEmpty)unreadBySender[sender]=(unreadBySender[sender]??0)+1;
              }
            }
            return Column(children:[
              Padding(padding:const EdgeInsets.fromLTRB(12,10,12,4),child:Row(children:[
                Expanded(child:Text('${docs.length} membri activi',style:const TextStyle(fontWeight:FontWeight.w800))),
                FilledButton.icon(onPressed:_selected.isEmpty?null:()=>_sendBulkMessage({..._selected},dataById),icon:const Icon(Icons.send),label:Text(_selected.length<=1?'Trimite mesaj':'Mesaj către ${_selected.length}')),
              ])),
              Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Align(alignment:Alignment.centerLeft,child:Text(widget.chatMode?'Chatul live principal este comun pentru toți membrii. Mai jos poți intra și în conversații private.':'Apasă pe un membru pentru profil. Bulina de pe chat arată mesajele necitite.'))),
              const SizedBox(height:6),
              Expanded(child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:docs.length + (widget.chatMode ? 1 : 0),itemBuilder:(context,index){
                if(widget.chatMode && index == 0){
                  return Card(child:ListTile(
                    onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>GroupChatPage(currentUser: widget.currentUser, functionDefinitions: widget.functionDefinitions))),
                    contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
                    leading:const CircleAvatar(child:Icon(Icons.forum_outlined)),
                    title:const Text('Chat live · Toți membrii',style:TextStyle(fontWeight:FontWeight.w900)),
                    subtitle:const Text('Conversație comună între toți membrii activi ai aplicației.'),
                    trailing:const Icon(Icons.chevron_right),
                  ));
                }
                final realIndex = index - (widget.chatMode ? 1 : 0);
                final doc=docs[realIndex];final d=doc.data();final uid=doc.id;final name=_profileDisplayName(d,fallback:uid);final photoData=(d['photoBase64']??'').toString();final photo=decodeProfilePhoto(photoData);final isMe=uid==widget.currentUser.id;final checked=_selected.contains(uid);final unread=unreadBySender[uid]??0;final functionIds=d['functionIds'] is List?(d['functionIds'] as List).map((e)=>e.toString()).where((e)=>e.isNotEmpty).toList():<String>[];
                return Card(child:ListTile(
                  onTap:()=>widget.chatMode&&!isMe?_openChat(uid,d):_openProfile(uid),contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
                  leading:Row(mainAxisSize:MainAxisSize.min,children:[Checkbox(value:checked,onChanged:isMe?null:(v)=>setState((){if(v==true){_selected.add(uid);}else{_selected.remove(uid);}})),GestureDetector(onTap:photo==null?null:()=>showProfilePhotoViewer(context,photoData,name),child:CircleAvatar(key:ValueKey('member-$uid-${photoData.hashCode}'),radius:29,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person):null))]),
                  title:Row(children:[Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w800))),if(isMe)const Chip(label:Text('Eu'))]),
                  subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text('${memberFunctionsText(d,widget.functionDefinitions)}${unread>0?' · $unread mesaj${unread==1?'':'e'} necitit${unread==1?'':'e'}':''}'),if(functionIds.isNotEmpty)...[const SizedBox(height:7),memberBadgeStripWidget(widget.functionDefinitions,functionIds,size:32)]]),
                  trailing:isMe?const Icon(Icons.chevron_right):Badge(isLabelVisible:unread>0,label:Text(unread>99?'99+':'$unread'),child:IconButton(tooltip:'Deschide conversația',onPressed:()=>_openChat(uid,d),icon:Icon(unread>0?Icons.mark_chat_unread:Icons.chat_bubble_outline))),
                ));
              })),
            ]);
          },
        );
      },
    )));
  }
}

class FeedbackPage extends StatefulWidget {
  final AppUser currentUser; final int initialTab;
  const FeedbackPage({super.key,required this.currentUser,this.initialTab=0});
  @override State<FeedbackPage> createState()=>_FeedbackPageState();
}
class _FeedbackPageState extends State<FeedbackPage> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final details=TextEditingController(); final expected=TextEditingController(); final suggestion=TextEditingController();
  String area='Dashboard'; String severity='Mă încurcă, dar pot continua'; bool sending=false;
  @override void initState(){super.initState();tabs=TabController(length:2,vsync:this,initialIndex:widget.initialTab.clamp(0,1));}
  @override void dispose(){tabs.dispose();details.dispose();expected.dispose();suggestion.dispose();super.dispose();}
  Future<void> _sendError() async {
    if(details.text.trim().length<8){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Scrie pe scurt ce s-a întâmplat, măcar 8 caractere.')));return;}
    setState(()=>sending=true);
    try{await FirebaseFirestore.instance.collection('errorReports').add({'userId':widget.currentUser.id,'userName':widget.currentUser.name,'area':area,'severity':severity,'details':details.text.trim(),'expected':expected.text.trim(),'status':'nou','createdAt':FieldValue.serverTimestamp()});details.clear();expected.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Eroarea a fost trimisă. Mersi, detectivule.'),backgroundColor:Colors.green));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nu s-a putut trimite: $e')));}finally{if(mounted)setState(()=>sending=false);}
  }
  Future<void> _sendSuggestion() async {
    if(suggestion.text.trim().length<5)return;
    setState(()=>sending=true);
    try{await FirebaseFirestore.instance.collection('suggestions').add({'userId':widget.currentUser.id,'userName':widget.currentUser.name,'message':suggestion.text.trim(),'upVotes':<String>[],'downVotes':<String>[],'createdAt':FieldValue.serverTimestamp()});suggestion.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sugestia a intrat la vot. Să înceapă democrația.'),backgroundColor:Colors.green));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nu s-a putut trimite: $e')));}finally{if(mounted)setState(()=>sending=false);}
  }
  Future<void> _vote(DocumentSnapshot<Map<String,dynamic>> doc,bool up) async {
    final uid=widget.currentUser.id; final d=doc.data()??{}; final ups=List<String>.from((d['upVotes'] as List?)??const[]); final downs=List<String>.from((d['downVotes'] as List?)??const[]);
    if(up){downs.remove(uid);ups.contains(uid)?ups.remove(uid):ups.add(uid);}else{ups.remove(uid);downs.contains(uid)?downs.remove(uid):downs.add(uid);}
    await doc.reference.update({'upVotes':ups,'downVotes':downs});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eroare sau idee? Dă-i aici.'),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(icon: Icon(Icons.bug_report), text: 'Raportează eroare'),
            Tab(icon: Icon(Icons.lightbulb), text: 'Sugestii'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _InfoCard(
                icon: Icons.support_agent,
                title: 'Spune-ne unde doare',
                text: 'Alege zona, gravitatea și descrie simplu ce ai făcut și ce s-a întâmplat. Cu cât e mai clar, cu atât reparăm mai repede.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: area,
                decoration: const InputDecoration(labelText: 'Unde a apărut?'),
                items: const ['Dashboard','Grafic de lucru','Hartă','Centralizator','Decont','Documente','Profil','Admin Panel','Altundeva']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setState(() => area = v ?? area),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(labelText: 'Cât de grav e?'),
                items: const ['Doar arată ciudat','Mă încurcă, dar pot continua','Nu mai pot continua','Date greșite / risc de pierdere date']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setState(() => severity = v ?? severity),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Ce s-a întâmplat?',
                  hintText: 'Ex.: Am apăsat INTRĂ la Million X și butonul a rămas blocat…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expected,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ce te așteptai să se întâmple?',
                  hintText: 'Ex.: Să apară imediat sala în Dashboard și ora în Centralizator.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: sending ? null : _sendError,
                icon: const Icon(Icons.send),
                label: const Text('Trimite eroarea'),
              ),
            ],
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: suggestion,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Sugestia ta',
                        hintText: 'Ex.: Ar fi util să…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: sending ? null : _sendSuggestion,
                        icon: const Icon(Icons.add_comment),
                        label: const Text('Publică sugestia'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('suggestions').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Nu pot încărca sugestiile: ${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('Nicio sugestie încă. Fii primul care complică aplicația.'));
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      itemBuilder: (c, i) {
                        final doc = docs[i];
                        final d = doc.data();
                        final ups = List<String>.from((d['upVotes'] as List?) ?? const []);
                        final downs = List<String>.from((d['downVotes'] as List?) ?? const []);
                        final uid = widget.currentUser.id;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((d['message'] ?? '').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('de ${(d['userName'] ?? 'Utilizator').toString()}', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: () => _vote(doc, true),
                                      icon: Icon(Icons.check_circle, color: ups.contains(uid) ? Colors.green : null),
                                      label: Text('${ups.length} Da'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _vote(doc, false),
                                      icon: Icon(Icons.cancel, color: downs.contains(uid) ? Colors.red : null),
                                      label: Text('${downs.length} Nu'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class AdminPanelPage extends StatefulWidget {
  final List<AppUser> users; final List<Team> teams; final List<Car> cars; final List<Location> locations; final List<LocationCategory> categories; final List<FunctionDefinition> functionDefinitions; final List<WorkSchedule> schedules; final List<CentralizerRecord> records; final List<Expense> expenses; final List<PerDiemEntry> perDiems; final List<TeamFinance> finances; final List<TravelSettlement> settlements; final List<AppNotification> notifications; final List<AuditEntry> audit; final AppSettings settings; final String Function(String) userName; final VoidCallback onChanged; final void Function(String,String) log; final Future<void> Function(Location) saveLocation; final Future<void> Function(String) deleteLocation;
  const AdminPanelPage({super.key,required this.users,required this.teams,required this.cars,required this.locations,required this.categories,required this.functionDefinitions,required this.schedules,required this.records,required this.expenses,required this.perDiems,required this.finances,required this.settlements,required this.notifications,required this.audit,required this.settings,required this.userName,required this.onChanged,required this.log,required this.saveLocation,required this.deleteLocation});
  @override State<AdminPanelPage> createState()=>_AdminPanelPageState();
}
class _AdminPanelPageState extends State<AdminPanelPage>{
  List<AppUser> get users => widget.users; List<Team> get teams => widget.teams; List<Car> get cars => widget.cars; List<Location> get locations => widget.locations; List<LocationCategory> get categories => widget.categories; List<FunctionDefinition> get functionDefinitions => widget.functionDefinitions; List<WorkSchedule> get schedules => widget.schedules; List<CentralizerRecord> get records => widget.records; List<Expense> get expenses => widget.expenses; List<PerDiemEntry> get perDiems => widget.perDiems; List<TeamFinance> get finances => widget.finances; List<TravelSettlement> get settlements => widget.settlements; List<AppNotification> get notifications => widget.notifications; List<AuditEntry> get audit => widget.audit; AppSettings get settings => widget.settings;
  int section = 0;
  final names = const [
    'Dashboard','Echipe','Membri / Conturi','Mașini','Locații','Categorii locații','Grafice de lucru','Centralizator','Decont & Financiar','Learning Center','Learning OCR','Notificări','Rapoarte','Istoric / Audit','Funcții & Drepturi','Setări sistem','Backup & Recuperare'
  ];

  IconData _icon(int i) => const [
    Icons.dashboard, Icons.groups, Icons.people, Icons.directions_car, Icons.location_on, Icons.category_outlined,
    Icons.calendar_month, Icons.table_chart, Icons.receipt_long, Icons.auto_graph, Icons.document_scanner,
    Icons.notifications, Icons.assessment, Icons.history, Icons.security, Icons.palette_outlined, Icons.backup,
  ][i];

  String _groupFor(int i) {
    if (i <= 7) return 'Operațional';
    if (i == 8) return 'Financiar';
    if (i == 9 || i == 10) return 'Learning';
    if (i == 11 || i == 14) return 'Administrare';
    return 'Sistem';
  }

  String? _adminSectionAsset(int i) => switch (i) {
    0 => 'assets/ui/tab_dashboard.png',
    1 => 'assets/ui/teams.png',
    2 => 'assets/ui/members.png',
    4 => 'assets/ui/tab_harta.png',
    6 => 'assets/ui/tab_grafic.png',
    7 => 'assets/ui/tab_centralizator.png',
    8 => 'assets/ui/tab_decont.png',
    12 => 'assets/ui/tab_centralizator.png',
    14 => 'assets/ui/security.png',
    _ => null,
  };

  Widget _adminLeading(int i, Color accent) {
    final asset = _adminSectionAsset(i);
    return asset == null ? Icon(_icon(i)) : appAssetIcon(asset, size: 22, accent: accent, selected: section == i);
  }

  Widget _adminMenu({required bool closeDrawer}) {
    final widgets = <Widget>[];
    String? previousGroup;
    for (var i = 0; i < names.length; i++) {
      final group = _groupFor(i);
      if (group != previousGroup) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 12, 6),
          child: Text(group.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ));
        previousGroup = group;
      }
      final accent = sectionAccent(names[i]);
      widgets.add(ListTile(
        selected: section == i,
        selectedTileColor: accent.withValues(alpha: .14),
        iconColor: section == i ? accent : null,
        textColor: section == i ? accent : null,
        leading: _adminLeading(i, accent),
        title: Text(names[i], style: TextStyle(fontWeight: section == i ? FontWeight.w800 : FontWeight.w600)),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          setState(() => section = i);
          if (closeDrawer) Navigator.of(context).pop();
        },
      ));
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: widgets);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final mobile = box.maxWidth < 900;
      final content = SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? 12 : 24),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1250),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(mobile ? 12 : 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .95 : .98),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (mobile) ...[
                DropdownButtonFormField<int>(
                  key: ValueKey('admin-section-$section'),
                  initialValue: section,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Secțiune Admin',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [for (var i = 0; i < names.length; i++)
                    DropdownMenuItem<int>(value: i, child: Text(names[i], overflow: TextOverflow.ellipsis))],
                  onChanged: (value) { if (value != null) setState(() => section = value); },
                ),
                const SizedBox(height: 12),
              ],
              _content(),
            ]),
          ),
        )),
      );
      return Scaffold(
        appBar: AppBar(
          leading: mobile
              ? Builder(builder: (c) => IconButton(
                  tooltip: 'Meniu Admin',
                  onPressed: () => Scaffold.of(c).openDrawer(),
                  icon: const Icon(Icons.menu),
                ))
              : (Navigator.canPop(context) ? IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Înapoi', icon: appAssetIcon('assets/ui/back.png', size: 22, accent: Theme.of(context).colorScheme.primary)) : null),
          title: Text(mobile ? 'Admin · ${names[section]}' : 'Admin Panel'),
          actions: [
            if (mobile && Navigator.canPop(context)) IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Închide Admin Panel', icon: const Icon(Icons.close)),
            IconButton(onPressed: () => setState(() {}), tooltip: 'Reîncarcă', icon: const Icon(Icons.refresh)),
          ],
        ),
        drawer: mobile ? Drawer(child: SafeArea(child: _adminMenu(closeDrawer: true))) : null,
        body: _AppBackdrop(
          settings: settings,
          child: mobile
              ? content
              : Row(children: [
                  SizedBox(width: 270, child: Material(color: Theme.of(context).colorScheme.surface.withValues(alpha: .94), child: _adminMenu(closeDrawer: false))),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ]),
        ),
      );
    });
  }

  Widget _content(){switch(section){
    case 0:return _dashboard(); case 1:return _teams(); case 2:return _members(); case 3:return _cars(); case 4:return _locations(); case 5:return _categories();
    case 6:return _programs(); case 7:return _records(); case 8:return _finance(); case 9:return _learning(false); case 10:return _learning(true); case 11:return _notifications();
    case 12:return _reports(); case 13:return _audit(); case 14:return _functionRights(); case 15:return _settings(); default:return _backup();
  }}
  Widget _dashboard()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Dashboard Admin',style:Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height:12),
    Wrap(spacing:12,runSpacing:12,children:[_StatCard(title:'Membri',value:'${users.length}',asset:'assets/ui/members.png'),_StatCard(title:'Echipe',value:'${teams.length}',asset:'assets/ui/teams.png'),_StatCard(title:'Locații',value:'${locations.length}',asset:'assets/ui/tab_harta.png'),_StatCard(title:'Grafice de lucru',value:'${schedules.length}',asset:'assets/ui/tab_grafic.png'),_StatCard(title:'Execuții',value:'${records.length}',asset:'assets/ui/tab_centralizator.png'),_StatCard(title:'Audit',value:'${audit.length}',icon:Icons.history)]),
    const SizedBox(height:16),
    Text('Acces rapid', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height:8),
    Wrap(spacing:8,runSpacing:8,children:[
      for (final i in [1,2,4,6,8,11,13,14,15])
        ActionChip(
          avatar: Icon(_icon(i), size:18),
          label: Text(names[i]),
          onPressed: () => setState(() => section = i),
        ),
    ]),
    const SizedBox(height:20),
    _mapboxUsagePanel(),
  ]);

  Widget _mapboxUsagePanel() {
    const budget = 50000;
    final counts = _mapboxServices.requestsByService;
    final total = _mapboxServices.totalRequests;
    final ratio = total / budget;
    final warning = ratio >= .95 ? 'Avertizare: 95% din buget' : ratio >= .85 ? 'Avertizare: 85% din buget' : ratio >= .70 ? 'Avertizare: 70% din buget' : null;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mapbox – monitor orientativ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        Text('Buget orientativ: $budget solicitări/lună (nu blochează serviciile).'),
        Text('Solicitări observate pe acest dispozitiv, în sesiunea curentă: $total'),
        const SizedBox(height:8),
        LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
        const SizedBox(height:8),
        for (final entry in counts.entries) Text('${entry.key}: ${entry.value}'),
        if (warning != null) Padding(padding: const EdgeInsets.only(top:8), child: Text(warning, style: const TextStyle(fontWeight:FontWeight.bold))),
        const SizedBox(height:8),
        const Text('Contor local, resetat la repornire; NU reprezintă consumul lunar al contului sau facturarea. Pentru totalul real al ambelor echipe verificați statisticile Mapbox.', style: TextStyle(fontSize:12)),
      ],
    )));
  }
  String _safeName(String id){try{return users.firstWhere((u)=>u.id==id).name;}catch(_){return id;}}
  String _safeTeam(String id){try{return teams.firstWhere((t)=>t.id==id).name;}catch(_){return id;}}
  FunctionDefinition? _functionByIdLocal(String id) { for (final f in functionDefinitions) { if (f.id == id) return f; } return null; }
  Color _locationColor(Location l) => categoryColor(categories, l.categoryId, fallbackType: l.type);
  String _functionNames(AppUser u) {
    final labels = u.functionIds.map((id) => _functionByIdLocal(id)?.name ?? id).toList();
    return labels.isEmpty ? u.function.label : labels.join(', ');
  }

  Future<int?> _pickColorValue(int current) async {
    final hex = TextEditingController(text: current.toRadixString(16).padLeft(8, '0').toUpperCase());
    final palette = <Color>[
      Colors.red, Colors.pink, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.blueGrey, Colors.black87,
    ];
    int selected = current;
    final result = await showDialog<int>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
      title: const Text('Alege culoarea'),
      content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 10, runSpacing: 10, children: palette.map((color) => InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => setD(() { selected = color.value; hex.text = selected.toRadixString(16).padLeft(8, '0').toUpperCase(); }),
          child: Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: selected == color.value ? Theme.of(c).colorScheme.primary : Colors.white, width: selected == color.value ? 4 : 2))),
        )).toList()),
        const SizedBox(height: 18),
        TextField(controller: hex, decoration: const InputDecoration(labelText: 'Culoare HEX (AARRGGBB sau RRGGBB)', prefixText: '#'), onChanged: (v) {
          var t = v.trim().replaceAll('#','');
          if (t.length == 6) t = 'FF$t';
          final parsed = int.tryParse(t, radix: 16);
          if (parsed != null && t.length == 8) setD(() => selected = parsed);
        }),
        const SizedBox(height: 12),
        Container(height: 48, decoration: BoxDecoration(color: Color(selected), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const Text('PREVIZUALIZARE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(c, selected), child: const Text('Alege'))],
    )));
    hex.dispose();
    return result;
  }

  Future<void> _editTeam([Team? existing]) async {
    final n = TextEditingController(text: existing?.name ?? '');
    String? car = existing?.carId;
    String? financialManager = existing?.financialManagerId;
    final realUserIds = users.map((u) => u.id).toSet();
    final selected = <String>{...?existing?.members.where(realUserIds.contains)};

    final draft = await showDialog<Team>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(existing == null ? 'Adaugă echipă' : 'Editează echipă'),
          content: SizedBox(
            width: MediaQuery.sizeOf(d).width < 700 ? MediaQuery.sizeOf(d).width * .80 : 520,
            child: SingleChildScrollView(
              child: Column(children: [
                TextField(controller: n, decoration: const InputDecoration(labelText: 'Nume / pseudonim echipă *')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: car,
                  decoration: const InputDecoration(labelText: 'Mașină'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Fără mașină')),
                    ...cars.where((c) => c.active).map((c) => DropdownMenuItem<String?>(value: c.id, child: Text('${c.plate} · ${c.makeModel}'))),
                  ],
                  onChanged: (v) => setD(() => car = v),
                ),
                const SizedBox(height: 14),
                const Align(alignment: Alignment.centerLeft, child: Text('Membrii echipei', style: TextStyle(fontWeight: FontWeight.bold))),
                ...users.where((u) => u.active).map((u) => CheckboxListTile(
                  value: selected.contains(u.id),
                  onChanged: (v) => setD(() {
                    if (v == true) {
                      selected.add(u.id);
                    } else {
                      selected.remove(u.id);
                      if (financialManager == u.id) financialManager = null;
                    }
                  }),
                  secondary: (() { final f = u.functionIds.isNotEmpty ? _functionByIdLocal(u.functionIds.first) : null; return f == null ? Icon(u.function.icon) : functionKeyWidget(f.iconKey, size: 34, color: f.color); })(),
                  title: Text(u.name),
                  subtitle: Text(_functionNames(u)),
                  dense: true,
                )),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('${selected.length}_${financialManager ?? 'none'}'),
                  initialValue: selected.contains(financialManager) ? financialManager : null,
                  decoration: const InputDecoration(labelText: 'Gestionar financiar / diurnă'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Nesetat')),
                    ...users.where((u) => selected.contains(u.id)).map((u) => DropdownMenuItem<String?>(value: u.id, child: Text('${u.name} · ${_functionNames(u)}'))),
                  ],
                  onChanged: (v) => setD(() => financialManager = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              onPressed: () {
                final name = n.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(d).showSnackBar(const SnackBar(content: Text('Numele echipei este obligatoriu.')));
                  return;
                }
                Navigator.pop(d, Team(
                  id: existing?.id ?? 'team_${idNow()}',
                  name: name,
                  members: selected.toList(),
                  carId: car,
                  financialManagerId: financialManager,
                  active: existing?.active ?? true,
                ));
              },
              label: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
    n.dispose();
    if (draft == null) return;

    String memberKey(Iterable<String> ids) {
      final x = ids.toList()..sort();
      return x.join('|');
    }
    final duplicate = teams.any((t) =>
      t.id != draft.id &&
      t.active &&
      t.name.trim().toLowerCase() == draft.name.trim().toLowerCase() &&
      memberKey(t.members) == memberKey(draft.members));
    if (duplicate) {
      showErrorMessage(context, 'Există deja o echipă activă cu același nume și aceiași membri.');
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('teams').doc(draft.id), {
        'name': draft.name,
        'members': draft.members,
        'carId': draft.carId,
        'financialManagerId': draft.financialManagerId,
        'active': draft.active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final other in teams) {
        if (other.id == draft.id) continue;
        final cleaned = other.members.where((id) => !draft.members.contains(id)).toList();
        if (cleaned.length != other.members.length) {
          batch.set(db.collection('teams').doc(other.id), {'members': cleaned, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }
      final formerMembers = <String>{...?existing?.members};
      for (final u in users) {
        if (draft.members.contains(u.id)) {
          batch.set(db.collection('users').doc(u.id), {'teamId': draft.id}, SetOptions(merge: true));
        } else if (formerMembers.contains(u.id)) {
          batch.set(db.collection('users').doc(u.id), {'teamId': null}, SetOptions(merge: true));
        }
      }
      await batch.commit();

      for (final other in teams) {
        if (other.id != draft.id) other.members.removeWhere((id) => draft.members.contains(id));
      }
      final idx = teams.indexWhere((t) => t.id == draft.id);
      if (idx >= 0) teams[idx] = draft; else teams.add(draft);
      for (final u in users) {
        if (draft.members.contains(u.id)) {
          u.teamId = draft.id;
        } else if (formerMembers.contains(u.id)) {
          u.teamId = null;
        }
      }
      if (mounted) setState(() {});
      widget.log(existing == null ? 'Echipă creată' : 'Echipă modificată', draft.name);
      if (mounted) showSuccessMessage(context, existing == null ? 'Echipa ${draft.name} a fost creată.' : 'Modificările pentru ${draft.name} au fost salvate.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Echipa nu a putut fi salvată: $e');
    }
  }

  Future<void> _setTeamActive(Team team, bool value) async {
    try {
      await FirebaseFirestore.instance.collection('teams').doc(team.id).set({
        'active': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      setState(() => team.active = value);
      widget.log(value ? 'Echipă activată' : 'Echipă dezactivată', team.name);
      showSuccessMessage(context, value ? '${team.name} a fost activată.' : '${team.name} a fost dezactivată.');
    } catch (e) {
      showErrorMessage(context, 'Statusul echipei nu a putut fi schimbat: $e');
    }
  }

  Future<void> _deleteTeam(Team team) async {
    final scheduleCount = schedules.where((x) => x.teamId == team.id).length;
    final recordCount = records.where((x) => x.teamId == team.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Șterge definitiv echipa?'),
        content: Text(
          '${team.name} va dispărea din lista de echipe. Membrii vor rămâne conturi active, dar fără echipă. '
          'Istoricul existent nu este șters ($scheduleCount grafice/zile, $recordCount execuții).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anulează')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error, foregroundColor: Theme.of(d).colorScheme.onError),
            onPressed: () => Navigator.pop(d, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Șterge definitiv'),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.delete(db.collection('teams').doc(team.id));
      for (final u in users.where((u) => u.teamId == team.id || team.members.contains(u.id))) {
        batch.set(db.collection('users').doc(u.id), {'teamId': null}, SetOptions(merge: true));
      }
      await batch.commit();
      for (final u in users) { if (u.teamId == team.id) u.teamId = null; }
      setState(() => teams.removeWhere((t) => t.id == team.id));
      widget.log('Echipă ștearsă definitiv', team.name);
      showSuccessMessage(context, 'Echipa ${team.name} a fost ștearsă.');
    } catch (e) {
      showErrorMessage(context, 'Echipa nu a putut fi ștearsă: $e');
    }
  }


  Future<void> _cleanupDuplicateTeams() async {
    final groups = <String, List<Team>>{};
    for (final t in teams) {
      final members = t.members.toList()..sort();
      final key = '${t.name.trim().toLowerCase()}|${members.join(',')}|${t.carId ?? ''}';
      groups.putIfAbsent(key, () => <Team>[]).add(t);
    }
    final removable = <Team>[];
    for (final g in groups.values.where((g) => g.length > 1)) {
      g.sort((a,b) => a.id.compareTo(b.id));
      for (final t in g.skip(1)) {
        final hasHistory = schedules.any((x) => x.teamId == t.id) || records.any((x) => x.teamId == t.id) || expenses.any((x) => x.teamId == t.id) || perDiems.any((x) => x.teamId == t.id);
        if (!hasHistory) removable.add(t);
      }
    }
    if (removable.isEmpty) {
      if (mounted) showSuccessMessage(context, 'Nu există echipe duplicate fără istoric care să poată fi curățate automat.');
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Curăță echipe duplicate'),
      content: Text('Vor fi șterse ${removable.length} duplicate exacte care nu au Grafic de lucru, execuții sau date financiare. Echipele cu istoric nu sunt atinse.'),
      actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Curăță'))],
    )) ?? false;
    if (!ok) return;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    for (final t in removable) batch.delete(db.collection('teams').doc(t.id));
    await batch.commit();
    if (mounted) showSuccessMessage(context, '${removable.length} echipe duplicate au fost eliminate.');
  }

  Widget _teams() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
        const Text('Echipe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _cleanupDuplicateTeams, icon: const Icon(Icons.cleaning_services_outlined), label: const Text('Curăță duplicate')),
          FilledButton.icon(onPressed: () => _editTeam(), icon: const Icon(Icons.add), label: const Text('Adaugă echipă')),
        ]),
      ]),
      const SizedBox(height: 12),
      if (teams.isEmpty) const _Empty(icon: Icons.groups_outlined, text: 'Nu există încă echipe.'),
      ...teams.map((t) {
        final sameName = teams.where((x) => x.id != t.id && x.name.trim().toLowerCase() == t.name.trim().toLowerCase()).length;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: t.active ? sectionAccent('Echipe').withValues(alpha: .14) : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(Icons.groups, color: t.active ? sectionAccent('Echipe') : Theme.of(context).colorScheme.outline),
            ),
            title: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (!t.active) const Chip(label: Text('Inactivă')),
              if (sameName > 0) Chip(avatar: const Icon(Icons.warning_amber_rounded, size: 17), label: Text('$sameName nume duplicat')),
            ]),
            subtitle: Text('${t.members.map(_safeName).join(', ')} · mașină ${t.carId == null ? 'nesetată' : cars.firstWhere((c) => c.id == t.carId, orElse: () => Car(id: 'x', plate: '—')).plate} · gestionar ${t.financialManagerId == null ? 'nesetat' : _safeName(t.financialManagerId!)}'),
            trailing: MediaQuery.sizeOf(context).width < 700
                ? PopupMenuButton<String>(
                    tooltip: 'Acțiuni echipă',
                    onSelected: (value) {
                      if (value == 'edit') _editTeam(t);
                      if (value == 'toggle') _setTeamActive(t, !t.active);
                      if (value == 'delete') _deleteTeam(t);
                    },
                    itemBuilder: (c) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editează'))),
                      PopupMenuItem(value: 'toggle', child: ListTile(leading: Icon(t.active ? Icons.pause_circle_outline : Icons.play_circle_outline), title: Text(t.active ? 'Dezactivează' : 'Activează'))),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever, color: Theme.of(c).colorScheme.error), title: Text('Șterge definitiv'))),
                    ],
                  )
                : Wrap(spacing: 2, children: [
                    IconButton(tooltip: 'Editează echipa', onPressed: () => _editTeam(t), icon: const Icon(Icons.edit_outlined)),
                    IconButton(tooltip: 'Șterge definitiv echipa', onPressed: () => _deleteTeam(t), icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error)),
                    Switch(value: t.active, onChanged: (v) => _setTeamActive(t, v)),
                  ]),
          ),
        );
      }),
    ],
  );
 Future<void> _editFunctionDefinition([FunctionDefinition? existing]) async {
   final name = TextEditingController(text: existing?.name ?? '');
   int colorValue = existing?.colorValue ?? Colors.blue.value;
   final permissions = <String>{...?existing?.permissions};
   final selectedBadges = <String>[...(existing?.badgeKeys ?? <String>[existing?.iconKey ?? 'badge_driver'])]
     ..removeWhere((e) => e.trim().isEmpty || e == 'badge_coordinator');
   for (var i = 0; i < selectedBadges.length; i++) { if (selectedBadges[i] == 'badge_machine') selectedBadges[i] = 'badge_worker'; }
   if (selectedBadges.isEmpty) selectedBadges.add('badge_driver');
   while (selectedBadges.length > 3) { selectedBadges.removeLast(); }
   bool active = existing?.active ?? true;
   final grouped = <String, List<FunctionPermission>>{};
   for (final permission in FunctionPermission.values) {
     grouped.putIfAbsent(functionPermissionGroup(permission), () => <FunctionPermission>[]).add(permission);
   }
   final result = await showDialog<FunctionDefinition>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
     title: Text(existing == null ? 'Adaugă funcție' : 'Editează funcția'),
     content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 660, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       TextField(controller: name, decoration: const InputDecoration(labelText: 'Denumire funcție *')),
       const SizedBox(height: 12),
       const Text('Ecusoane (alege 1, 2 sau maximum 3)', style: TextStyle(fontWeight: FontWeight.bold)),
       const SizedBox(height: 6),
       Wrap(spacing: 8, runSpacing: 8, children: [
         ...availableBadgeKeys.map((key) {
           final selected = selectedBadges.contains(key);
           return FilterChip(
             selected: selected,
             selectedColor: Color(colorValue).withValues(alpha: .18),
             side: BorderSide(color: selected ? Color(colorValue).withValues(alpha: .75) : Theme.of(c).colorScheme.outlineVariant),
             avatar: functionKeyWidget(key, size: 36, color: Color(colorValue)),
             label: Text(badgeLabel(key), style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
             onSelected: (value) {
               setD(() {
                 if (value) {
                   if (!selected && selectedBadges.length < 3) selectedBadges.add(key);
                 } else {
                   if (selectedBadges.length > 1) selectedBadges.remove(key);
                 }
               });
             },
           );
         }),
       ]),
       const SizedBox(height: 6),
       Text('Selectate: ${selectedBadges.map(badgeLabel).join(', ')}', style: Theme.of(c).textTheme.bodySmall),
       const SizedBox(height: 10),
       Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
         Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           const Text('Previzualizare ecusoane',style:TextStyle(fontWeight:FontWeight.w800)),
           const SizedBox(height:8),
           badgeStripWidget(selectedBadges,size:48,color:Color(colorValue)),
           const SizedBox(height:5),
           Text('Contur funcție: #${colorValue.toRadixString(16).padLeft(8,'0').toUpperCase()}',style:Theme.of(c).textTheme.bodySmall),
         ])),
         OutlinedButton(onPressed: () async { final v = await _pickColorValue(colorValue); if (v != null) setD(() => colorValue = v); }, child: const Text('Culoare')),
       ]),
       SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setD(() => active = v), title: const Text('Funcție activă')),
       const Divider(),
       const Text('Drepturi', style: TextStyle(fontWeight: FontWeight.bold)),
       const SizedBox(height: 6),
       ...grouped.entries.map((entry) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Padding(
           padding: const EdgeInsets.only(top: 8, bottom: 4),
           child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900)),
         ),
         ...entry.value.map((p) => CheckboxListTile(
           contentPadding: EdgeInsets.zero,
           value: permissions.contains(p.name),
           onChanged: (v) => setD(() => v == true ? permissions.add(p.name) : permissions.remove(p.name)),
           title: Text(p.label),
           dense: true,
         )),
       ])),
     ]))),
     actions: [
       TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
       FilledButton(onPressed: () {
         if (name.text.trim().isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Denumirea funcției este obligatorie.'))); return; }
         if (selectedBadges.isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Alege cel puțin un ecuson.'))); return; }
         Navigator.pop(c, FunctionDefinition(id: existing?.id ?? 'fn_${idNow()}', name: name.text.trim(), iconKey: selectedBadges.first, badgeKeys: selectedBadges, colorValue: colorValue, permissions: permissions, active: active));
       }, child: const Text('Salvează')),
     ],
   )));
   name.dispose();
   if (result == null) return;
   try {
     await FirebaseFirestore.instance.collection('functions').doc(result.id).set({
       'name': result.name, 'iconKey': result.iconKey, 'badgeKeys': result.badgeKeys, 'colorValue': result.colorValue,
       'permissions': result.permissions.toList()..sort(), 'active': result.active, 'updatedAt': FieldValue.serverTimestamp(),
     }, SetOptions(merge: true));
     final idx = functionDefinitions.indexWhere((x) => x.id == result.id);
     setState(() { if (idx >= 0) functionDefinitions[idx] = result; else functionDefinitions.add(result); });
     widget.log(existing == null ? 'Funcție adăugată' : 'Funcție modificată', result.name);
     if (mounted) showSuccessMessage(context, existing == null ? 'Funcția ${result.name} a fost adăugată.' : 'Funcția ${result.name} a fost actualizată.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Funcția nu a putut fi salvată: $e');
   }
 }

 Future<void> _setUserFunctions(DocumentReference<Map<String,dynamic>> ref, String display, List<String> ids) async {
   final clean = ids.toSet().where((id) => functionDefinitions.any((f) => f.id == id)).toList()..sort();
   final legacy = clean.isEmpty ? '' : clean.first;
   final effective = <String>{};
   for (final id in clean) {
     final def = _functionByIdLocal(id);
     if (def != null && def.active) effective.addAll(def.permissions);
   }
   final sortedPermissions = effective.toList()..sort();
   try {
     await ref.update({'functionIds': clean, 'function': legacy, 'effectivePermissions': sortedPermissions, 'updatedAt': FieldValue.serverTimestamp()});
     widget.log('Funcții cont modificate', '$display · ${clean.map((id) => _functionByIdLocal(id)?.name ?? id).join(', ')}');
     if (mounted) showSuccessMessage(context, 'Funcțiile pentru $display au fost salvate.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Funcțiile nu au putut fi salvate: $e');
   }
 }

 Widget _members() => Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
     Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
       const SizedBox(width: 360, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Text('Membri / Conturi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
         SizedBox(height: 4),
         Text('Atribuie una sau mai multe funcții direct aici. Funcțiile noi se pot crea fără să părăsești pagina.'),
       ])),
       FilledButton.icon(onPressed: () => _editFunctionDefinition(), icon: const Icon(Icons.add), label: const Text('Adaugă funcție')),
     ]),
     const SizedBox(height: 12),
     StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
       stream: FirebaseFirestore.instance.collection('users').snapshots(),
       builder: (context, snap) {
         if (snap.hasError) return _InfoCard(icon: Icons.error_outline, title: 'Conturi Firebase', text: 'Eroare: ${snap.error}');
         if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())));
         final docs = snap.data!.docs.toList()..sort((a,b) {
           final ap = (a.data()['status'] ?? '').toString() == 'pending';
           final bp = (b.data()['status'] ?? '').toString() == 'pending';
           if (ap != bp) return ap ? -1 : 1;
           return (a.data()['name'] ?? a.data()['email'] ?? '').toString().compareTo((b.data()['name'] ?? b.data()['email'] ?? '').toString());
         });
         if (docs.isEmpty) return const _Empty(icon: Icons.person_off_outlined, text: 'Nu există conturi Firebase.');
         final defs = functionDefinitions.where((f) => f.active).toList()..sort((a,b) => a.name.compareTo(b.name));
         return Column(children: docs.map((doc) {
           final d = doc.data();
           final role = (d['role'] ?? 'member').toString();
           final active = d['active'] == true;
           final status = (d['status'] ?? (active ? 'approved' : 'pending')).toString();
           final display = (d['name'] ?? d['email'] ?? doc.id).toString();
           final email = (d['email'] ?? '').toString();
           final pending = status == 'pending' && !active;
           final assigned = d['functionIds'] is List
               ? (d['functionIds'] as List).map((e) => e.toString()).where((e)=>e.isNotEmpty).toSet()
               : <String>{(d['function'] ?? '').toString()}.where((e)=>e.isNotEmpty).toSet();
           final photoData = (d['photoBase64'] ?? '').toString();
           final photo = decodeProfilePhoto(photoData);
           return Card(child: Padding(
             padding: const EdgeInsets.all(12),
             child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 GestureDetector(
                   onTap:photo==null?null:()=>showProfilePhotoViewer(context,photoData,display),
                   child:CircleAvatar(radius: 28, backgroundImage: photo == null ? null : MemoryImage(photo), child: photo == null ? Icon(role == 'admin' ? Icons.admin_panel_settings : Icons.person_outline) : null),
                 ),
                 const SizedBox(width: 12),
                 Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                     Text(display, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                     if (pending) const Chip(label: Text('În așteptare')),
                     if (role == 'admin') const Chip(label: Text('ADMIN')),
                   ]),
                   if (email.isNotEmpty) Text(email),
                   if (assigned.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: memberBadgeStripWidget(functionDefinitions, assigned, size: 32)),
                   Text('UID: ${doc.id}', style: Theme.of(context).textTheme.bodySmall),
                 ])),
                 if (role != 'admin') Switch(value: active, onChanged: (v) async {
                   try {
                     await doc.reference.update({'active': v, 'status': v ? 'approved' : 'disabled', 'updatedAt': FieldValue.serverTimestamp()});
                     widget.log(v ? 'Cont activat' : 'Cont dezactivat', display);
                     if (mounted) showSuccessMessage(context, v ? '$display a fost activat.' : '$display a fost dezactivat.');
                   } catch (e) {
                     if (mounted) showErrorMessage(context, 'Contul nu a putut fi actualizat: $e');
                   }
                 }),
               ]),
               if (role != 'admin') ...[
                 const SizedBox(height: 10),
                 const Text('Funcții', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 6),
                 Wrap(spacing: 8, runSpacing: 8, children: [
                   ...defs.map((f) => FilterChip(
                     selected: assigned.contains(f.id),
                     selectedColor: f.color.withValues(alpha: .18),
                     checkmarkColor: f.color,
                     side: BorderSide(color: assigned.contains(f.id) ? f.color.withValues(alpha: .75) : Theme.of(context).colorScheme.outlineVariant),
                     avatar: functionKeyWidget(f.iconKey, size: 30, color: f.color),
                     label: Text(f.name, style: TextStyle(fontWeight: assigned.contains(f.id) ? FontWeight.w800 : FontWeight.w600)),
                     onSelected: (selected) async {
                       final next = <String>{...assigned};
                       selected ? next.add(f.id) : next.remove(f.id);
                       await _setUserFunctions(doc.reference, display, next.toList());
                     },
                   )),
                   ActionChip(avatar: const Icon(Icons.add, size: 17), label: const Text('Funcție nouă'), onPressed: () => _editFunctionDefinition()),
                 ]),
               ],
             ]),
           ));
         }).toList());
       },
     ),
   ],
 );
 Future<void> _editCar([Car? existing]) async {
   final plate = TextEditingController(text: existing?.plate ?? '');
   final model = TextEditingController(text: existing?.makeModel ?? '');
   final rca = TextEditingController(text: existing?.rcaUntil == null ? '' : formatDate(existing!.rcaUntil!));
   final itp = TextEditingController(text: existing?.itpUntil == null ? '' : formatDate(existing!.itpUntil!));
   final rov = TextEditingController(text: existing?.rovinietaUntil == null ? '' : formatDate(existing!.rovinietaUntil!));
   final consumption = TextEditingController(text: existing == null || existing.averageConsumption <= 0 ? '' : existing.averageConsumption.toStringAsFixed(1));
   final fuelPrice = TextEditingController(text: existing == null || existing.fuelPricePerLiter <= 0 ? '' : existing.fuelPricePerLiter.toStringAsFixed(2));
   String fuelType = existing?.fuelType ?? 'Motorină';
   DateTime? parseDateInput(String v) {
     final p = v.trim().split('-');
     if (p.length != 4) return null;
     final day = int.tryParse(p[1]);
     final year = int.tryParse(p[3]);
     const months = ['ianuarie','februarie','martie','aprilie','mai','iunie','iulie','august','septembrie','octombrie','noiembrie','decembrie'];
     final month = months.indexOf(p[2]);
     if (day == null || year == null || month < 0) return null;
     return DateTime(year, month + 1, day);
   }
   final result = await showDialog<bool>(
     context: context,
     builder: (d) => AlertDialog(
       title: Text(existing == null ? 'Adaugă mașină' : 'Editează mașină'),
       content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
         TextField(controller: plate, decoration: const InputDecoration(labelText: 'Număr de înmatriculare')),
         TextField(controller: model, decoration: const InputDecoration(labelText: 'Marcă / model')),
         TextField(controller: rca, decoration: const InputDecoration(labelText: 'RCA · ex. luni-30-septembrie-2026')),
         TextField(controller: itp, decoration: const InputDecoration(labelText: 'ITP · ex. luni-30-septembrie-2026')),
         TextField(controller: rov, decoration: const InputDecoration(labelText: 'Rovinietă · ex. luni-30-septembrie-2026')),
         const SizedBox(height: 8),
         DropdownButtonFormField<String>(value:fuelType,decoration:const InputDecoration(labelText:'Carburant'),items:const ['Motorină','Benzină','GPL','Electric'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)fuelType=v;}),
         const SizedBox(height: 8),
         TextField(controller:consumption,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Consum mediu (l/100 km)',helperText:'Folosit pentru sumarul Graficului de lucru')),
         const SizedBox(height: 8),
         TextField(controller:fuelPrice,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Preț carburant (lei/l)',helperText:'Poate fi actualizat manual după prețul OMV')),
         Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{await launchUrl(Uri.parse('https://www.omv.ro/ro/mobilitate/carburanti/localizare-statii-omv'),mode:LaunchMode.externalApplication);},icon:appAssetIcon('assets/ui/fuel.png',size:20,accent:Colors.red),label:const Text('Deschide prețurile OMV'))),
       ])),
       actions: [
         TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
         FilledButton(onPressed: () {
           if (plate.text.trim().isEmpty) return;
           final c = existing ?? Car(id: idNow(), plate: plate.text.trim());
           c.plate = plate.text.trim();
           c.makeModel = model.text.trim();
           c.rcaUntil = parseDateInput(rca.text);
           c.itpUntil = parseDateInput(itp.text);
           c.rovinietaUntil = parseDateInput(rov.text);
           c.fuelType = fuelType;
           c.averageConsumption = double.tryParse(consumption.text.replaceAll(',', '.')) ?? 0;
           c.fuelPricePerLiter = double.tryParse(fuelPrice.text.replaceAll(',', '.')) ?? 0;
           if (existing == null) cars.add(c);
           widget.log(existing == null ? 'Mașină adăugată' : 'Mașină modificată', c.plate);
           widget.onChanged();
           Navigator.pop(d, true);
         }, child: const Text('Salvează')),
       ],
     ),
   );
   if (result == true) {
     widget.onChanged();
     setState(() {});
     if (mounted) showSuccessMessage(context, existing == null ? 'Mașina a fost adăugată.' : 'Datele mașinii au fost salvate.');
   }
 }
 Future<void> _removeCar(Car c) async {
   final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Elimină mașina?'), content: Text('${c.plate} va fi scoasă din lista de mașini.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Elimină'))]));
   if (ok == true) {
     for (final t in teams) {
       if (t.carId == c.id) t.carId = null;
     }
     cars.remove(c);
     await FirebaseFirestore.instance.collection('cars').doc(c.id).delete();
     widget.onChanged();
     setState(() {});
     if (mounted) showSuccessMessage(context, '${c.plate} a fost eliminată.');
   }
 }
 Widget _cars() => Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
     Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
       const Text('Mașini', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
       Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(c)=>const AlertDialog(title:Text('Setări Mașini'),content:Text('Consum mediu și preț carburant se setează direct pe fiecare mașină și intră automat în sumarul Graficului de lucru. Prețul OMV se verifică din butonul din editarea mașinii.'))),icon:appAssetIcon('assets/ui/settings.png',size:20,accent:Theme.of(context).colorScheme.primary),label:const Text('Setări')),FilledButton.icon(onPressed: () => _editCar(), icon: const Icon(Icons.add), label: const Text('Adaugă mașină'))]),
     ]),
     const SizedBox(height: 12),
     ...cars.map((c) => Card(child: ListTile(
       leading: const Icon(Icons.directions_car),
       title: Text(c.plate),
       subtitle: Text('${c.makeModel} · ${c.fuelType} · ${c.averageConsumption > 0 ? '${c.averageConsumption.toStringAsFixed(1)} l/100 km' : 'consum nesetat'} · ${c.fuelPricePerLiter > 0 ? '${c.fuelPricePerLiter.toStringAsFixed(2)} lei/l' : 'preț nesetat'}\nRCA ${c.rcaUntil == null ? 'nesetat' : formatDate(c.rcaUntil!)} · ITP ${c.itpUntil == null ? 'nesetat' : formatDate(c.itpUntil!)} · Rovinietă ${c.rovinietaUntil == null ? 'nesetată' : formatDate(c.rovinietaUntil!)}'),
       isThreeLine: true,
       trailing: MediaQuery.sizeOf(context).width < 700
           ? PopupMenuButton<String>(
               tooltip: 'Acțiuni mașină',
               onSelected: (value) {
                 if (value == 'edit') _editCar(c);
                 if (value == 'delete') _removeCar(c);
                 if (value == 'toggle') { setState(() => c.active = !c.active); widget.onChanged(); showSuccessMessage(context, c.active ? '${c.plate} a fost activată.' : '${c.plate} a fost dezactivată.'); }
               },
               itemBuilder: (ctx) => [
                 const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editează'))),
                 PopupMenuItem(value: 'toggle', child: ListTile(leading: Icon(c.active ? Icons.pause_circle_outline : Icons.play_circle_outline), title: Text(c.active ? 'Dezactivează' : 'Activează'))),
                 PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever, color: Theme.of(ctx).colorScheme.error), title: const Text('Elimină'))),
               ],
             )
           : Wrap(children: [
               IconButton(tooltip: 'Editează datele mașinii', onPressed: () => _editCar(c), icon: const Icon(Icons.edit)),
               IconButton(tooltip: 'Elimină mașina', onPressed: () => _removeCar(c), icon: const Icon(Icons.delete_forever)),
               Switch(value: c.active, onChanged: (v) { setState(() => c.active = v); widget.onChanged(); showSuccessMessage(context, v ? '${c.plate} a fost activată.' : '${c.plate} a fost dezactivată.'); }),
             ]),
     ))),
   ],
 );
 Future<LocationContact?> _contactDialog([LocationContact? existing]) async {
   final name = TextEditingController(text: existing?.name ?? '');
   final phone = TextEditingController(text: existing?.phone ?? '');
   var role=(existing?.role.trim().isNotEmpty??false)?existing!.role:'Manager';
   if(!const ['Manager','Casierie','Alt contact'].contains(role))role='Alt contact';
   var smsEnabled=existing?.smsEnabled??true;
   final result = await showDialog<LocationContact>(context: context, builder: (c) => StatefulBuilder(builder:(c,setD)=>AlertDialog(
     title: Text(existing == null ? 'Adaugă contact' : 'Editează contact'),
     content: Column(mainAxisSize: MainAxisSize.min, children: [
       DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Tip contact'),items:const[
         DropdownMenuItem(value:'Manager',child:Text('Manager')),
         DropdownMenuItem(value:'Casierie',child:Text('Casierie')),
         DropdownMenuItem(value:'Alt contact',child:Text('Alt contact')),
       ],onChanged:(v){if(v!=null)setD(()=>role=v);}),
       const SizedBox(height: 8),
       TextField(controller: name, decoration: InputDecoration(labelText:role=='Casierie'?'Nume / denumire (opțional)':'Nume contact')),
       const SizedBox(height: 8),
       TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon *')),
       SwitchListTile(contentPadding:EdgeInsets.zero,value:smsEnabled,onChanged:(v)=>setD(()=>smsEnabled=v),title:const Text('Primește SMS automat')),
     ]),
     actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')), FilledButton(onPressed: () {
       if (phone.text.trim().isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Completează telefonul.'))); return; }
       Navigator.pop(c, LocationContact(name: name.text.trim().isEmpty?role:name.text.trim(), phone: phone.text.trim(),role:role,smsEnabled:smsEnabled));
     }, child: const Text('Salvează'))],
   )));
   name.dispose(); phone.dispose();
   return result;
 }

 Future<void> _editLocationAdmin([Location? existing]) async {
   final formKey = GlobalKey<FormState>();
   final n = TextEditingController(text: existing?.name ?? '');
   final a = TextEditingController(text: existing?.address ?? '');
   final m = TextEditingController(text: existing == null || existing.surfaceM2 == 0 ? '' : existing.surfaceM2.toString());
   final f = TextEditingController(text: existing == null || existing.facadeM2 == 0 ? '' : existing.facadeM2.toString());
   final note = TextEditingController(text: existing?.notes ?? '');
   final lat = TextEditingController(text: existing?.latitude?.toString() ?? '');
   final lng = TextEditingController(text: existing?.longitude?.toString() ?? '');
   String categoryId = existing?.categoryId ?? (categories.isNotEmpty ? categories.first.id : 'horeca');
   LocationStatus status = existing?.status ?? LocationStatus.open;
   final contacts = existing?.contacts.map((x) => LocationContact(name: x.name, phone: x.phone, role: x.role, smsEnabled: x.smsEnabled)).toList() ?? <LocationContact>[];
   final result = await showDialog<Location>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
     title: Text(existing == null ? 'Adaugă locație' : 'Editează locația'),
     content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 680, child: Form(key: formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       TextFormField(controller: n, decoration: const InputDecoration(labelText: 'Nume *'), validator: (v) => v == null || v.trim().isEmpty ? 'Numele este obligatoriu.' : null),
       const SizedBox(height: 8),
       TextFormField(controller: a, decoration: const InputDecoration(labelText: 'Adresă *'), validator: (v) => v == null || v.trim().isEmpty ? 'Adresa este obligatorie.' : null),
       const SizedBox(height: 8),
       Row(children: [
         Expanded(child: DropdownButtonFormField<String>(initialValue: categoryId, decoration: const InputDecoration(labelText: 'Categorie'), items: categories.where((x) => x.active || x.id == categoryId).map((x) => DropdownMenuItem(value: x.id, child: Row(children: [categoryBrandWidget(x.id, size: 24, fallbackColor: x.color), const SizedBox(width: 8), Text(x.name)]))).toList(), onChanged: (v) { if (v != null) setD(() => categoryId = v); })),
         const SizedBox(width: 8),
         Expanded(child: DropdownButtonFormField<LocationStatus>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: LocationStatus.values.map((x) => DropdownMenuItem(value: x, child: Text(x.label))).toList(), onChanged: (v) { if (v != null) setD(() => status = v); })),
       ]),
       const SizedBox(height: 8),
       Row(children: [
         Expanded(child: TextFormField(controller: m, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Suprafață / mochetă m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; })),
         const SizedBox(width: 8),
         Expanded(child: TextFormField(controller: f, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fațadă m²'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < 0 ? 'Număr invalid' : null; })),
       ]),
       const SizedBox(height: 8),
       Row(children: [
         Expanded(child: TextFormField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitudine'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < -90 || x > 90 ? 'Latitudine invalidă' : null; })),
         const SizedBox(width: 8),
         Expanded(child: TextFormField(controller: lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitudine'), validator: (v) { if ((v ?? '').trim().isEmpty) return null; final x = double.tryParse(v!.replaceAll(',', '.')); return x == null || x < -180 || x > 180 ? 'Longitudine invalidă' : null; })),
       ]),
       const SizedBox(height: 8),
       TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Observații / note')),
       const SizedBox(height: 14),
       Row(children: [const Expanded(child: Text('Manageri / contacte', style: TextStyle(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: () async { final x = await _contactDialog(); if (x != null) setD(() => contacts.add(x)); }, icon: const Icon(Icons.add), label: const Text('Adaugă contact'))]),
       if (contacts.isEmpty) const Text('Nu există contacte salvate.'),
       ...List.generate(contacts.length, (i) => ListTile(
         contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_outline), title: Text(contacts[i].name), subtitle: Text('${contacts[i].role} · ${contacts[i].phone}${contacts[i].smsEnabled?' · SMS automat':' · doar apel'}'),
         trailing: Wrap(spacing: 2, children: [
           IconButton(tooltip: 'Editează', onPressed: () async { final x = await _contactDialog(contacts[i]); if (x != null) setD(() => contacts[i] = x); }, icon: const Icon(Icons.edit_outlined)),
           IconButton(tooltip: 'Șterge contact', onPressed: () => setD(() => contacts.removeAt(i)), icon: const Icon(Icons.delete_outline)),
         ]),
       )),
     ])))),
     actions: [
       TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
       FilledButton(onPressed: () {
         if (!(formKey.currentState?.validate() ?? false)) return;
         final latText = lat.text.trim(), lngText = lng.text.trim();
         if ((latText.isEmpty) != (lngText.isEmpty)) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Completează ambele coordonate sau lasă-le pe ambele goale.'))); return; }
         Navigator.pop(c, Location(
           id: existing?.id ?? idNow(), name: n.text.trim(), address: a.text.trim(), type: legacyTypeForCategory(categoryId), categoryId: categoryId, status: status,
           latitude: latText.isEmpty ? null : double.parse(latText.replaceAll(',', '.')), longitude: lngText.isEmpty ? null : double.parse(lngText.replaceAll(',', '.')),
           phone: contacts.isEmpty ? null : contacts.first.phone, contacts: contacts,
           surfaceM2: double.tryParse(m.text.replaceAll(',', '.')) ?? 0, facadeM2: double.tryParse(f.text.replaceAll(',', '.')) ?? 0,
           notes: note.text.trim(), active: true,
         ));
       }, child: const Text('Salvează')),
     ],
   )));
   n.dispose(); a.dispose(); m.dispose(); f.dispose(); note.dispose(); lat.dispose(); lng.dispose();
   if (result == null) return;
   try {
     await widget.saveLocation(result);
     widget.log(existing == null ? 'Locație adăugată din Admin' : 'Locație editată din Admin', result.name);
     if (mounted) showSuccessMessage(context, '${result.name} a fost salvată.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Locația nu a putut fi salvată: $e');
   }
 }

 Future<void> _deleteLocationPermanent(Location l) async {
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: const Text('Ștergere definitivă'),
     content: Text('${l.name} va fi ștearsă definitiv din registru și va dispărea automat de pe hartă. Istoricul execuțiilor deja înregistrate rămâne în Centralizator. Continui?'),
     actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, foregroundColor: Theme.of(c).colorScheme.onError), onPressed: () => Navigator.pop(c, true), child: const Text('Șterge definitiv'))],
   )) ?? false;
   if (!ok) return;
   try {
     await widget.deleteLocation(l.id);
     widget.log('Locație ștearsă definitiv', l.name);
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l.name} a fost ștearsă definitiv.')));
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ștergerea a eșuat: $e')));
   }
 }

 Future<void> _changeLocationStatus(Location l, LocationStatus status) async {
   try {
     final updated = Location(
       id: l.id, name: l.name, address: l.address, type: l.type, categoryId: l.categoryId, status: status,
       latitude: l.latitude, longitude: l.longitude, phone: l.phone,
       contacts: l.contacts.map((x) => LocationContact(name: x.name, phone: x.phone, role: x.role, smsEnabled: x.smsEnabled)).toList(),
       surfaceM2: l.surfaceM2, facadeM2: l.facadeM2, notes: l.notes, active: true,
     );
     await widget.saveLocation(updated);
     widget.log('Status locație modificat', '${l.name} · ${status.label}');
     if (mounted) showSuccessMessage(context, '${l.name}: ${status.label}.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Statusul locației nu a putut fi salvat: $e');
   }
 }

 Widget _locations() {
   final cats = [...categories]..sort((a,b) => a.name.compareTo(b.name));
   return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
     Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
       const SizedBox(width: 460, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Text('Locații', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
         SizedBox(height: 4),
         Text('Aici editezi datele, categoria și statusul. Hartă rămâne doar pentru vizualizare și poziționare GPS.'),
       ])),
       FilledButton.icon(onPressed: () => _editLocationAdmin(), icon: const Icon(Icons.add), label: const Text('Adaugă locație')),
     ]),
     const SizedBox(height: 12),
     ...cats.map((cat) {
       final items = locations.where((l) => l.categoryId == cat.id).toList()..sort((a,b) => a.name.compareTo(b.name));
       return Card(child: ExpansionTile(
         leading: categoryBrandWidget(cat.id, size: 34, fallbackColor: cat.color),
         title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
         subtitle: Text('${items.length} locații'),
         children: items.isEmpty ? [const ListTile(title: Text('Nu există locații în această categorie.'))] : items.map((l) => ListTile(
           leading: Icon(l.status.icon, color: l.status.color),
           title: Text(l.name),
           subtitle: Text('${l.address}\n${l.status.label} · ${l.latitude == null ? 'fără GPS' : 'GPS salvat'}'),
           isThreeLine: true,
           trailing: MediaQuery.sizeOf(context).width < 700
               ? PopupMenuButton<String>(
                   tooltip: 'Acțiuni locație',
                   onSelected: (value) {
                     if (value == 'edit') _editLocationAdmin(l);
                     if (value == 'delete') _deleteLocationPermanent(l);
                     if (value == 'open') _changeLocationStatus(l, LocationStatus.open);
                     if (value == 'temporary') _changeLocationStatus(l, LocationStatus.temporarilyClosed);
                     if (value == 'permanent') _changeLocationStatus(l, LocationStatus.permanentlyClosed);
                   },
                   itemBuilder: (c) => [
                     const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editează'))),
                     const PopupMenuDivider(),
                     const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.check_circle_outline, color: Colors.green), title: Text('Locație deschisă'))),
                     const PopupMenuItem(value: 'temporary', child: ListTile(leading: Icon(Icons.pause_circle_outline, color: Colors.orange), title: Text('Închisă temporar'))),
                     const PopupMenuItem(value: 'permanent', child: ListTile(leading: Icon(Icons.cancel_outlined, color: Colors.redAccent), title: Text('Închisă definitiv'))),
                     const PopupMenuDivider(),
                     PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever, color: Theme.of(c).colorScheme.error), title: const Text('Șterge definitiv'))),
                   ],
                 )
               : Wrap(spacing: 2, children: [
                   IconButton(tooltip: 'Editează', onPressed: () => _editLocationAdmin(l), icon: const Icon(Icons.edit_outlined)),
                   PopupMenuButton<LocationStatus>(
                     tooltip: 'Schimbă statusul',
                     onSelected: (status) => _changeLocationStatus(l, status),
                     itemBuilder: (_) => LocationStatus.values.map((x) => PopupMenuItem(value: x, child: Row(children: [Icon(x.icon, color: x.color), const SizedBox(width: 8), Text(x.label)]))).toList(),
                     icon: const Icon(Icons.flag_outlined),
                   ),
                   IconButton(tooltip: 'Șterge definitiv', onPressed: () => _deleteLocationPermanent(l), icon: const Icon(Icons.delete_forever)),
                 ]),
         )).toList(),
       ));
     }),
   ]);
 }

 Future<void> _editCategory([LocationCategory? existing]) async {
   final name = TextEditingController(text: existing?.name ?? '');
   int colorValue = existing?.colorValue ?? Colors.blueGrey.value;
   bool active = existing?.active ?? true;
   final result = await showDialog<LocationCategory>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
     title: Text(existing == null ? 'Adaugă categorie' : 'Editează categoria'),
     content: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
       TextField(controller: name, decoration: const InputDecoration(labelText: 'Denumire categorie *')),
       const SizedBox(height: 10),
       ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: existing?.id == 'million' ? Colors.red : existing?.id == 'magic' ? Colors.black87 : Color(colorValue)), title: const Text('Culoare categorie'), subtitle: Text(existing?.id == 'million' ? 'Million are culoare fixă: roșu.' : existing?.id == 'magic' ? 'Magic are culoare fixă: negru.' : 'Se aplică pe hartă, liste, Grafic de lucru și Dashboard.'), trailing: (existing?.id == 'million' || existing?.id == 'magic') ? const Chip(label: Text('FIXĂ')) : OutlinedButton(onPressed: () async { final v = await _pickColorValue(colorValue); if (v != null) setD(() => colorValue = v); }, child: const Text('Alege culoarea'))),
       SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setD(() => active = v), title: const Text('Categorie activă')),
     ])),
     actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')), FilledButton(onPressed: () {
       if (name.text.trim().isEmpty) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Denumirea categoriei este obligatorie.'))); return; }
       Navigator.pop(c, LocationCategory(id: existing?.id ?? 'cat_${idNow()}', name: name.text.trim(), colorValue: colorValue, active: active));
     }, child: const Text('Salvează'))],
   )));
   name.dispose();
   if (result == null) return;
   if (result.id == 'million') result.colorValue = Colors.red.value;
   if (result.id == 'magic') result.colorValue = Colors.black87.value;
   try {
     await FirebaseFirestore.instance.collection('locationCategories').doc(result.id).set({'name':result.name,'colorValue':result.colorValue,'active':result.active,'updatedAt':FieldValue.serverTimestamp()}, SetOptions(merge:true));
     final idx = categories.indexWhere((x) => x.id == result.id);
     setState(() { if (idx >= 0) categories[idx] = result; else categories.add(result); });
     widget.log(existing == null ? 'Categorie locații adăugată' : 'Categorie locații modificată', result.name);
     if (mounted) showSuccessMessage(context, existing == null ? 'Categoria ${result.name} a fost adăugată.' : 'Categoria ${result.name} a fost actualizată.');
   } catch (e) { if (mounted) showErrorMessage(context, 'Categoria nu a putut fi salvată: $e'); }
 }

 Future<void> _deleteCategory(LocationCategory cat) async {
   final used = locations.where((l) => l.categoryId == cat.id).length;
   if (used > 0) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoria ${cat.name} este folosită de $used locații. Mută locațiile înainte de ștergere.'))); return; }
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Șterge categoria?'), content: Text(cat.name), actions: [TextButton(onPressed: () => Navigator.pop(c,false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(c,true), child: const Text('Șterge'))])) ?? false;
   if (!ok) return;
   await FirebaseFirestore.instance.collection('locationCategories').doc(cat.id).delete();
   setState(() => categories.removeWhere((x) => x.id == cat.id));
   widget.log('Categorie locații ștearsă', cat.name); if (mounted) showSuccessMessage(context, 'Categoria ${cat.name} a fost ștearsă.');
 }

 Widget _categories() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
   Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
     const SizedBox(width: 480, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Categorii locații', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Million, Magic, HoReCa, Cazări și orice categorie nouă. Culoarea este globală și se aplică imediat peste tot.')])),
     FilledButton.icon(onPressed: () => _editCategory(), icon: const Icon(Icons.add), label: const Text('Adaugă categorie')),
   ]),
   const SizedBox(height: 12),
   ...([...categories]..sort((a,b)=>a.name.compareTo(b.name))).map((cat) => Card(child: ListTile(
     leading: categoryBrandWidget(cat.id, size: 38, fallbackColor: cat.color), title: Text(cat.name), subtitle: Text('${locations.where((l)=>l.categoryId==cat.id).length} locații · ${cat.active?'activă':'inactivă'} · #${cat.colorValue.toRadixString(16).padLeft(8,'0').toUpperCase()}'),
     trailing: Wrap(spacing: 2, children: [IconButton(tooltip:'Editează',onPressed:()=>_editCategory(cat),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Șterge',onPressed:()=>_deleteCategory(cat),icon:const Icon(Icons.delete_outline))]),
   ))),
 ]);
 Future<void> _sendSystemNotification() async {
   final recipients = users.where((u) => u.active).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
   if (recipients.isEmpty) {
     if (mounted) showErrorMessage(context, 'Nu există membri activi care să primească notificarea.');
     return;
   }
   final message = TextEditingController();
   final selected = <String>{};
   final send = await showDialog<bool>(
     context: context,
     builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
       title: const Text('Trimite notificare de sistem'),
       content: SizedBox(
         width: 620,
         child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           const _InfoCard(
             icon: Icons.info_outline,
             title: 'Expeditor: Sistem',
             text: 'Membrii vor vedea notificarea ca fiind transmisă de Sistem. Numele Adminului nu este afișat.',
           ),
           const SizedBox(height: 10),
           TextField(
             controller: message,
             minLines: 3,
             maxLines: 7,
             decoration: const InputDecoration(labelText: 'Text notificare', hintText: 'Scrie mesajul care trebuie transmis...'),
           ),
           const SizedBox(height: 12),
           Row(children: [
             Expanded(child: Text('Destinatari (${selected.length}/${recipients.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
             TextButton(onPressed: () => setD(() {
               if (selected.length == recipients.length) {
                 selected.clear();
               } else {
                 selected..clear()..addAll(recipients.map((u) => u.id));
               }
             }), child: Text(selected.length == recipients.length ? 'Debifează toate' : 'Bifează toate')),
           ]),
           const SizedBox(height: 4),
           ...recipients.map((u) {
             final functionText = u.functionIds.isEmpty
                 ? u.function.label
                 : u.functionIds.map((id) => _functionByIdLocal(id)?.name ?? id).join(', ');
             return CheckboxListTile(
               contentPadding: EdgeInsets.zero,
               value: selected.contains(u.id),
               onChanged: (v) => setD(() {
                 if (v == true) { selected.add(u.id); } else { selected.remove(u.id); }
               }),
               title: Text(u.name),
               subtitle: Text(functionText),
               secondary: const Icon(Icons.person_outline),
             );
           }),
         ])),
       ),
       actions: [
         TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')),
         FilledButton.icon(
           onPressed: () {
             if (message.text.trim().isEmpty || selected.isEmpty) return;
             Navigator.pop(c, true);
           },
           icon: const Icon(Icons.send),
           label: const Text('Trimite'),
         ),
       ],
     )),
   ) ?? false;
   if (!send) { message.dispose(); return; }

   final body = message.text.trim();
   message.dispose();
   try {
     final db = FirebaseFirestore.instance;
     final batch = db.batch();
     final now = DateTime.now();
     for (final uid in selected) {
       final ref = db.collection('notifications').doc();
       batch.set(ref, {
         'userId': uid,
         'title': 'Sistem',
         'message': body,
         'createdAt': Timestamp.fromDate(now),
         'read': false,
         'updatedAt': FieldValue.serverTimestamp(),
       });
     }
     await batch.commit();
     widget.log('Notificare de sistem trimisă', '${selected.length} destinatari · $body');
     if (mounted) showSuccessMessage(context, 'Notificarea a fost trimisă către ${selected.length} membri.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Notificarea nu a putut fi trimisă: $e');
   }
 }

 Future<void> _setScheduleClosed(WorkSchedule schedule, bool closed) async {
   try {
     await FirebaseFirestore.instance.collection('schedules').doc(schedule.id).update({
       'closed': closed,
       'active': !closed,
       'updatedAt': FieldValue.serverTimestamp(),
     });
     widget.log(closed ? 'Grafic/zi închisă de Admin' : 'Grafic/zi redeschisă de Admin', '${_safeTeam(schedule.teamId)} · ${formatDate(schedule.date)}');
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Modificarea graficului a eșuat: $e')));
   }
 }

 Future<void> _deleteSchedulePermanently(WorkSchedule schedule) async {
   final graphId = schedule.graphId.trim().isEmpty ? schedule.id : schedule.graphId;
   final related = schedules.where((s) => s.teamId == schedule.teamId && (s.graphId.trim().isEmpty ? s.id : s.graphId) == graphId).toList();
   final deleteWholeGraph = related.length > 1;
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: Text(deleteWholeGraph ? 'Ștergi definitiv graficul?' : 'Ștergi definitiv graficul/ziua?'),
     content: Text(
       deleteWholeGraph
           ? '${schedule.graphName} are ${related.length} zile. Toate zilele graficului vor fi șterse definitiv, indiferent dacă sunt deschise sau închise. Istoricul execuțiilor din Centralizator rămâne păstrat.'
           : '${schedule.graphName} · ${formatDate(schedule.date)} va fi șters definitiv. Istoricul execuțiilor din Centralizator rămâne păstrat.'
     ),
     actions: [
       TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')),
       FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.delete_forever), label: const Text('Șterge definitiv')),
     ],
   )) ?? false;
   if (!ok) return;
   try {
     final db = FirebaseFirestore.instance;
     final batch = db.batch();
     for (final item in related) {
       batch.delete(db.collection('schedules').doc(item.id));
     }
     await batch.commit();
     widget.log('Grafic șters definitiv de Admin', '${schedule.graphName} · ${related.length} zile');
     if (mounted) showSuccessMessage(context, deleteWholeGraph ? 'Graficul ${schedule.graphName} a fost șters definitiv.' : 'Graficul/ziua a fost șters(ă) definitiv.');
   } catch (e) {
     if (mounted) showErrorMessage(context, 'Graficul nu a putut fi șters: $e');
   }
 }

 Future<void> _deleteRecord(CentralizerRecord record) async {
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: const Text('Ștergi execuția?'),
     content: Text('${record.locationNameSnapshot} va fi eliminată din Centralizator. Operația intră în Audit.'),
     actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Șterge'))],
   )) ?? false;
   if (!ok) return;
   try {
     await FirebaseFirestore.instance.collection('records').doc(record.id).delete();
     widget.log('Execuție ștearsă de Admin', record.locationNameSnapshot);
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ștergerea execuției a eșuat: $e')));
   }
 }

 Future<void> _deleteExpense(Expense expense) async {
   final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
     title: const Text('Ștergi documentul financiar?'),
     content: Text('${expense.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} nr ${expense.documentNumber} va fi eliminat. Operația intră în Audit.'),
     actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Șterge'))],
   )) ?? false;
   if (!ok) return;
   try {
     await FirebaseFirestore.instance.collection('expenses').doc(expense.id).delete();
     widget.log('Document financiar șters de Admin', expense.documentNumber);
   } catch (e) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ștergerea documentului a eșuat: $e')));
   }
 }

 Widget _programs() {
   final grouped = <String,List<WorkSchedule>>{};
   for (final s in schedules) {
     final graphId = s.graphId.trim().isEmpty ? s.id : s.graphId;
     grouped.putIfAbsent('${s.teamId}|$graphId', () => <WorkSchedule>[]).add(s);
   }
   final groups = grouped.values.toList()
     ..forEach((days) => days.sort((a,b) => a.date.compareTo(b.date)))
     ..sort((a,b) => b.first.date.compareTo(a.first.date));
   return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
     Row(children:[const Expanded(child:Text('Grafice de lucru',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold))),IconButton(tooltip:'Setări Grafice',onPressed:()=>setState(()=>section=15),icon:const Icon(Icons.settings_outlined))]),
     const SizedBox(height:6),
     const Text('Adminul poate închide/redeschide zilele unui grafic sau poate șterge definitiv întregul grafic, indiferent dacă este deschis ori închis. Istoricul execuțiilor din Centralizator rămâne păstrat.'),
     const SizedBox(height:10),
     if(groups.isEmpty)const _Empty(icon:Icons.calendar_month,text:'Nu există grafice de lucru.'),
     ...groups.map((days){
       final first=days.first;
       final openCount=days.where((s)=>!s.closed).length;
       final closedCount=days.length-openCount;
       return Card(child:ExpansionTile(
         leading:const Icon(Icons.calendar_month),
         title:Text('${first.graphName} · ${_safeTeam(first.teamId)}',style:const TextStyle(fontWeight:FontWeight.w800)),
         subtitle:Text('${days.length} zile · $openCount deschise · $closedCount închise'),
         trailing:IconButton(tooltip:'Șterge definitiv întregul grafic',onPressed:()=>_deleteSchedulePermanently(first),icon:const Icon(Icons.delete_forever,color:Colors.redAccent)),
         children:days.map((s)=>ListTile(
           title:Text(formatDate(s.date)),
           subtitle:Text('${s.items.length} locații · ${s.closed?'închis':'activ'}'),
           trailing:Switch(value:s.closed,onChanged:(v)=>_setScheduleClosed(s,v)),
         )).toList(),
       ));
     }),
   ]);
 }
 Widget _records() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
   const Text('Centralizator / istoric execuții', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
   ...records.map((r) => Card(child: ListTile(
     title: Text(r.locationNameSnapshot),
     subtitle: Text('${_safeTeam(r.teamId)} · ${formatDate(r.finishedAt ?? r.startedAt ?? DateTime.now())} · ${timeText(r.startedAt)}–${timeText(r.finishedAt)} · ${r.status.name}'),
     trailing: IconButton(tooltip: 'Șterge execuția', onPressed: () => _deleteRecord(r), icon: const Icon(Icons.delete_forever)),
   )))
 ]);
 Widget _finance() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
   Row(children:[const Expanded(child:Text('Decont & Financiar',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold))),IconButton(tooltip:'Setări financiare',onPressed:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Setări financiare'),content:Text('Diurna implicită este ${settings.defaultPerDiem.toStringAsFixed(2)} lei/zi. Modificările generale se fac din Setări sistem.'))),icon:const Icon(Icons.settings_outlined))]),
   const SizedBox(height: 8),
   Text('Documente confirmate: ${expenses.where((e) => e.confirmed).length}'),
   ...expenses.map((e) => Card(child: ListTile(
     title: Text('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} nr ${e.documentNumber}'),
     subtitle: Text('data ${formatDate(e.date)} · suma ${e.amount.toStringAsFixed(2)} lei · ${e.category}'),
     trailing: IconButton(tooltip: 'Șterge documentul', onPressed: () => _deleteExpense(e), icon: const Icon(Icons.delete_forever)),
   )))
 ]);
  Widget _learning(bool ocr){
    final ls=ocr?settings.learning.values.where((x)=>x.key=='ocr'):settings.learning.values.where((x)=>x.key!='ocr');
    final proposed=[...schedules.where((s)=>s.autoProposed&&s.learningExplanation.trim().isNotEmpty)]..sort((a,b)=>(b.lastRecalculatedAt??b.date).compareTo(a.lastRecalculatedAt??a.date));
    final learnedLocations=<Map<String,dynamic>>[];
    if(!ocr){
      for(final l in locations){
        final estimate=learnedDurationEstimate(records,l.id,settings,targetDate:DateTime.now());
        if(estimate!=null)learnedLocations.add({'location':l,'estimate':estimate});
      }
      learnedLocations.sort((a,b)=>((b['estimate'] as LearnedDurationEstimate).confidence).compareTo((a['estimate'] as LearnedDurationEstimate).confidence));
    }
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(ocr?'Learning OCR':'Learning Center',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      const Text('Fiecare categorie poate rămâne cu aprobare manuală sau poate fi trecută de Admin pe aplicare automată.'),
      if(!ocr)...[
        const SizedBox(height:10),
        const _InfoCard(icon:Icons.verified_user_outlined,title:'Regulă Learning: minimum 3 execuții',text:'Ordinea automată și estimările nu sunt folosite pentru o locație până când există minimum 3 execuții valide păstrate pentru Learning.'),
      ],
      const SizedBox(height:12),
      ...ls.map((cfg)=>Card(child:Column(children:[
        SwitchListTile(value:cfg.enabled,onChanged:(v)async{setState(()=>cfg.enabled=v);await _saveUiSettings();},title:Text(cfg.title),subtitle:Text(cfg.mode==LearningMode.manualApproval?'Aprobare manuală înainte de modificări':'Aplicare automată')),
        const Divider(height:1),
        ListTile(title:Text('${cfg.title} · mod'),trailing:DropdownButton<LearningMode>(value:cfg.mode,items:LearningMode.values.map((m)=>DropdownMenuItem(value:m,child:Text(m==LearningMode.manualApproval?'Manual':'Automat'))).toList(),onChanged:(v)async{if(v!=null){setState(()=>cfg.mode=v);await _saveUiSettings();}})),
      ]))),
      if(!ocr)...[
        const SizedBox(height:16),
        Text('De ce a propus Learning?',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:6),
        if(proposed.isEmpty)const _Empty(icon:Icons.psychology_alt_outlined,text:'Nu există încă trasee propuse de Learning cu explicație salvată.'),
        ...proposed.take(20).map((s)=>Card(child:ExpansionTile(
          leading:CircleAvatar(child:Text('${(s.learningConfidence*100).round()}%')),
          title:Text('${_safeTeam(s.teamId)} · ${s.graphName} · ${formatDate(s.date)}',style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle:Text('${s.learningSamples} mostre · recalculări ${s.recalculationCount}'),
          children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Align(alignment:Alignment.centerLeft,child:Text(s.learningExplanation)))],
        ))),
        const SizedBox(height:16),
        Text('Estimări temporale pe locații',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:6),
        ...learnedLocations.take(30).map((row){
          final l=row['location'] as Location; final e=row['estimate'] as LearnedDurationEstimate;
          return Card(child:ListTile(
            leading:categoryBrandWidget(l.categoryId,size:34,fallbackColor:_locationColor(l)),
            title:Text(l.name,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(e.explanation),
            trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(durationText(e.duration),style:const TextStyle(fontWeight:FontWeight.w800)),Text('${(e.confidence*100).round()}%')]),
          ));
        }),
      ],
      const SizedBox(height:16),
      Text(ocr?'Evenimente OCR recente':'Jurnal Learning recent',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
      const SizedBox(height:6),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:FirebaseFirestore.instance.collection('learningEvents').orderBy('createdAt',descending:true).limit(100).snapshots(),
        builder:(context,snap){
          if(snap.hasError)return _InfoCard(icon:Icons.warning_amber_rounded,title:'Jurnal indisponibil',text:'${snap.error}');
          final docs=(snap.data?.docs??<QueryDocumentSnapshot<Map<String,dynamic>>>[]).where((d)=>!ocr||(d.data()['category']??'').toString()=='ocr').take(30).toList();
          if(docs.isEmpty)return const _Empty(icon:Icons.history,text:'Nu există încă evenimente pentru această categorie.');
          return Column(children:docs.map((doc){final d=doc.data();final at=d['createdAt'] is Timestamp?(d['createdAt'] as Timestamp).toDate():null;return Card(child:ListTile(
            leading:const Icon(Icons.insights_outlined),
            title:Text('${d['category']??''} · ${d['event']??''}',style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text('${d['actor']??''}${at==null?'':' · ${formatDate(at)} ${timeText(at)}'}\n${(d['data']??<String,dynamic>{}).toString()}',maxLines:3,overflow:TextOverflow.ellipsis),
            isThreeLine:true,
          ));}).toList());
        },
      ),
    ]);
  }
  Widget _notifications()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:10,runSpacing:10,children:[
      const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Notificări',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        SizedBox(height:4),
        Text('Trimite notificări manuale către unul sau mai mulți membri. Pentru destinatar, expeditorul este afișat ca Sistem.'),
      ]),
      FilledButton.icon(onPressed:_sendSystemNotification,icon:const Icon(Icons.send),label:const Text('Trimite notificare')),
    ]),
    const SizedBox(height:12),
    if(notifications.isEmpty)const _Empty(icon:Icons.notifications_none,text:'Nu există notificări.'),
    ...notifications.map((n)=>Card(child:ListTile(title:Text(n.title),subtitle:Text('${n.message}\n${formatDate(n.createdAt)} ${timeText(n.createdAt)}'),isThreeLine:true,trailing:Icon(n.read?Icons.mark_email_read:Icons.mark_email_unread))))
  ]);
  dynamic _backupEncode(dynamic value) {
    if (value is Timestamp) return {'__type': 'timestamp', 'value': value.toDate().toIso8601String()};
    if (value is GeoPoint) return {'__type': 'geopoint', 'lat': value.latitude, 'lng': value.longitude};
    if (value is Map) return value.map((k,v)=>MapEntry(k.toString(),_backupEncode(v)));
    if (value is List) return value.map(_backupEncode).toList();
    return value;
  }

  dynamic _backupDecode(dynamic value) {
    if (value is Map && value['__type'] == 'timestamp') return Timestamp.fromDate(DateTime.parse(value['value'].toString()));
    if (value is Map && value['__type'] == 'geopoint') return GeoPoint((value['lat'] as num).toDouble(),(value['lng'] as num).toDouble());
    if (value is Map) return value.map((k,v)=>MapEntry(k.toString(),_backupDecode(v)));
    if (value is List) return value.map(_backupDecode).toList();
    return value;
  }

  Future<void> _exportBackup() async {
    const names=['teams','cars','locations','locationCategories','functions','schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit','learningEvents','backgrounds'];
    final db=FirebaseFirestore.instance;
    final data=<String,dynamic>{
      'format':'AndiCarpetaBackupV1',
      'createdAt':DateTime.now().toIso8601String(),
      'collections':<String,dynamic>{},
    };
    final uiSettings=await db.collection('meta').doc('uiSettings').get();
    data['uiSettings']=_backupEncode(uiSettings.data());
    final collections=data['collections'] as Map<String,dynamic>;
    for(final name in names){
      final snap=await db.collection(name).get();
      collections[name]={for(final doc in snap.docs) doc.id:_backupEncode(doc.data())};
    }
    final bytes=Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    final filename='andi_carpeta_backup_${DateTime.now().year}${two(DateTime.now().month)}${two(DateTime.now().day)}_${two(DateTime.now().hour)}${two(DateTime.now().minute)}.json';
    final saved=await FilePicker.saveFile(fileName:filename,bytes:bytes);
    if(saved!=null){
      await db.collection('meta').doc('backup').set({'lastExportAt':FieldValue.serverTimestamp(),'fileName':filename},SetOptions(merge:true));
      widget.log('Backup exportat',filename);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Backup exportat.')));
    }
  }

  Future<void> _restoreAutomaticBackup(String backupId) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Restaurează backup-ul automat?'),
      content:Text('Snapshot: $backupId\n\nColecțiile operaționale vor fi înlocuite cu valorile din snapshot. Conturile Firebase Authentication și profilurile users nu sunt modificate.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restaurează'))],
    ))??false;
    if(!ok)return;
    final db=FirebaseFirestore.instance;
    final ref=db.collection('backups').doc(backupId);
    final meta=await ref.get();
    if(!meta.exists||meta.data()?['status']!='complete'){if(mounted)showErrorMessage(context,'Backup-ul selectat nu este complet.');return;}
    final items=await ref.collection('items').get();
    const allowed=<String>{'teams','cars','locations','locationCategories','functions','schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit'};
    final grouped=<String,List<QueryDocumentSnapshot<Map<String,dynamic>>>>{};
    for(final item in items.docs){final collection=(item.data()['collection']??'').toString();if(allowed.contains(collection))grouped.putIfAbsent(collection,()=>[]).add(item);}
    try{
      for(final collection in allowed){
        final current=await db.collection(collection).get();
        WriteBatch batch=db.batch();var count=0;
        for(final doc in current.docs){batch.delete(doc.reference);count++;if(count>=300){await batch.commit();batch=db.batch();count=0;}}
        if(count>0)await batch.commit();
        batch=db.batch();count=0;
        for(final item in grouped[collection]??const <QueryDocumentSnapshot<Map<String,dynamic>>>[]){
          final d=item.data();final documentId=(d['documentId']??'').toString();final data=d['data'];
          if(documentId.isEmpty||data is! Map)continue;
          batch.set(db.collection(collection).doc(documentId),Map<String,dynamic>.from(data));count++;
          if(count>=8){await batch.commit();batch=db.batch();count=0;}
        }
        if(count>0)await batch.commit();
      }
      final savedSettings=meta.data()?['uiSettings'];
      if(savedSettings is Map)await db.collection('meta').doc('uiSettings').set(Map<String,dynamic>.from(savedSettings),SetOptions(merge:false));
      await db.collection('meta').doc('backup').set({'lastRestoreAt':FieldValue.serverTimestamp(),'restoredAutomaticBackup':backupId},SetOptions(merge:true));
      widget.log('Backup automat restaurat',backupId);
      if(mounted)showSuccessMessage(context,'Backup-ul automat a fost restaurat. Datele se resincronizează.');
    }catch(e){if(mounted)showErrorMessage(context,'Restaurarea backup-ului automat a eșuat: $e');}
  }

  Future<void> _restoreBackup() async {
    final file=await FilePicker.pickFile(type:FileType.custom,allowedExtensions:['json']);
    if(file==null)return;
    final raw=utf8.decode(await file.readAsBytes());
    final parsed=jsonDecode(raw);
    if(parsed is! Map || parsed['format']!='AndiCarpetaBackupV1' || parsed['collections'] is! Map){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Fișierul nu este un backup Andi Carpetă valid.')));
      return;
    }
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Restaurare backup'),content:const Text('Datele operaționale și Auditul din backup vor înlocui colecțiile existente. Conturile Firebase Authentication nu sunt modificate. Continui?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restaurează'))]))??false;
    if(!ok)return;
    final db=FirebaseFirestore.instance;
    final collections=(parsed['collections'] as Map).map((k,v)=>MapEntry(k.toString(),v));
    for(final entry in collections.entries){
      final name=entry.key;
      if(!['teams','cars','locations','locationCategories','functions','schedules','records','expenses','perDiems','finance','settlements','documents','notifications','audit'].contains(name))continue;
      final current=await db.collection(name).get();
      var batch=db.batch();
      var count=0;
      for(final doc in current.docs){
        batch.delete(doc.reference);count++;
        if(count>=400){await batch.commit();batch=db.batch();count=0;}
      }
      if(count>0)await batch.commit();
      final source=entry.value;
      if(source is Map){
        batch=db.batch();count=0;
        for(final rawEntry in source.entries){
          final value=_backupDecode(rawEntry.value);
          if(value is! Map)continue;
          batch.set(db.collection(name).doc(rawEntry.key.toString()),Map<String,dynamic>.from(value));count++;
          if(count>=400){await batch.commit();batch=db.batch();count=0;}
        }
        if(count>0)await batch.commit();
      }
    }
    final savedSettings=_backupDecode(parsed['uiSettings']);
    if(savedSettings is Map)await db.collection('meta').doc('uiSettings').set(Map<String,dynamic>.from(savedSettings),SetOptions(merge:false));
    await db.collection('meta').doc('backup').set({'lastRestoreAt':FieldValue.serverTimestamp(),'restoredFile':file.name},SetOptions(merge:true));
    widget.log('Backup restaurat',file.name);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Restaurarea s-a terminat. Datele se resincronizează.')));
  }

  Widget _reports()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Rapoarte',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    const Text('Rapoartele se generează la cerere și PDF-ul pornește imediat descărcarea. Nu se arhivează copii în Firebase.'),
    const SizedBox(height:14),
    Wrap(spacing:10,runSpacing:10,children:[
      FilledButton.icon(onPressed:()=>downloadCentralizerPdf(type:LocationType.magic,locations:locations,teams:teams,schedules:schedules,records:records),icon:const Icon(Icons.picture_as_pdf),label:const Text('Centralizator MAGIC')),
      FilledButton.icon(onPressed:()=>downloadCentralizerPdf(type:LocationType.million,locations:locations,teams:teams,schedules:schedules,records:records),icon:const Icon(Icons.picture_as_pdf),label:const Text('Centralizator Million')),
      OutlinedButton.icon(onPressed:()=>downloadFinancialSummaryPdf(teams:teams,expenses:expenses,perDiems:perDiems,finances:finances,settlements:settlements),icon:const Icon(Icons.account_balance_wallet_outlined),label:const Text('Raport financiar general')),
      OutlinedButton.icon(onPressed:()=>downloadAuditPdf(audit),icon:const Icon(Icons.history),label:const Text('Raport Audit')),
    ]),
    const SizedBox(height:16),
    _InfoCard(icon:Icons.assessment,title:'Date incluse',text:'Centralizatoarele includ sălile programate chiar dacă nu au fost executate, plus execuțiile manuale. Raportul financiar folosește numai cheltuieli și diurne confirmate. Auditul exportă istoricul încărcat în Admin.'),
  ]);
  Widget _audit()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Istoric / Audit',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),...audit.map((a)=>ListTile(leading:const Icon(Icons.history),title:Text(a.action),subtitle:Text('${a.actor} · ${a.target}\n${formatDate(a.at)} ${timeText(a.at)}'),isThreeLine:true))]);
  Future<void> _deleteFunction(FunctionDefinition f) async {
    if (f.id == 'admin') {
      if (mounted) showErrorMessage(context, 'Funcția Admin este protejată și nu poate fi ștearsă.');
      return;
    }
    final db = FirebaseFirestore.instance;
    final usersSnap = await db.collection('users').get();
    final affected = usersSnap.docs.where((doc) {
      final d = doc.data();
      final ids = d['functionIds'] is List
          ? (d['functionIds'] as List).map((e) => e.toString()).toList()
          : <String>[(d['function'] ?? '').toString()];
      return ids.contains(f.id);
    }).toList();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Șterge funcția?'),
      content: Text(affected.isEmpty
          ? '${f.name} va fi ștearsă definitiv.'
          : '${f.name} este atribuită la ${affected.length} membri. Funcția va fi eliminată automat de la aceștia, iar drepturile lor vor fi recalculate înainte de ștergere.'),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),
        FilledButton.icon(onPressed:()=>Navigator.pop(c,true),icon:const Icon(Icons.delete_forever),label:const Text('Șterge funcția')),
      ],
    )) ?? false;
    if (!ok) return;
    try {
      var batch = db.batch();
      var writes = 0;
      Future<void> flush() async {
        if (writes == 0) return;
        await batch.commit();
        batch = db.batch();
        writes = 0;
      }
      for (final doc in affected) {
        final d = doc.data();
        final currentIds = d['functionIds'] is List
            ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
            : <String>[(d['function'] ?? '').toString()].where((e) => e.isNotEmpty).toList();
        final remaining = currentIds.where((id) => id != f.id && functionDefinitions.any((def) => def.id == id)).toList();
        final effective = <String>{};
        for (final id in remaining) {
          final def = _functionByIdLocal(id);
          if (def != null && def.active) effective.addAll(def.permissions);
        }
        final sortedPermissions = effective.toList()..sort();
        batch.set(doc.reference, {
          'functionIds': remaining,
          'function': remaining.isEmpty ? '' : remaining.first,
          'effectivePermissions': sortedPermissions,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge:true));
        writes++;
        if (writes >= 350) await flush();
      }
      batch.delete(db.collection('functions').doc(f.id));
      writes++;
      await flush();
      if (!mounted) return;
      setState(() {
        functionDefinitions.removeWhere((x) => x.id == f.id);
        for (final u in users) { u.functionIds.removeWhere((id) => id == f.id); }
      });
      widget.log('Funcție ștearsă', '${f.name} · eliminată de la ${affected.length} membri');
      showSuccessMessage(context, affected.isEmpty ? 'Funcția ${f.name} a fost ștearsă.' : 'Funcția ${f.name} a fost ștearsă și eliminată de la ${affected.length} membri.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Funcția nu a putut fi ștearsă: $e');
    }
  }

  Widget _functionRights()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:12,runSpacing:10,children:[
      const SizedBox(width:520,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Funcții & Drepturi',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),SizedBox(height:4),Text('Funcțiile sunt dinamice. Poți adăuga funcții, alege 1-3 ecusoane și bifa drepturile. Un membru poate avea mai multe funcții.')])),
      FilledButton.icon(onPressed:()=>_editFunctionDefinition(),icon:const Icon(Icons.add),label:const Text('Adaugă funcție')),
    ]),
    const SizedBox(height:12),
    ...([...functionDefinitions]..sort((a,b)=>a.name.compareTo(b.name))).map((f)=>Card(child:ExpansionTile(
      leading: SizedBox(width:118,child:badgeStripWidget(f.badgeKeys,size:34,color:f.color)),
      title:Text(f.name),
      subtitle:Text('${f.permissions.length} drepturi active · ${f.active?'activă':'inactivă'}'),
      trailing:Wrap(spacing:2,children:[IconButton(tooltip:'Editează funcția',onPressed:()=>_editFunctionDefinition(f),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Șterge funcția',onPressed:()=>_deleteFunction(f),icon:const Icon(Icons.delete_outline))]),
      children:[
        SwitchListTile(value:f.active,onChanged:(v)async{f.active=v;setState((){});await FirebaseFirestore.instance.collection('functions').doc(f.id).set({'active':v,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));widget.log(v?'Funcție activată':'Funcție dezactivată',f.name);},title:const Text('Funcție activă')),
        ...FunctionPermission.values.map((p)=>CheckboxListTile(
          value:f.permissions.contains(p.name),
          onChanged:(v)async{
            setState((){if(v==true){f.permissions.add(p.name);}else{f.permissions.remove(p.name);}});
            await FirebaseFirestore.instance.collection('functions').doc(f.id).set({'permissions':f.permissions.toList()..sort(),'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
            widget.log('Drepturi funcție modificate','${f.name} · ${p.label}');
          },
          title:Text(p.label),dense:true,
        )),
      ],
    ))),
  ]);
  Future<void> _saveUiSettings() async {
    try {
      await FirebaseFirestore.instance.collection('meta').doc('uiSettings').set({
        'background': settings.background,
        'brandingBackgroundId': settings.brandingBackgroundId,
        'brandingLogoId': settings.brandingLogoId,
        'androidDownloadUrl': settings.androidDownloadUrl,
        'smsPreviousDayTime': settings.smsPreviousDayTime,
        'smsTemplates': settings.smsTemplates,
        'backgroundOpacity': settings.backgroundOpacity,
        'defaultPerDiem': settings.defaultPerDiem,
        'allowUndo': settings.allowUndo,
        'autoStart': settings.autoStart,
        'autoFinish': settings.autoFinish,
        'autoCloseWhenAllDone': settings.autoCloseWhenAllDone,
        'pushNotifications': settings.pushNotifications,
        'automaticBackup': settings.automaticBackup,
        'backupRetentionDays': settings.backupRetentionDays,
        'notificationHistoryDays': settings.notificationHistoryDays,
        'learning': {
          for (final entry in settings.learning.entries)
            entry.key: {'enabled': entry.value.enabled, 'mode': entry.value.mode.name},
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      widget.log('Setări sistem salvate', settings.background);
      if (mounted) showSuccessMessage(context, 'Setările au fost salvate și se vor sincroniza pe dispozitive.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Setările nu au putut fi salvate: $e');
    }
  }

  Future<void> _editDaysSetting({required String title, required int current, required void Function(int) apply}) async {
    final c=TextEditingController(text:'$current');
    final value=await showDialog<int>(context:context,builder:(d)=>AlertDialog(
      title:Text(title),
      content:TextField(controller:c,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Număr zile',suffixText:'zile')),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(d,int.tryParse(c.text.trim())),child:const Text('Salvează'))],
    ));
    c.dispose();
    if(value!=null&&value>=1&&value<=365){setState(()=>apply(value));await _saveUiSettings();}
  }

  Uint8List _compressBackgroundImage(Uint8List bytes) {
    final decoded=img.decodeImage(bytes);
    if(decoded==null)throw const FormatException('Imaginea nu poate fi citită.');
    var work=img.bakeOrientation(decoded);
    final longest=work.width>work.height?work.width:work.height;
    if(longest>1600)work=work.width>=work.height?img.copyResize(work,width:1600):img.copyResize(work,height:1600);
    var quality=72;
    var encoded=Uint8List.fromList(img.encodeJpg(work,quality:quality));
    while(encoded.length>620000&&quality>38){
      quality-=8;
      encoded=Uint8List.fromList(img.encodeJpg(work,quality:quality));
    }
    if(encoded.length>620000){
      work=work.width>=work.height?img.copyResize(work,width:1100):img.copyResize(work,height:1100);
      encoded=Uint8List.fromList(img.encodeJpg(work,quality:45));
    }
    if(encoded.length>700000)throw const FormatException('Imaginea rămâne prea mare după compresie. Alege o imagine mai mică.');
    return encoded;
  }

  Future<void> _uploadCustomBackground() async {
    final picked=await FilePicker.pickFile(type:FileType.image);
    if(picked==null)return;
    final raw=await picked.readAsBytes();
    if(raw.isEmpty){if(mounted)showErrorMessage(context,'Imaginea nu a putut fi citită.');return;}
    final nameCtrl=TextEditingController(text:picked.name.replaceFirst(RegExp(r'\.[^.]+$'),''));
    final name=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Nume fundal'),
      content:TextField(controller:nameCtrl,decoration:const InputDecoration(labelText:'Denumire pentru utilizatori')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,nameCtrl.text.trim()),child:const Text('Încarcă'))],
    ));
    nameCtrl.dispose(); if(name==null||name.trim().isEmpty)return;
    try{
      final compressed=_compressBackgroundImage(raw);
      final id='bg_${idNow()}';
      await FirebaseFirestore.instance.collection('backgrounds').doc(id).set({
        'name':name.trim(),'imageBase64':base64Encode(compressed),'active':true,
        'createdBy':FirebaseAuth.instance.currentUser?.uid??'','createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),
      });
      widget.log('Fundal personalizat adăugat',name.trim());
      if(mounted)showSuccessMessage(context,'Fundalul a fost adăugat. Îl poți activa global din Branding.');
    }catch(e){if(mounted)showErrorMessage(context,'Fundalul nu a putut fi salvat: $e');}
  }

  Future<void> _deleteCustomBackground(String id,String name) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Ștergi fundalul?'),content:Text(name),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Șterge'))]))??false;
    if(!ok)return;
    await FirebaseFirestore.instance.collection('backgrounds').doc(id).delete();
    widget.log('Fundal personalizat șters',name);
    if(mounted && settings.brandingBackgroundId=='custom:$id'){
      setState(()=>settings.brandingBackgroundId='default');
      await _saveUiSettings();
    }
    if(mounted)showSuccessMessage(context,'Fundalul a fost șters.');
  }

  Future<void> _editAndroidDownloadUrl() async {
    final c=TextEditingController(text:settings.androidDownloadUrl);
    final value=await showDialog<String>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Link descărcare APK Android'),
      content:SizedBox(width:620,child:TextField(controller:c,autocorrect:false,decoration:const InputDecoration(labelText:'URL APK',hintText:'https://.../andi-carpeta.apk'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(d,c.text.trim()),child:const Text('Salvează'))],
    ));
    c.dispose();if(value==null)return;
    if(value.isNotEmpty){final uri=Uri.tryParse(value);if(uri==null||!(uri.scheme=='https'||uri.scheme=='http')){if(mounted)showErrorMessage(context,'Linkul trebuie să înceapă cu https:// sau http://');return;}}
    setState(()=>settings.androidDownloadUrl=value);await _saveUiSettings();
  }

  Future<void> _editSmsPreviousDayTime() async {
    final parts=settings.smsPreviousDayTime.split(':');
    final initial=TimeOfDay(hour:int.tryParse(parts.isNotEmpty?parts[0]:'10')??10,minute:int.tryParse(parts.length>1?parts[1]:'00')??0);
    final picked=await showTimePicker(context:context,initialTime:initial,helpText:'Ora trimiterii SMS în ziua precedentă');
    if(picked==null)return;
    final value='${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
    setState(()=>settings.smsPreviousDayTime=value);
    await _saveUiSettings();
  }

  Widget _settings()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Setări sistem',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const SizedBox(height:4),
        const Text('Setări generale și branding global. Tema și fontul rămân preferințe personale; logo-ul și fundalul sunt stabilite numai de Admin.'),
      ])),
      FilledButton.icon(onPressed:_saveUiSettings,icon:const Icon(Icons.save_outlined),label:const Text('Salvează setările')),
    ]),
    const SizedBox(height:10),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Branding global',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      const SizedBox(height:4),
      const Text('Logo-ul și fundalul sunt controlate exclusiv de Admin și se aplică tuturor utilizatorilor.'),
      const SizedBox(height:10),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.android),title:const Text('Link APK Android'),subtitle:Text(settings.androidDownloadUrl.trim().isEmpty?'Neconfigurat':settings.androidDownloadUrl,maxLines:2,overflow:TextOverflow.ellipsis),trailing:OutlinedButton(onPressed:_editAndroidDownloadUrl,child:const Text('Editează'))),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
        value:_bundledLogoAssets.containsKey(settings.brandingLogoId)?settings.brandingLogoId:'standard',
        decoration:const InputDecoration(labelText:'Logo activ'),
        items:_bundledLogoLabels.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
        onChanged:(v)async{if(v==null)return;setState(()=>settings.brandingLogoId=v);widget.onChanged();await _saveUiSettings();},
      ),
      const SizedBox(height:10),
      Center(child:Container(constraints:const BoxConstraints(maxWidth:620,maxHeight:155),padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(12)),child:appBrandLogo(settings,width:600,height:135))),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
        value:{..._bundledBackgroundAssets.keys,...settings.customBackgrounds.keys.map((e)=>'custom:$e')}.contains(settings.brandingBackgroundId)?settings.brandingBackgroundId:'default',
        decoration:const InputDecoration(labelText:'Fundal activ pentru toți utilizatorii'),
        items:[
          ..._bundledBackgroundLabels.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))),
          ...settings.customBackgrounds.entries.map((e)=>DropdownMenuItem(value:'custom:${e.key}',child:Text('Personalizat · ${e.value['name']??e.key}'))),
        ],
        onChanged:(v)async{if(v==null)return;setState(()=>settings.brandingBackgroundId=v);widget.onChanged();await _saveUiSettings();},
      ),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('Vizibilitate fundal'),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Slider(value:settings.backgroundOpacity.clamp(0.0,.70),min:0,max:0.70,divisions:14,label:'${(settings.backgroundOpacity*100).round()}%',onChanged:(v){setState(()=>settings.backgroundOpacity=v);widget.onChanged();}),const Text('Stratul de contrast rămâne activ pentru ca textele și notificările să fie lizibile inclusiv pe imagini foarte deschise.',style:TextStyle(fontSize:12))])),
      Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:_saveUiSettings,icon:const Icon(Icons.public),label:const Text('Aplică global'))),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Text('Fundaluri personalizate',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),FilledButton.icon(onPressed:_uploadCustomBackground,icon:const Icon(Icons.add_photo_alternate_outlined),label:const Text('Adaugă fundal'))]),
      const SizedBox(height:6),
      const Text('Imaginile încărcate aici pot fi activate numai de Admin. Utilizatorii nu au selector individual de fundal.'),
      const SizedBox(height:8),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:FirebaseFirestore.instance.collection('backgrounds').orderBy('createdAt',descending:true).snapshots(),
        builder:(context,snap){
          if(snap.hasError)return ListTile(leading:const Icon(Icons.warning_amber_rounded),title:const Text('Fundalurile nu pot fi încărcate'),subtitle:Text('${snap.error}'));
          final docs=snap.data?.docs??<QueryDocumentSnapshot<Map<String,dynamic>>>[];
          if(docs.isEmpty)return const ListTile(leading:Icon(Icons.wallpaper_outlined),title:Text('Nu există încă fundaluri personalizate.'));
          return Column(children:docs.map((doc){
            final d=doc.data();Uint8List? bytes;try{bytes=base64Decode((d['imageBase64']??'').toString());}catch(_){}
            final name=(d['name']??doc.id).toString();
            final selected=settings.brandingBackgroundId=='custom:${doc.id}';
            return ListTile(
              leading:bytes==null?const CircleAvatar(child:Icon(Icons.broken_image_outlined)):ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.memory(bytes,width:56,height:42,fit:BoxFit.cover)),
              title:Text(name),subtitle:Text(selected?'ACTIV GLOBAL':(d['active']==false?'Inactiv':'Disponibil Adminului')),
              trailing:Wrap(spacing:4,children:[
                if(!selected)IconButton(tooltip:'Aplică global',onPressed:()async{setState(()=>settings.brandingBackgroundId='custom:${doc.id}');widget.onChanged();await _saveUiSettings();},icon:const Icon(Icons.check_circle_outline)),
                IconButton(tooltip:'Șterge',onPressed:()=>_deleteCustomBackground(doc.id,name),icon:const Icon(Icons.delete_outline)),
              ]),
            );
          }).toList());
        },
      ),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Automatizări & financiar',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      ListTile(
        contentPadding:EdgeInsets.zero,
        leading:const Icon(Icons.schedule_send_outlined),
        title:const Text('Ora mesajului automat către locații'),
        subtitle:Text('Mesajul inițial se trimite în ziua calendaristică precedentă intervenției. Exemplu: intervenție pe 8 → mesaj pe 7 la ${settings.smsPreviousDayTime}.'),
        trailing:OutlinedButton.icon(onPressed:_editSmsPreviousDayTime,icon:const Icon(Icons.schedule),label:Text(settings.smsPreviousDayTime)),
      ),
      ListTile(title:const Text('Diurnă implicită'),subtitle:Text('${settings.defaultPerDiem.toStringAsFixed(2)} lei/zi'),trailing:IconButton(icon:const Icon(Icons.edit_outlined),onPressed:()async{final c=TextEditingController(text:settings.defaultPerDiem.toStringAsFixed(2));final v=await showDialog<double>(context:context,builder:(d)=>AlertDialog(title:const Text('Diurnă implicită'),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(suffixText:'lei/zi')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(d,double.tryParse(c.text.replaceAll(',', '.'))),child:const Text('Salvează'))]));c.dispose();if(v!=null&&v>0){setState(()=>settings.defaultPerDiem=v);await _saveUiSettings();}})),
      SwitchListTile(value:settings.autoStart,onChanged:(v){setState(()=>settings.autoStart=v);widget.onChanged();},title:const Text('START automat asistat'),subtitle:const Text('Se aplică împreună cu Learning → Acces și așteptare.')),
      SwitchListTile(value:settings.autoFinish,onChanged:(v){setState(()=>settings.autoFinish=v);widget.onChanged();},title:const Text('FINAL automat asistat'),subtitle:const Text('Poate propune sau aplica FINAL după ieșirea din perimetrul locației.')),
      SwitchListTile(value:settings.autoCloseWhenAllDone,onChanged:(v){setState(()=>settings.autoCloseWhenAllDone=v);widget.onChanged();},title:const Text('Închide automat graficul rezolvat'),subtitle:const Text('Funcționează în modul automat al Learning → Modificări de program.')),
      SwitchListTile(value:settings.pushNotifications,onChanged:(v){setState(()=>settings.pushNotifications=v);widget.onChanged();},title:const Text('Notificări operaționale')),
      SwitchListTile(value:settings.allowUndo,onChanged:(v){setState(()=>settings.allowUndo=v);widget.onChanged();},title:const Text('Undo unde este posibil')),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Istoric & Backup',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      SwitchListTile(value:settings.automaticBackup,onChanged:(v){setState(()=>settings.automaticBackup=v);widget.onChanged();},secondary:const Icon(Icons.backup_outlined),title:const Text('Backup intern automat'),subtitle:const Text('Creează în Firebase o fotografie a datelor operaționale cel mult o dată pe zi. Backup-ul JSON descărcat rămâne recomandat ca copie externă.')),
      ListTile(title:const Text('Păstrare istoric notificări'),subtitle:const Text('Notificările mai vechi sunt curățate automat de Admin.'),trailing:TextButton(onPressed:()=>_editDaysSetting(title:'Păstrare notificări',current:settings.notificationHistoryDays,apply:(v)=>settings.notificationHistoryDays=v),child:Text('${settings.notificationHistoryDays} zile'))),
      ListTile(title:const Text('Păstrare backup automat'),subtitle:const Text('Backup-urile interne mai vechi sunt eliminate automat.'),trailing:TextButton(onPressed:()=>_editDaysSetting(title:'Păstrare backup automat',current:settings.backupRetentionDays,apply:(v)=>settings.backupRetentionDays=v),child:Text('${settings.backupRetentionDays} zile'))),
    ]))),
  ]);
  Widget _backup()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Backup & Recuperare',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    Text('Backup manual: fișier JSON descărcat local. Backup intern automat: ${settings.automaticBackup?'ACTIV':'OPRIT'} · retenție ${settings.backupRetentionDays} zile. Conturile Firebase Authentication nu sunt incluse.'),
    const SizedBox(height:12),
    StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('meta').doc('backup').snapshots(),
      builder:(context,snap){
        final d=snap.data?.data();
        final last=d!=null && d['lastExportAt'] is Timestamp ? (d['lastExportAt'] as Timestamp).toDate() : null;
        final restored=d!=null && d['lastRestoreAt'] is Timestamp ? (d['lastRestoreAt'] as Timestamp).toDate() : null;
        return _InfoCard(icon:Icons.backup,title:'Stare backup',text:'Ultimul export: ${last==null?'niciunul':'${formatDate(last)} ${timeText(last)}'}\nUltima restaurare: ${restored==null?'niciuna':'${formatDate(restored)} ${timeText(restored)}'}');
      },
    ),
    const SizedBox(height:10),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('backups').orderBy('createdAt',descending:true).limit(1).snapshots(),
      builder:(context,snap){
        if(!snap.hasData||snap.data!.docs.isEmpty)return _InfoCard(icon:Icons.cloud_outlined,title:'Backup intern automat',text:settings.automaticBackup?'Activ · încă nu există niciun snapshot complet.':'Oprit din Setări sistem.');
        final doc=snap.data!.docs.first;final d=doc.data();final at=d['createdAt'] is Timestamp?(d['createdAt'] as Timestamp).toDate():null;final status=(d['status']??'').toString();final count=d['documentCount'] is num?(d['documentCount'] as num).toInt():0;
        return Card(child:ListTile(leading:const Icon(Icons.cloud_done_outlined),title:const Text('Backup intern automat',style:TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${status=='complete'?'Complet':status} · ${at==null?'dată în curs':'${formatDate(at)} ${timeText(at)}'} · $count documente · retenție ${settings.backupRetentionDays} zile'),trailing:status=='complete'?OutlinedButton.icon(onPressed:()=>_restoreAutomaticBackup(doc.id),icon:const Icon(Icons.restore),label:const Text('Restaurează')):null));
      },
    ),
    const SizedBox(height:12),
    Wrap(spacing:10,runSpacing:10,children:[
      FilledButton.icon(onPressed:_exportBackup,icon:const Icon(Icons.download),label:const Text('Exportă backup')),
      OutlinedButton.icon(onPressed:_restoreBackup,icon:const Icon(Icons.restore),label:const Text('Restaurează backup')),
    ]),
    const SizedBox(height:12),
    const _InfoCard(icon:Icons.security,title:'Siguranță',text:'Restaurarea cere confirmare și înlocuiește datele operaționale și Auditul: echipe, mașini, locații, grafice, execuții, deplasări/deconturi, diurne, financiar, documente, notificări și audit. Conturile de autentificare rămân intacte.'),
  ]);

}

class _ScheduleCardFull extends StatelessWidget { final WorkSchedule schedule; final List<Location> locations; final List<LocationCategory> categories; final List<CentralizerRecord> records; final bool canEdit; final VoidCallback onAdd; final void Function(ScheduleItem) onRemove; final void Function(int,int) onReorder; const _ScheduleCardFull({required this.schedule,required this.locations,required this.categories,required this.records,required this.canEdit,required this.onAdd,required this.onRemove,required this.onReorder}); @override Widget build(BuildContext context){return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('Zi grafic · ${formatDate(schedule.date)}',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),if(canEdit&&!schedule.closed)TextButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Adaugă locații'))]),if(schedule.autoProposed)_InfoCard(icon:Icons.auto_graph,title:'Ordine propusă · încredere ${(schedule.learningConfidence*100).round()}%',text:schedule.learningExplanation.trim().isEmpty?'Ordinea este informativă. Echipa poate executa locațiile în orice ordine.':schedule.learningExplanation),ReorderableListView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:schedule.items.length,itemBuilder:(c,i){final x=schedule.items[i];final done=records.any((r)=>r.teamId==schedule.teamId&&r.locationId==x.locationId&&r.completed);return Card(key:ValueKey('${x.locationId}_$i'),child:ListTile(leading: Stack(alignment: Alignment.bottomRight, children: [categoryBrandWidget(x.categoryIdSnapshot, size: 38, fallbackColor: categoryColor(categories,x.categoryIdSnapshot,fallbackType:x.typeSnapshot)), Container(width: 20,height:20,decoration:BoxDecoration(color:categoryColor(categories,x.categoryIdSnapshot,fallbackType:x.typeSnapshot),shape:BoxShape.circle,border:Border.all(color:Colors.white,width:1.5)),alignment:Alignment.center,child:Text('${i+1}',style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold)))]),title:Text(x.locationNameSnapshot),subtitle:Text('${x.addressSnapshot} · ${done?'Finalizată':'Rămasă'}'),trailing:canEdit&&!schedule.closed?IconButton(onPressed:()=>onRemove(x),icon:const Icon(Icons.delete_outline)):null));},onReorder:canEdit&&!schedule.closed?onReorder:null)])));}}

class _TeamSelector extends StatelessWidget {
  final List<Team> teams; final int selected; final ValueChanged<int> onChanged;
  const _TeamSelector({required this.teams,required this.selected,required this.onChanged});
  @override Widget build(BuildContext context){
    final accent=sectionAccent('Echipe');
    return ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:360),
      child:DropdownButtonFormField<int>(
        value:selected.clamp(0,teams.length-1),
        decoration:InputDecoration(labelText:'Echipă',prefixIcon:Icon(Icons.groups,color:accent)),
        items:[for(int i=0;i<teams.length;i++)DropdownMenuItem(value:i,child:Text(teams[i].name,style:const TextStyle(fontWeight:FontWeight.w700)))],
        onChanged:(v){if(v!=null)onChanged(v);},
      ),
    );
  }
}
class _Page extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;
  const _Page({required this.title, required this.subtitle, this.actions = const [], required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (c, box) {
      final accent = sectionAccent(title);
      final mobile = box.maxWidth < 600;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(mobile ? 12 : 26, mobile ? 14 : 22, mobile ? 12 : 26, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: .90),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: _activeAppSettingsForBranding == null
                  ? Image.asset('assets/logos/standard.jpg',height:mobile?80:112,width:mobile?250:360,fit:BoxFit.contain)
                  : appBrandLogo(_activeAppSettingsForBranding!,height:mobile?80:112,width:mobile?250:360),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent.withValues(alpha: .23), Theme.of(context).colorScheme.surface.withValues(alpha: .94)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: .40)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 16, offset: const Offset(0, 5))],
            ),
            child: mobile
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 6, height: 42, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: accent))),
                    ]),
                    const SizedBox(height: 5),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                    ],
                  ])
                : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(width: 6, height: 48, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: accent)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ])),
                    ...actions.map((x) => Padding(padding: const EdgeInsets.only(left: 8), child: x)),
                  ]),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(mobile ? 12 : 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .94 : .975),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: child,
          ),
        ]),
      );
    },
  );
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData? icon;
  final String? asset;
  const _StatCard({required this.title, required this.value, this.icon, this.asset}) : assert(icon != null || asset != null);
  @override Widget build(BuildContext context){
    final accent=sectionAccent(title);
    final leading = asset != null
        ? appAssetIcon(asset!, size: 24, accent: accent, selected: true)
        : CircleAvatar(backgroundColor:accent.withValues(alpha:.16),child:Icon(icon,color:accent));
    return SizedBox(width:230,child:Card(child:Container(
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:LinearGradient(colors:[accent.withValues(alpha:.16),Theme.of(context).colorScheme.surface.withValues(alpha:.96)])),
      padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        leading,const SizedBox(height:10),
        Text(title,style:TextStyle(color:accent,fontWeight:FontWeight.w800)),const SizedBox(height:4),
        Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))
      ]),
    )));
  }
}
class _MoneyCard extends StatelessWidget { final String title; final double value; final VoidCallback? onTap; const _MoneyCard({required this.title,required this.value,this.onTap}); @override Widget build(BuildContext context)=>SizedBox(width:210,child:Card(child:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title),const SizedBox(height:8),Text('${value.toStringAsFixed(2)} lei',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))]))))); }
class _InfoCard extends StatelessWidget {
  final IconData icon; final String title,text;
  const _InfoCard({required this.icon,required this.title,required this.text});
  @override Widget build(BuildContext context){
    final accent=sectionAccent(title);
    return Card(child:ListTile(
      leading:CircleAvatar(backgroundColor:accent.withValues(alpha:.14),child:Icon(icon,color:accent)),
      title:Text(title,style:TextStyle(fontWeight:FontWeight.w800,color:accent)),subtitle:Text(text),
    ));
  }
}
class _Empty extends StatelessWidget { final IconData icon; final String text; const _Empty({required this.icon,required this.text}); @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(28),child:Row(children:[Icon(icon,size:30),const SizedBox(width:14),Expanded(child:Text(text))]))); }
