part of '../main.dart';

extension _DashboardWorkActions on _DashboardPageState {
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
