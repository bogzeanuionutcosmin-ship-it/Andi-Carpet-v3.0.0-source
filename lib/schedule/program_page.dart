part of '../main.dart';

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


}

// Puncte verificate pentru import controlat. Importul NU mută niciodată un marker
// care are deja coordonate în Firestore. Locațiile neclare rămân în lista
// „Neașezate pe hartă”, pentru verificare manuală.
