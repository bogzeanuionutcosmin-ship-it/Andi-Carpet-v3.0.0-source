part of '../main.dart';

extension _ProgramGraphActions on _ProgramPageState {
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
