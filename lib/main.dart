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
                if (_showGraphRoute &&
                    graphRoutePoints(_routeDays, widget.locations).points.length >= 2)
                  FutureBuilder<List<List<double>>?>(
                    future: _loadRoadGeometry(graphRoutePoints(_routeDays, widget.locations).points),
                    builder: (context, snapshot) {
                      final coords = snapshot.data;
                      final hasRoadGeometry = coords != null && coords.length >= 2;
                      final displayPoints = hasRoadGeometry
                          ? coords.map((p) => LatLng(p[0], p[1])).toList()
                          : graphRoutePoints(_routeDays, widget.locations).points;
                      // Schematic fallback when Mapbox cannot provide road geometry.
                      return PolylineLayer(polylines: [
                        Polyline(
                          points: displayPoints,
                          color: hasRoadGeometry ? Colors.deepOrangeAccent : Colors.blueGrey,
                          strokeWidth: hasRoadGeometry ? 6 : 3,
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
