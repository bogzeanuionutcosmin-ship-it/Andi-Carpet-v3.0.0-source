import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform;
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
import 'centralizer/correction_writer.dart';
import 'centralizer/manual_execution_defaults.dart';
import 'schedule/schedule_save_failure.dart';
import 'operations/record_writer.dart';
import 'operations/atomic_restore.dart';
import 'utils/date_formatters.dart';
export 'utils/date_formatters.dart';
import 'ui/badge_metadata.dart';
export 'ui/badge_metadata.dart';
import 'ui/section_accent_palette.dart';
import 'ui/font_choice_normalization.dart';
import 'models/location_category_and_function_definition.dart';
import 'reports/pdf_filename_normalization.dart';
import 'ui/branding_asset_catalog.dart';
export 'ui/branding_asset_catalog.dart';
export 'reports/pdf_filename_normalization.dart';
export 'models/location_category_and_function_definition.dart';
export 'ui/font_choice_normalization.dart';
export 'ui/section_accent_palette.dart';
import 'models/app_enums_permissions.dart';
export 'models/app_enums_permissions.dart';
import 'ui/section_asset_catalog.dart';
export 'ui/section_asset_catalog.dart';

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
part 'expenses/expense_page.dart';
part 'expenses/expense_ocr_prefill.dart';
part 'admin/admin_navigation_catalog.dart';
part 'admin/backup_codec.dart';
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
part 'auth/firebase_user_profile.dart';
part 'auth/auth_gate.dart';
part 'auth/login_registration_page.dart';
part 'auth/account_access_pages.dart';
part 'home/home_backup_maintenance.dart';
part 'home/home_permission_maintenance.dart';
part 'home/home_page.dart';
part 'home/home_document_codecs.dart';
part 'home/home_location_seed.dart';

const MethodChannel _smsGatewayChannel = MethodChannel('andi_carpeta/sms_gateway');
const String _registerSmsGatewayUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/registerSmsGateway';
const String _disableSmsGatewayUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/disableSmsGateway';
const String _geocodeRomaniaPlaceUrl = 'https://europe-central2-andicarpet-e777e.cloudfunctions.net/geocodeRomaniaPlace';
const String _appVersionLabel = '3.0.1+33';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _initializeFirebaseForPlatform();
    if (!usesLocalFirebaseEmulators) FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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

