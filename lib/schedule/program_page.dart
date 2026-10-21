part of '../main.dart';

/// Keeps the schedule screen on a team accepted by the same access callback
/// that guards rendering and writes. The fallback preserves read-only browsing
/// when the user has no team assignment.
int preferredProgramTeamIndex({
  required List<Team> teams,
  required int currentIndex,
  required bool Function(String teamId) canEditTeam,
}) {
  if (teams.isEmpty) return -1;
  if (currentIndex < 0 || currentIndex >= teams.length) {
    return currentIndex.clamp(0, teams.length - 1).toInt();
  }
  final selectedIsEditable = currentIndex >= 0 &&
      currentIndex < teams.length &&
      canEditTeam(teams[currentIndex].id);
  if (selectedIsEditable) return currentIndex;
  final editableIndex = teams.indexWhere((team) => canEditTeam(team.id));
  return editableIndex >= 0
      ? editableIndex
      : currentIndex.clamp(0, teams.length - 1).toInt();
}

class ProgramPage extends StatefulWidget {
  final AppUser currentUser; final List<Team> teams; final List<Car> cars; final List<Location> locations; final List<LocationCategory> categories; final List<WorkSchedule> schedules; final List<CentralizerRecord> records; final AppSettings settings; final bool Function(String) canEditTeam; final bool canEditProgram; final String Function(String) userName; final VoidCallback onChanged; final void Function(String,String,String) notifyTeam; final void Function(String,String) log; final Future<void> Function(List<WorkSchedule>) saveSchedules; final Future<Map<String,dynamic>?> Function(String query)? geocodeTripPoint;
  const ProgramPage({super.key, required this.currentUser, required this.teams, required this.cars, required this.locations, required this.categories, required this.schedules, required this.records, required this.settings, required this.canEditTeam, required this.canEditProgram, required this.userName, required this.onChanged, required this.notifyTeam, required this.log, required this.saveSchedules, this.geocodeTripPoint});
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
  List<String> get graphIds => orderedProgramGraphIds<WorkSchedule>(
    schedules: teamSchedules,
    graphIdOf: (schedule) => schedule.graphId,
    dateOf: (schedule) => schedule.date,
  );
  WorkSchedule? get graphHead => graphSchedules.isEmpty ? null : graphSchedules.first;
  Car? get assignedCar {
    final id = team.carId;
    if (id == null) return null;
    for (final c in widget.cars) { if (c.id == id) return c; }
    return null;
  }

  CentralizerRecord? _latestRecordForItem(ScheduleItem item, DateTime workDate) {
    final rs = selectWorkDateRecords(
      widget.records,
      teamId: team.id,
      locationId: item.locationId,
      teamIdOf: (record) => record.teamId,
      locationIdOf: (record) => record.locationId,
      belongsToWorkDate: (record) => recordBelongsToWorkDate(record, workDate),
    )..sort((a,b)=>recordEventTime(a).compareTo(recordEventTime(b)));
    return rs.isEmpty ? null : rs.last;
  }

  Duration? _averageDurationForLocation(String locationId) => learnedAverageDuration(widget.records, locationId, widget.settings);

  List<ScheduleItem> _pendingItemsForDay(WorkSchedule day, DateTime workDate, {bool includeActive = true}) {
    return pendingProgramItems<ScheduleItem, CentralizerRecord>(
      items: day.items,
      latestRecordForItem: (item) => _latestRecordForItem(item, workDate),
      isTerminal: (record) =>
          record?.status == WorkAttemptStatus.completed ||
          record?.status == WorkAttemptStatus.refused ||
          record?.status == WorkAttemptStatus.notCompleted,
      isActive: (record) =>
          record?.status == WorkAttemptStatus.running ||
          record?.status == WorkAttemptStatus.waitingAccess,
      includeActive: includeActive,
    );
  }

  DateTime? _estimatedEndForDay(WorkSchedule day, DateTime now) {
    final workDate = operationalWorkDate(now);
    final pending = _pendingItemsForDay(day, workDate);
    return estimateProgramFinish<ScheduleItem, CentralizerRecord>(
      now: now,
      pendingItems: pending,
      averageDurationForItem: (item) =>
          _averageDurationForLocation(item.locationId),
      latestRecordForItem: (item) => _latestRecordForItem(item, workDate),
      isRunning: (record) => record?.status == WorkAttemptStatus.running,
      startedAt: (record) => record?.startedAt,
    );
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
      final updated = cloneWorkSchedule(day);
      updated.planAlertAt = DateTime.now();
      updated.planAlertReason = reason;
      await widget.saveSchedules(<WorkSchedule>[updated]);
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
    final updated = cloneWorkSchedule(day);
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
    await widget.saveSchedules(<WorkSchedule>[updated]);
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
    final current = cloneWorkSchedule(day);
    final ids = transferable.map((e)=>e.locationId).toSet();
    current.items.removeWhere((e)=>ids.contains(e.locationId));
    for(var i=0;i<current.items.length;i++)current.items[i].order=i+1;
    WorkSchedule? existingNext;
    for(final s in graphSchedules){if(sameDay(s.date,nextDate)){existingNext=s;break;}}
    final next = existingNext==null
      ? WorkSchedule(id:idNow(),teamId:day.teamId,graphId:day.graphId,graphName:day.graphName,date:nextDate,items:<ScheduleItem>[],active:true,started:day.started)
      : cloneWorkSchedule(existingNext);
    final moved = transferable.map((e)=>ScheduleItem(locationId:e.locationId,locationNameSnapshot:e.locationNameSnapshot,addressSnapshot:e.addressSnapshot,typeSnapshot:e.typeSnapshot,categoryIdSnapshot:e.categoryIdSnapshot,order:0,transferred:true,facadePlanned:e.facadePlanned)).toList();
    next.items = <ScheduleItem>[...moved,...next.items.where((x)=>!ids.contains(x.locationId))];
    for(var i=0;i<next.items.length;i++)next.items[i].order=i+1;
    try { await widget.saveSchedules(<WorkSchedule>[current, next]); } catch (e) { if (mounted) showErrorMessage(context, 'Transferul nu a putut fi salvat: ${scheduleSaveFailureMessage(e)}'); return; }
    widget.onChanged();
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
    teamIndex = preferredProgramTeamIndex(
      teams: widget.teams,
      currentIndex: teamIndex,
      canEditTeam: widget.canEditTeam,
    );
    _ensureGraphSelection();
    final can = widget.canEditProgram && widget.canEditTeam(team.id);
    final canAdministerGraph = widget.currentUser.role == UserRole.director;
    final isTeamMember = widget.canEditTeam(team.id);
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
        if(!can) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:_InfoCard(
          icon:Icons.lock_outline,
          title:!isTeamMember?'Nu ești repartizat în echipa ${team.name}':'Lipsește dreptul de editare a graficului',
          text:!isTeamMember
              ?'Administratorul trebuie să te adauge în Admin → Echipe → ${team.name}. Graficul poate fi citit, dar editarea rămâne blocată până când apartenența este confirmată de Firestore.'
              :!widget.canEditProgram
                  ?'Contul tău este în echipa selectată, dar funcția atribuită nu are dreptul „Poate modifica graficul de lucru”. Cere unui Admin să verifice Admin → Membri / Conturi → Funcții și dreptul editProgram.'
                  :'Accesul echipei sau drepturile contului s-au schimbat. Reîncarcă aplicația și cere administratorului să verifice repartizarea echipei și dreptul editProgram.',
        )),
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
                if(canAdministerGraph&&head.started&&!head.closed&&!head.paused) OutlinedButton.icon(onPressed:_pauseGraph,icon:const Icon(Icons.pause),label:const Text('Pauză')),
                if(canAdministerGraph&&head.started&&!head.closed&&head.paused) FilledButton.tonalIcon(onPressed:_resumeGraph,icon:const Icon(Icons.play_circle_outline),label:const Text('Reia')),
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
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
              initiallyExpanded:true,
              title:const Text('Editare zile',style:TextStyle(fontWeight:FontWeight.bold)),
              subtitle:const Text('Adaugă sau elimină locații; trage de mânerul din dreapta pentru a schimba ordinea.'),
              children:graphSchedules.map((s)=>Padding(padding:const EdgeInsets.only(bottom:10),child:_ScheduleCardFull(
                schedule:s,locations:widget.locations,categories:widget.categories,records:widget.records,canEdit:can,
                onAdd:()=>_addLocations(s),onRemove:(item)=>unawaited(_removeItem(s,item)),onReorder:(a,b)=>unawaited(_reorder(s,a,b)),
              ))).toList(),
              ),
            ),
          ],
          if(can&&head.closed) const Padding(padding:EdgeInsets.symmetric(vertical:8),child:_InfoCard(icon:Icons.lock_clock_outlined,title:'Grafic închis',text:'Editarea locațiilor este blocată după închiderea graficului.')),
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
        insetPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
        title:Text('Creează grafic · Ziua ${dayIndex+1}'),
        content:SizedBox(width:760,height:MediaQuery.sizeOf(c).height*.72,child:CustomScrollView(slivers:[SliverToBoxAdapter(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Wrap(spacing:6,runSpacing:6,children:days.asMap().entries.map((e)=>ChoiceChip(label:Text('Ziua ${e.key+1} · ${e.value.length}'),selected:e.key==dayIndex,onSelected:(_)=>setD((){dayIndex=e.key;query='';}))).toList()),
          const SizedBox(height:8),
          if(selected.isNotEmpty) ConstrainedBox(constraints:const BoxConstraints(maxHeight:160),child:SingleChildScrollView(child:Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Theme.of(c).colorScheme.primaryContainer.withValues(alpha:.45),borderRadius:BorderRadius.circular(12)),child:Wrap(spacing:6,runSpacing:6,children:selected.asMap().entries.map((e){final l=available.firstWhere((x)=>x.id==e.value);return Chip(label:Text('${e.key+1}. ${l.name}'),onDeleted:()=>setD(()=>selected.remove(e.value)));}).toList())))),
          const SizedBox(height:8),
          TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Caută sală / adresă / categorie'),onChanged:(v)=>setD(()=>query=v)),
          const SizedBox(height:8),
        ])),
          SliverList(delegate:SliverChildListDelegate(filtered.map((l)=>CheckboxListTile(
            value:selected.contains(l.id),
            secondary: categoryBrandWidget(l.categoryId, size: 28, fallbackColor: categoryColor(widget.categories,l.categoryId,fallbackType:l.type)),
            title:Text(l.name),subtitle:Text('${categoryName(widget.categories,l.categoryId,fallbackType:l.type)} · ${l.address}'),
            onChanged:(v)=>setD((){if(v==true){if(!selected.contains(l.id))selected.add(l.id);}else{selected.remove(l.id);}}),
          )).toList())),
        ])),
        actions:[Wrap(alignment:WrapAlignment.end,spacing:8,runSpacing:8,children:[
          TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),
          if(dayIndex>0) OutlinedButton.icon(onPressed:()=>setD((){dayIndex--;query='';}),icon:const Icon(Icons.arrow_back),label:const Text('Ziua anterioară')),
          FilledButton.tonalIcon(onPressed:selected.isEmpty?null:()=>setD((){if(dayIndex==days.length-1)days.add(<String>[]);dayIndex++;query='';}),icon:const Icon(Icons.arrow_forward),label:const Text('Următoarea zi')),
          FilledButton.icon(onPressed:days.where((d)=>d.isNotEmpty).isEmpty?null:()=>Navigator.pop(c,days.where((d)=>d.isNotEmpty).map((d)=>[...d]).toList()),icon:const Icon(Icons.done_all),label:const Text('Finalizare')),
        ])],
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
    var graphNameInput=graphDefaultName(startDate);
    final meta=await showDialog<Map<String,dynamic>>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD){
      final endDate=DateTime(startDate.year,startDate.month,startDate.day).add(Duration(days:drafted.length-1));
      return AlertDialog(title:const Text('Finalizează Graficul de lucru'),content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        TextFormField(initialValue:graphNameInput,onChanged:(value)=>graphNameInput=value,decoration:const InputDecoration(labelText:'Nume grafic')),
        const SizedBox(height:12),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.play_circle_outline),title:const Text('Data început'),subtitle:Text(formatDate(startDate)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:c,firstDate:DateTime(2025),lastDate:DateTime(2035),initialDate:startDate);if(d!=null)setD(()=>startDate=d);}),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.flag_outlined),title:const Text('Data final'),subtitle:Text(formatDate(endDate))),
        Text('${drafted.length} zile · ${drafted.fold<int>(0,(a,b)=>a+b.length)} locații selectate'),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Înapoi')),FilledButton(onPressed:()=>Navigator.pop(c,{'name':graphNameInput.trim().isEmpty?graphDefaultName(startDate):graphNameInput.trim(),'start':startDate}),child:const Text('Creează graficul'))]);
    }));
    if(meta==null)return;
    final graphId=idNow();final graphName=meta['name'] as String;final start=meta['start'] as DateTime;
    try{
      final created=<WorkSchedule>[];
      for(var d=0;d<drafted.length;d++){
        final date=DateTime(start.year,start.month,start.day).add(Duration(days:d));
        final ids=drafted[d];
        final items=<ScheduleItem>[];
        for(var i=0;i<ids.length;i++){final l=available.firstWhere((x)=>x.id==ids[i]);items.add(ScheduleItem(locationId:l.id,locationNameSnapshot:l.name,addressSnapshot:l.address,typeSnapshot:l.type,categoryIdSnapshot:l.categoryId,order:i+1,facadePlanned:facadePlanKeys.contains('$d:${l.id}')));}
        created.add(WorkSchedule(id:idNow(),teamId:team.id,graphId:graphId,graphName:graphName,date:date,items:items));
      }
      await widget.saveSchedules(created);
      widget.log('Grafic de lucru creat','$graphName · ${drafted.length} zile · ${team.name}');
      widget.notifyTeam(team.id,'Grafic de lucru creat','$graphName · ${drafted.length} zile.');
      if(mounted){setState(()=>selectedGraphId=graphId);showSuccessMessage(context,'Graficul a fost creat cu ${drafted.length} zile.');}
    }catch(e){if(mounted)showErrorMessage(context,'Graficul nu a putut fi creat: ${scheduleSaveFailureMessage(e)}');}
  }

  Future<void> _addLocations(WorkSchedule s) async {
    final picked=await _locationDialog(s.items.map((i)=>i.locationId).toList());
    if(picked==null||!mounted)return;
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
    if(accepted!=true||!mounted)return;
    final updated=cloneWorkSchedule(s);updated.items.addAll(createProgramScheduleItems(locations:additions,firstOrder:updated.items.length+1,facadePlannedLocationIds:facadeIds));
    await _saveWithFeedback(updated,success:'Locațiile au fost adăugate în ziua selectată.',auditAction:'Locații adăugate în Grafic');
  }
  
  Future<bool> _saveWithFeedback(WorkSchedule s,{required String success,required String auditAction})async{try{await widget.saveSchedules(<WorkSchedule>[s]);if(!mounted)return true;widget.onChanged();widget.log(auditAction,'${team.name} · ${s.graphName} · ${formatDate(s.date)}');widget.notifyTeam(team.id,'Grafic de lucru modificat','${s.graphName} · ${formatDate(s.date)} a fost actualizat.');showSuccessMessage(context,success);return true;}catch(e){if(mounted)showErrorMessage(context,'Graficul nu a putut fi salvat: ${scheduleSaveFailureMessage(e)}');return false;}}
  Future<bool> _applyGraphState({bool? started,bool? closed,bool? paused})async{try{await saveProgramGraphState(
      schedules: graphSchedules,
      clone: cloneWorkSchedule,
      save: widget.saveSchedules,
      started: started,
      closed: closed,
      paused: paused,
    );if(!mounted)return true;widget.onChanged();return true;}catch(e){if(mounted)showErrorMessage(context,'Graficul nu a putut fi actualizat: ${scheduleSaveFailureMessage(e)}');return false;}}
  Future<Map<String,dynamic>?> _geocodeTripPoint(String query) async {
    return RomaniaPlaceGeocoder(
      serverEndpoint: Uri.parse(_geocodeRomaniaPlaceUrl),
      getIdToken: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
      get: (uri, {headers}) => http.get(uri, headers: headers),
      post: (uri, {headers, body}) => http.post(uri, headers: headers, body: body),
      isWeb: kIsWeb,
      includeName: true,
      log: (message) => debugPrint(message),
    ).geocode(query);
  }

  Future<void> _startGraph()async{
    final head=graphHead;if(head==null)return;
    var departureInput=head.departureName;
    var destinationInput=head.returnName;
    final choice=await showDialog<Map<String,String>>(context:context,barrierDismissible:false,builder:(c)=>AlertDialog(
      title:const Text('Pornește Graficul de lucru'),
      content:SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Alege punctul real de plecare și punctul în care se termină deplasarea. Acestea sunt folosite numai pentru traseu, kilometri și consum; nu apar în Centralizator.'),
        const SizedBox(height:14),
        TextFormField(initialValue:departureInput,decoration:const InputDecoration(labelText:'Plecare',hintText:'Ex: Brăila'),onChanged:(value)=>departureInput=value),
        const SizedBox(height:10),
        TextFormField(initialValue:destinationInput,decoration:const InputDecoration(labelText:'Întoarcere / destinație finală',hintText:'Ex: Brăila'),onChanged:(value)=>destinationInput=value),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,{'departure':departureInput.trim(),'return':destinationInput.trim()}),child:const Text('START'))],
    ));
    if(choice==null)return;
    final departureText=(choice['departure']??'').trim();final returnText=(choice['return']??'').trim();
    if(departureText.isEmpty||returnText.isEmpty){if(mounted)showErrorMessage(context,'Completează atât plecarea, cât și punctul final.');return;}
    if(mounted)showSuccessMessage(context,'Identific punctele de plecare și întoarcere…');
    final tripPoints=await resolveProgramStartLocations(
      departure:departureText,
      destination:returnText,
      geocode:widget.geocodeTripPoint ?? _geocodeTripPoint,
    );
    if(tripPoints==null){if(mounted)showErrorMessage(context,'Nu am putut identifica una dintre localități. Scrie localitatea mai explicit, de exemplu „Brăila, România”.');return;}
    final items=buildStartedProgramScheduleSnapshot(
      schedules:graphSchedules,
      departureName:departureText,
      departureLatitude:tripPoints.departureLatitude,
      departureLongitude:tripPoints.departureLongitude,
      returnName:returnText,
      returnLatitude:tripPoints.destinationLatitude,
      returnLongitude:tripPoints.destinationLongitude,
    );
    try { await widget.saveSchedules(items); } catch (e) { if (mounted) showErrorMessage(context, 'Graficul nu a putut fi pornit: ${scheduleSaveFailureMessage(e)}'); return; }
    widget.onChanged();
    final km=estimateGraphDistanceKm(items,widget.locations);
    widget.log('Grafic pornit','${team.name} · ${head.graphName} · $departureText → $returnText · ${km.toStringAsFixed(1)} km estimați');
    if(mounted)showSuccessMessage(context,'Grafic pornit. Traseu complet: $departureText → săli → $returnText · ${km.toStringAsFixed(1)} km estimați.');
  }
  Future<void> _pauseGraph()async{if(!await _applyGraphState(paused:true))return;widget.log('Grafic pus pe pauză','${team.name} · ${graphHead?.graphName??''}');if(mounted)showSuccessMessage(context,'Graficul a fost pus pe pauză.');}
  Future<void> _resumeGraph()async{if(!await _applyGraphState(paused:false))return;widget.log('Grafic reluat','${team.name} · ${graphHead?.graphName??''}');if(mounted)showSuccessMessage(context,'Graficul a fost reluat.');}
  Future<void> _closeGraph()async{
    final readiness=programGraphClosureReadiness(
      schedules:graphSchedules,
      records:widget.records,
    );
    if(!readiness.canClose){
      final preview=readiness.blockers.take(5).join('\n');
      final remainder=readiness.blockers.length>5
          ?'\n… și încă ${readiness.blockers.length-5} intervenții.'
          :'';
      if(mounted)showErrorMessage(context,
        'STOP blocat: ${readiness.blockers.length} intervenții nu au rezultat final.\n$preview$remainder');
      return;
    }
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('STOP Grafic de lucru'),
      content:const Text('Toate intervențiile principale sunt finalizate sau au fost declarate nerealizate cu explicație. Graficul complet va fi închis. Istoricul și Centralizatorul rămân păstrate.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('STOP'))],
    ))??false;
    if(!ok)return;
    if(!await _applyGraphState(closed:true,paused:false))return;
    widget.log('Grafic închis','${team.name} · ${graphHead?.graphName??''}');
    if(mounted)showSuccessMessage(context,'Graficul a fost închis.');
  }
  Future<void> _postponeGraph()async{
    if(graphSchedules.isEmpty)return;DateTime selected=graphSchedules.firstWhere((x)=>!x.date.isBefore(operationalWorkDate(DateTime.now())),orElse:()=>graphSchedules.first).date;
    final chosen=await showDialog<DateTime>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(title:const Text('Amână programul'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Alege ziua de la care vrei să deplasezi graficul cu +1 zi.'),const SizedBox(height:10),DropdownButtonFormField<DateTime>(value:selected,items:graphSchedules.map((x)=>DropdownMenuItem(value:x.date,child:Text(formatDate(x.date)))).toList(),onChanged:(v){if(v!=null)setD(()=>selected=v);})]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,selected),child:const Text('Amână cu 1 zi'))])));
    if(chosen==null)return;
    final affected=postponeProgramSchedules<WorkSchedule>(
      schedules:graphSchedules,
      startDate:chosen,
      dateOf:(schedule)=>schedule.date,
      clone:cloneWorkSchedule,
      setDate:(schedule,date)=>schedule.date=date,
    );
    try{await widget.saveSchedules(affected);}catch(e){if(mounted)showErrorMessage(context,'Graficul nu a putut fi amânat: ${scheduleSaveFailureMessage(e)}');return;}
    widget.log('Grafic amânat','${team.name} · de la ${formatDate(chosen)} · +1 zi');
    if(mounted)showSuccessMessage(context,'Graficul s-a actualizat în timp real: zilele au fost mutate cu +1 zi.');
  }
  Future<void> _removeItem(WorkSchedule s,ScheduleItem item)async{final updated=cloneWorkSchedule(s,items:removeProgramScheduleItem(s.items,locationId:item.locationId,order:item.order));await _saveWithFeedback(updated,success:'Locația a fost eliminată.',auditAction:'Locație eliminată din Grafic');}
  Future<void> _reorder(
    WorkSchedule schedule,
    int oldIndex,
    int newIndex,
  ) async {
    final reorderedItems =
        reorderScheduleItems(schedule.items, oldIndex, newIndex);
    if (reorderedItems == null) return;

    final updated = cloneWorkSchedule(schedule, items: reorderedItems);
    final saved = await _saveWithFeedback(
      updated,
      success: 'Ordinea zilei a fost salvată.',
      auditAction: 'Ordine Grafic modificată',
    );
    if (saved) {
      unawaited(_recordRoutingChoice(updated, 'manual_order'));
    }
  }
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
