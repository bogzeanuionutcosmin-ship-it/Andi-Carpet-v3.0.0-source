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
import 'map/graph_route_calculations.dart';
export 'map/graph_route_calculations.dart';
import 'map/graph_road_distance.dart' as graph_routing;
import 'reports/pdf_report_format.dart' as pdf_format;
import 'utils/graph_names.dart';
export 'utils/graph_names.dart';
import 'models/app_data_models.dart';
export 'models/app_data_models.dart';
import 'utils/operational_dates.dart';
export 'utils/operational_dates.dart';
import 'learning/duration_estimates.dart';
export 'learning/duration_estimates.dart';
import 'models/app_enums_permissions.dart';
export 'models/app_enums_permissions.dart';
import 'models/location_status_and_functions.dart';
export 'models/location_status_and_functions.dart';
import 'models/default_categories_functions.dart';
export 'models/default_categories_functions.dart';
import 'models/location_category_helpers.dart';
export 'models/location_category_helpers.dart';
import 'models/permission_status_labels.dart';
import 'home/seed_operational_locations.dart' as operational_location_seed;
import 'admin/admin_navigation_catalog.dart' as admin_navigation;
import 'ui/icon_badge_catalog.dart';
import 'teams/team_selector.dart' as team_selector;
import 'schedule/schedule_card_full.dart' as schedule_card;
import 'ui/branding_theme_helpers.dart' as branding_helpers;
import 'admin/backup_codec.dart' as backup_codec;
export 'ui/branding_theme_helpers.dart' show appBrandLogo;
import 'ui/section_visual_helpers.dart';
export 'ui/section_visual_helpers.dart'
    show sectionAccent, showSuccessMessage, showErrorMessage;
import 'ui/empty_state.dart' as empty_state;
import 'ui/money_card.dart' as money_card;
import 'ui/info_card.dart' as info_card;
import 'ui/stat_card.dart' as stat_card;
import 'ui/app_backdrop.dart' as app_backdrop;
import 'ui/install_app_buttons_view.dart' as install_buttons;
import 'ui/interactive_member_badges.dart' as member_badges;
import 'ui/auth_status_views.dart' as auth_status;
import 'bootstrap/firebase_bootstrap_error_app.dart' as bootstrap_error;
import 'map/verified_location_fix.dart' as verified_fix;
import 'ui/dashboard_map_components.dart' as dashboard_components;
import 'auth/account_access_views.dart' as account_access_views;
import 'ui/app_capabilities_view.dart' as app_capabilities;
export 'ui/icon_badge_catalog.dart';
export 'models/permission_status_labels.dart';

part 'auth/quick_accounts.dart';
part 'ui/install_app_buttons.dart';
part 'bootstrap/firebase_initialization.dart';
part 'map/location_adjust_page.dart';
part 'reports/pdf_reports.dart';
part 'documents/documents_page.dart';
part 'contacts/location_contacts_page.dart';
part 'ui/app_root_theme.dart';
part 'ui/app_information_page.dart';
part 'notifications/sms_gateway_card.dart';
part 'notifications/push_diagnostics_page.dart';
part 'chat/private_chat_page.dart';
part 'chat/group_chat_page.dart';
part 'members/member_profile_page.dart';
part 'members/members_directory_page.dart';
part 'feedback/feedback_page.dart';
part 'ui/page_shell.dart';
part 'settings/settings_page.dart';
part 'profile/profile_page.dart';
part 'centralizer/centralizer_page.dart';
part 'dashboard/dashboard_page.dart';
part 'dashboard/dashboard_work_actions.dart';
part 'map/map_page.dart';
part 'map/map_verified_import_actions.dart';
part 'map/map_location_actions.dart';
part 'expenses/expense_page.dart';
part 'expenses/expense_settlement_actions.dart';
part 'expenses/expense_per_diem_actions.dart';
part 'expenses/expense_document_actions.dart';
part 'admin/admin_backup_actions.dart';
part 'admin/admin_team_actions.dart';
part 'admin/admin_member_actions.dart';
part 'admin/admin_car_actions.dart';
part 'admin/admin_location_actions.dart';
part 'admin/admin_operations_actions.dart';
part 'admin/admin_learning_actions.dart';
part 'admin/admin_communications_actions.dart';
part 'admin/admin_dashboard_actions.dart';
part 'admin/admin_function_rights_actions.dart';
part 'admin/admin_settings_actions.dart';
part 'admin/admin_backup_panel_actions.dart';
part 'admin/admin_panel_page.dart';
part 'schedule/program_page.dart';
part 'schedule/program_route_learning_actions.dart';
part 'schedule/program_graph_actions.dart';
part 'auth/firebase_user_profile.dart';
part 'auth/auth_gate.dart';
part 'auth/login_registration_page.dart';
part 'auth/account_access_pages.dart';
part 'home/home_backup_maintenance.dart';
part 'home/home_permission_maintenance.dart';
part 'home/home_page.dart';
part 'home/home_push_notifications.dart';
part 'home/home_live_location.dart';
part 'home/home_work_automation.dart';
part 'home/home_navigation.dart';
part 'home/home_sync_listeners.dart';
part 'home/home_directory_definitions_audit_sync.dart';
part 'home/home_financial_sync.dart';
part 'home/home_financial_write_actions.dart';
part 'home/home_operational_write_actions.dart';
part 'home/home_audit_persistence.dart';
part 'home/home_document_codecs.dart';

// Application adapter: retain the singleton and lazy initialization in main.
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
  return graph_routing.calculateGraphRoadDistanceKm(
    days, locations,
    mapboxEnabled: kMapboxEnabled,
    drivingKm: (points) => _mapboxServices.drivingKm(points),
    get: (uri) => http.get(uri),
  );
}

// Keep the existing private adapter name for callers in main.dart parts.
Color _plainBackgroundColor(AppSettings settings, Brightness brightness) =>
    plainBackgroundColor(settings, brightness);

String _normalizeFontChoice(String? raw) =>
    branding_helpers.normalizeFontChoice(raw);
String? _resolvedFontFamily(String choice) =>
    branding_helpers.resolvedFontFamily(choice);
const Map<String, String> _bundledBackgroundAssets =
    branding_helpers.bundledBackgroundAssets;
const Map<String, String> _bundledBackgroundLabels =
    branding_helpers.bundledBackgroundLabels;
const Map<String, String> _bundledLogoAssets =
    branding_helpers.bundledLogoAssets;
const Map<String, String> _bundledLogoLabels =
    branding_helpers.bundledLogoLabels;
String _activeLogoAsset(AppSettings settings) =>
    branding_helpers.activeLogoAsset(settings);
Widget appBrandLogo(AppSettings settings, {double width = 520, double height = 130}) =>
    branding_helpers.appBrandLogo(settings, width: width, height: height);

dynamic _backupEncode(dynamic value) => backup_codec.encodeBackupValue(value);
dynamic _backupDecode(dynamic value) => backup_codec.decodeBackupValue(value);

Widget functionKeyWidget(String key, {double size = 32, Color? color}) =>
    member_badges.functionKeyWidget(key, size: size, color: color);
List<String> effectiveBadgeKeysForFunctionIds(
        List<FunctionDefinition> defs, Iterable<String> ids) =>
    member_badges.effectiveBadgeKeysForFunctionIds(defs, ids);
Widget badgeStripWidget(Iterable<String> keys, {double size = 32, Color? color}) =>
    member_badges.badgeStripWidget(keys, size: size, color: color);
Widget memberBadgeStripWidget(
        List<FunctionDefinition> defs, Iterable<String> functionIds,
        {double size = 32}) =>
    member_badges.memberBadgeStripWidget(defs, functionIds, size: size);

class _TeamSelector extends StatelessWidget {
  final List<Team> teams;
  final int selected;
  final ValueChanged<int> onChanged;
  const _TeamSelector({required this.teams, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => team_selector.TeamSelector(
        teams: teams,
        selected: selected,
        onChanged: onChanged,
        accent: sectionAccent('Echipe'),
      );
}

class _ScheduleCardFull extends StatelessWidget {
  final WorkSchedule schedule;
  final List<Location> locations;
  final List<LocationCategory> categories;
  final List<CentralizerRecord> records;
  final bool canEdit;
  final VoidCallback onAdd;
  final void Function(ScheduleItem) onRemove;
  final void Function(int, int) onReorder;

  const _ScheduleCardFull({
    required this.schedule,
    required this.locations,
    required this.categories,
    required this.records,
    required this.canEdit,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) => schedule_card.ScheduleCardFull(
        schedule: schedule,
        locations: locations,
        categories: categories,
        records: records,
        canEdit: canEdit,
        onAdd: onAdd,
        onRemove: onRemove,
        onReorder: onReorder,
      );
}

IconData _adminSectionIcon(int index) => admin_navigation.adminSectionIcon(index);
String _adminSectionGroup(int index) => admin_navigation.adminSectionGroup(index);
String? _adminSectionAsset(int index) => admin_navigation.adminSectionAsset(index);
Widget _badgeGraphic(String asset, {required double size, Color? color}) =>
    badgeGraphic(asset, size: size, color: color);

class _MoneyCard extends StatelessWidget {
  final String title;
  final double value;
  final VoidCallback? onTap;
  const _MoneyCard({required this.title, required this.value, this.onTap});
  @override
  Widget build(BuildContext context) =>
      money_card.MoneyCard(title: title, value: value, onTap: onTap);
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData? icon;
  final String? asset;
  const _StatCard({required this.title, required this.value, this.icon, this.asset})
      : assert(icon != null || asset != null);

  @override
  Widget build(BuildContext context) {
    final accent = sectionAccent(title);
    final leading = asset != null
        ? appAssetIcon(asset!, size: 24, accent: accent, selected: true)
        : CircleAvatar(
            backgroundColor: accent.withValues(alpha: .16),
            child: Icon(icon, color: accent),
          );
    return stat_card.StatCard(
      title: title,
      value: value,
      accent: accent,
      leading: leading,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _InfoCard({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => info_card.InfoCard(
        icon: icon,
        title: title,
        text: text,
        accent: sectionAccent(title),
      );
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
    final customId =
        selected.startsWith('custom:') ? selected.substring('custom:'.length) : '';
    final customData =
        customId.isEmpty ? null : settings.customBackgrounds[customId];
    return app_backdrop.AppBackdrop(
      plainBackground: _plainBackgroundColor(settings, brightness),
      bundledAsset: bundledAsset,
      customBackgroundBase64:
          customData == null ? null : customData['imageBase64'] ?? '',
      backgroundOpacity: settings.backgroundOpacity,
      child: child,
    );
  }
}

class _FirebaseLoading extends StatelessWidget {
  final String text;
  final AppSettings settings;
  const _FirebaseLoading({required this.text, required this.settings});

  @override
  Widget build(BuildContext context) => auth_status.FirebaseLoadingView(
        text: text,
        logo: appBrandLogo(settings, width: 520, height: 130),
      );
}

class _FirebaseError extends StatelessWidget {
  final String message;
  const _FirebaseError({required this.message});

  @override
  Widget build(BuildContext context) => auth_status.FirebaseErrorView(
        message: message,
        onSignOut: () => FirebaseAuth.instance.signOut(),
      );
}

class _FirebaseBootstrapErrorApp extends StatelessWidget {
  final String message;
  const _FirebaseBootstrapErrorApp({required this.message});

  @override
  Widget build(BuildContext context) =>
      bootstrap_error.FirebaseBootstrapErrorView(message: message);
}

class _VerifiedLocationFix extends verified_fix.VerifiedLocationFix {
  const _VerifiedLocationFix({
    required super.id,
    super.latitude,
    super.longitude,
    super.status,
    required super.verifiedAddress,
    super.confidence = 'ridicată',
    super.note = '',
  });
}


class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) =>
      dashboard_components.StatMini(label: label, value: value, icon: icon);
}

class _MapStatusLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MapStatusLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      dashboard_components.MapStatusLegend(color: color, label: label);
}

class _InstallAppButtons extends StatelessWidget {
  final AppSettings settings;
  final bool compact;
  const _InstallAppButtons({required this.settings, this.compact = false});

  @override
  Widget build(BuildContext context) => install_buttons.InstallAppButtonsView(
        compact: compact,
        onAndroidPressed: () => _showAndroidInstallFlow(context, settings),
        onApplePressed: () => _showAppleInstallFlow(context),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => empty_state.EmptyState(icon: icon, text: text);
}

// PDF composition adapters preserve existing private callers in PDF and JPEG exports.
class _ApplicationPdfFonts implements pdf_format.PdfFontProvider {
  @override
  Future<pw.Font> regular() => PdfGoogleFonts.openSansRegular();

  @override
  Future<pw.Font> bold() => PdfGoogleFonts.openSansBold();

  @override
  Future<pw.Font> italic() => PdfGoogleFonts.openSansItalic();
}

Future<pw.ThemeData> _buildPdfTheme() =>
    pdf_format.buildPdfTheme(_ApplicationPdfFonts());

String _safeFilePart(String text) => pdf_format.safePdfFilePart(text);

String _pdfDate(DateTime date) => pdf_format.formatPdfDate(date, two);

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

