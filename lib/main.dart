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

part 'ui/dashboard_map_components.dart';
part 'ui/auth_status_components.dart';
part 'auth/quick_accounts.dart';
part 'ui/branding_theme_helpers.dart';
part 'ui/install_app_buttons.dart';
part 'bootstrap/firebase_initialization.dart';
part 'bootstrap/firebase_bootstrap_error_app.dart';
part 'utils/operational_dates.dart';
part 'map/verified_location_fix.dart';
part 'map/graph_route_calculations.dart';
part 'map/location_adjust_page.dart';
part 'reports/pdf_reports.dart';
part 'documents/documents_page.dart';
part 'contacts/location_contacts_page.dart';
part 'models/app_data_models.dart';
part 'models/app_enums_permissions.dart';
part 'models/permission_status_labels.dart';
part 'learning/duration_estimates.dart';
part 'ui/section_visual_helpers.dart';
part 'ui/app_backdrop.dart';
part 'ui/icon_badge_catalog.dart';
part 'ui/interactive_member_badges.dart';
part 'models/location_category_helpers.dart';
part 'models/default_categories_functions.dart';
part 'models/location_status_and_functions.dart';
part 'reports/pdf_format_helpers.dart';
part 'ui/app_root_theme.dart';
part 'ui/app_information_page.dart';
part 'notifications/sms_gateway_card.dart';
part 'notifications/push_diagnostics_page.dart';
part 'chat/private_chat_page.dart';
part 'chat/group_chat_page.dart';
part 'members/member_profile_page.dart';
part 'members/members_directory_page.dart';
part 'feedback/feedback_page.dart';
part 'schedule/schedule_card_full.dart';
part 'teams/team_selector.dart';
part 'ui/page_shell.dart';
part 'ui/summary_cards.dart';
part 'ui/empty_state.dart';
part 'settings/settings_page.dart';
part 'profile/profile_page.dart';
part 'centralizer/centralizer_page.dart';
part 'dashboard/dashboard_page.dart';
part 'map/map_page.dart';
part 'schedule/program_page.dart';
part 'auth/firebase_user_profile.dart';
part 'auth/auth_gate.dart';
part 'auth/login_registration_page.dart';
part 'auth/account_access_pages.dart';
part 'home/home_page.dart';

const MethodChannel _smsGatewayChannel = MethodChannel('andi_carpeta/sms_gateway');
const String _registerSmsGatewayUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/registerSmsGateway';
const String _disableSmsGatewayUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/disableSmsGateway';
const String _geocodeRomaniaPlaceUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/geocodeRomaniaPlace';
const String _appVersionLabel = '3.0.0+32';

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

// ============================================================
// ANDI CARPETĂ - aplicație operațională Flutter + Firebase
// ============================================================
// Datele operaționale sunt sincronizate prin Firestore. Harta, GPS-ul,
// PDF-urile, funcțiile dinamice și administrarea sunt integrate aici.
// ============================================================

String graphDefaultName(DateTime d) => 'Grafic ${d.month.toString().padLeft(2, '0')}/${d.year}';

String idNow() => DateTime.now().microsecondsSinceEpoch.toString();

AppSettings? _activeAppSettingsForBranding;


/// Punctele reale ale deplasării; capetele nu sunt intervenții de lucru.
/// Un grafic incomplet GPS nu trebuie raportat ca traseu complet.





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
    if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
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
    // Keep controllers alive through the closing dialog animation.
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
