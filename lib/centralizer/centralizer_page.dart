part of '../main.dart';

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
  final Future<void> Function(CentralizerRecord, CentralizerRecord) correctRecord;
  const CentralizerPage({super.key,required this.currentUser,required this.teams,required this.locations,required this.categories,required this.schedules,required this.records,required this.isAdmin,required this.canEditTeam,required this.canEditCentralizer,required this.onChanged,required this.log,required this.saveRecord,required this.correctRecord});
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
            trailing:(widget.isAdmin || (widget.canEditCentralizer && widget.canEditTeam(r.teamId))) && r.status == WorkAttemptStatus.completed
              ? IconButton(tooltip:'Corectează data, orele și fațada',onPressed:()=>_editRecord(r),icon:const Icon(Icons.edit))
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
    if(!fn.isAfter(st!)){
      reason.dispose();
      if(mounted)showErrorMessage(context,'Ora FINAL trebuie să fie după ora START.');
      return;
    }
    final note=reason.text.trim();reason.dispose();
    final l=selectedLocation!;
    // A correction to an existing execution must use Edit, not create a second record.
    final existing=widget.records.where((record)=>
      record.locationId==l.id &&
      record.teamId==selectedTeamId &&
      record.status==WorkAttemptStatus.completed &&
      record.startedAt!=null &&
      sameDay(record.startedAt!,st!)
    ).toList();
    if(existing.isNotEmpty){
      if(!mounted)return;
      final confirmed=await showDialog<bool>(
        context:context,
        builder:(c)=>AlertDialog(
          title:const Text('Execuție deja înregistrată'),
          content:Text('Există deja ${existing.length} execuție/execuții finalizate pentru această sală, echipă și dată. Dacă vrei să corectezi data sau orele, folosește butonul de editare al intervenției existente. Adaugi totuși o execuție distinctă?'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),
            FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Execuție distinctă')),
          ],
        ),
      )??false;
      if(!confirmed)return;
    }
    final r=CentralizerRecord(id:idNow(),teamId:selectedTeamId,locationId:l.id,type:l.type,locationNameSnapshot:l.name,addressSnapshot:l.address,startedAt:st,finishedAt:fn,status:WorkAttemptStatus.completed,refusalReason:note.isEmpty?null:note,keptForLearning:true,facadePlanned:facadeDone,facadeDone:facadeDone);
    try{await widget.saveRecord(r);widget.log('Execuție manuală adăugată',l.name);if(mounted)showSuccessMessage(context,'Execuția a fost adăugată în Centralizator.');}
    catch(e){if(mounted)showErrorMessage(context,'Nu s-a putut salva execuția: $e');}
  }

  Future<void> _editRecord(CentralizerRecord r) async {
    if (r.status != WorkAttemptStatus.completed || r.startedAt == null || r.finishedAt == null) {
      if (mounted) showErrorMessage(context, 'Pot fi corectate doar intervențiile finalizate, cu ore START și FINAL.');
      return;
    }
    final s = TextEditingController(text: timeText(r.startedAt));
    final f = TextEditingController(text: timeText(r.finishedAt));
    var date = r.startedAt ?? r.finishedAt ?? DateTime.now();
    var facadeDone = r.facadeDone;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setDialogState) => AlertDialog(
        title: const Text('Corectează intervenția'),
        content: SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children: [
          ListTile(
            title:const Text('Data intervenției'),
            subtitle:Text(formatDate(date)),
            trailing:const Icon(Icons.calendar_month),
            onTap:()async{
              final first=DateTime(2020);
              final last=DateTime.now().add(const Duration(days:1));
              final initial=date.isBefore(first)?first:(date.isAfter(last)?last:date);
              final picked=await showDatePicker(context:c,initialDate:initial,firstDate:first,lastDate:last);
              if(picked!=null&&c.mounted)setDialogState(()=>date=picked);
            },
          ),
          TextField(controller:s,decoration:const InputDecoration(labelText:'START HH:MM')),
          TextField(controller:f,decoration:const InputDecoration(labelText:'FINAL HH:MM')),
          SwitchListTile(
            contentPadding:EdgeInsets.zero,
            title:const Text('Fațadă realizată'),
            subtitle:const Text('Confirmă numai dacă fațada a fost efectiv executată.'),
            value:facadeDone,
            onChanged:(value)=>setDialogState(()=>facadeDone=value),
          ),
        ]))),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Anulează')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvează')),
        ],
      )),
    );
    if(!mounted){s.dispose();f.dispose();return;}
    final startText=s.text;
    final finishText=f.text;
    s.dispose();
    f.dispose();
    if(result!=true)return;
    final newStart=_sameDateTime(date,startText);
    var newFinish=_sameDateTime(date,finishText);
    if(newStart==null||newFinish==null){
      showErrorMessage(context,'Completează ore valide în format HH:MM.');
      return;
    }
    if(newFinish.isBefore(newStart))newFinish=newFinish.add(const Duration(days:1));
    if(!newFinish.isAfter(newStart)){
      showErrorMessage(context,'Ora FINAL trebuie să fie după ora START. Pentru intervențiile peste miezul nopții, FINAL poate fi mai mică decât START.');
      return;
    }
    final updated=CentralizerRecord(
      id:r.id,teamId:r.teamId,locationId:r.locationId,type:r.type,
      locationNameSnapshot:r.locationNameSnapshot,addressSnapshot:r.addressSnapshot,
      waitingStartedAt:r.waitingStartedAt,waitingEndedAt:r.waitingEndedAt,
      startedAt:newStart,finishedAt:newFinish,status:r.status,
      refusalReason:r.refusalReason,keptForLearning:r.keptForLearning,
      facadePlanned:r.facadePlanned||facadeDone,facadeDone:facadeDone,
    );
    try {
      await widget.correctRecord(r, updated);
      widget.log('Intervenție corectată (dată, ore, fațadă)',r.locationNameSnapshot);
      widget.onChanged();
      if(mounted)showSuccessMessage(context,'Data, orele și fațada au fost salvate.');
    } catch(e) {
      if(mounted)showErrorMessage(context,'Nu s-a putut salva corecția: $e');
    }
  }

  DateTime? _sameDateTime(DateTime? base,String text) {
    final p=text.trim().split(':');
    if(base==null||p.length!=2)return null;
    final h=int.tryParse(p[0]),m=int.tryParse(p[1]);
    if(h==null||m==null||h<0||m<0||h>23||m>59)return null;
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

