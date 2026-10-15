part of '../main.dart';

extension _ProgramRouteLearningActions on _ProgramPageState {
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


}
