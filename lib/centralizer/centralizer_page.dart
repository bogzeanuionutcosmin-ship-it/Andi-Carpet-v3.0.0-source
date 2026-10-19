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

class _ManualExecutionDraft {
  final Location? location;
  final String teamId;
  final DateTime date;
  final String startTime;
  final String finishTime;
  final String note;
  final bool facadeDone;
  const _ManualExecutionDraft({required this.location, required this.teamId, required this.date, required this.startTime, required this.finishTime, required this.note, required this.facadeDone});
}

class _ManualExecutionDialog extends StatefulWidget {
  final String title;
  final List<Location> locations;
  final List<Team> allowedTeams;
  final LocationType type;
  final Location? initialLocation;
  const _ManualExecutionDialog({required this.title, required this.locations, required this.allowedTeams, required this.type, required this.initialLocation});
  @override State<_ManualExecutionDialog> createState() => _ManualExecutionDialogState();
}

class _ManualExecutionDialogState extends State<_ManualExecutionDialog> {
  late final TextEditingController _start;
  late final TextEditingController _finish;
  late final TextEditingController _note;
  late Location? _selectedLocation = widget.initialLocation;
  late String _selectedTeamId = widget.allowedTeams.first.id;
  late DateTime _date = DateTime.now();
  bool _facadeDone = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(hours: 1));
    _start = TextEditingController(text: '${two(earlier.hour)}:${two(earlier.minute)}');
    _finish = TextEditingController(text: '${two(now.hour)}:${two(now.minute)}');
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _start.dispose();
    _finish.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.locations.where((location) => location.type == widget.type).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedLocation?.id,
              decoration: const InputDecoration(labelText: 'Locație'),
              items: choices.map((location) => DropdownMenuItem(value: location.id, child: Text(location.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: widget.initialLocation != null ? null : (value) => setState(() => _selectedLocation = value == null ? null : choices.firstWhere((location) => location.id == value)),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedTeamId,
              decoration: const InputDecoration(labelText: 'Echipă'),
              items: widget.allowedTeams.map((team) => DropdownMenuItem(value: team.id, child: Text(team.name))).toList(),
              onChanged: (value) { if (value != null) setState(() => _selectedTeamId = value); },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero, title: const Text('Data execuției'),
              subtitle: Text(formatDate(_date)), trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)), initialDate: _date);
                if (date != null && mounted) setState(() => _date = date);
              },
            ),
            Row(children: [
              Expanded(child: TextField(controller: _start, decoration: const InputDecoration(labelText: 'START HH:MM'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _finish, decoration: const InputDecoration(labelText: 'FINAL HH:MM'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Observație (opțional)', hintText: 'Ex.: a doua spălare / sală preluată de la altă echipă')),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, value: _facadeDone,
              title: const Text('Fațadă realizată'),
              subtitle: const Text('Bifează numai dacă fațada a fost făcută efectiv la această intervenție.'),
              onChanged: (value) => setState(() => _facadeDone = value),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează')),
        FilledButton.icon(
          onPressed: _selectedLocation == null ? null : () => Navigator.pop(context, _ManualExecutionDraft(
            location: _selectedLocation, teamId: _selectedTeamId, date: _date,
            startTime: _start.text, finishTime: _finish.text, note: _note.text, facadeDone: _facadeDone,
          )),
          icon: const Icon(Icons.save), label: const Text('Adaugă'),
        ),
      ],
    );
  }
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
    final finish=toDate==null?null:DateTime(toDate!.year,toDate!.month,toDate!.day+1);
    return widget.records.where((r){
      if(r.type!=type)return false;
      if(teamFilter!=null&&r.teamId!=teamFilter)return false;
      if(statusFilter!=null&&r.status!=statusFilter)return false;
      final when=recordEventTime(r);
      if(start!=null&&when.isBefore(start))return false;
      if(finish!=null&&!when.isBefore(finish))return false;
      if(q.isNotEmpty&&!r.locationNameSnapshot.toLowerCase().contains(q)&&!r.addressSnapshot.toLowerCase().contains(q))return false;
      return true;
    }).toList();
  }

  List<WorkSchedule> _scheduledWithoutExecutionForLocation(String locationId){
    if(statusFilter!=null)return <WorkSchedule>[];
    final q=searchController.text.trim().toLowerCase();
    final start=fromDate==null?null:DateTime(fromDate!.year,fromDate!.month,fromDate!.day);
    final finish=toDate==null?null:DateTime(toDate!.year,toDate!.month,toDate!.day+1);
    final out=<WorkSchedule>[];
    for(final schedule in widget.schedules){
      if(teamFilter!=null&&schedule.teamId!=teamFilter)continue;
      if(start!=null&&schedule.date.isBefore(start))continue;
      if(finish!=null&&!schedule.date.isBefore(finish))continue;
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
    final locationsById=<String,Location>{for(final location in widget.locations)location.id:location};
    // Execution snapshots remain visible after a registry location is removed.
    // These inactive display-only locations never re-create registry documents.
    for(final record in filtered){
      locationsById.putIfAbsent(record.locationId,()=>Location(
        id:record.locationId,name:record.locationNameSnapshot,address:record.addressSnapshot,
        type:record.type,active:false,
      ));
    }
    final locs=locationsById.values.where((l)=>l.type==type&&ids.contains(l.id)).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
          SizedBox(width:220,child:DropdownButtonFormField<String?>(isExpanded:true,value:teamFilter,decoration:const InputDecoration(labelText:'Echipă'),items:[const DropdownMenuItem<String?>(value:null,child:Text('Toate echipele')),...widget.teams.map((t)=>DropdownMenuItem<String?>(value:t.id,child:Text(t.name)))],onChanged:(v)=>setState(()=>teamFilter=v))),
          SizedBox(width:220,child:DropdownButtonFormField<WorkAttemptStatus?>(isExpanded:true,value:statusFilter,decoration:const InputDecoration(labelText:'Stare'),items:[const DropdownMenuItem<WorkAttemptStatus?>(value:null,child:Text('Toate stările')),const DropdownMenuItem(value:WorkAttemptStatus.completed,child:Text('Finalizată')),const DropdownMenuItem(value:WorkAttemptStatus.running,child:Text('În lucru')),const DropdownMenuItem(value:WorkAttemptStatus.waitingAccess,child:Text('Așteptare acces')),const DropdownMenuItem(value:WorkAttemptStatus.refused,child:Text('Refuzată')),const DropdownMenuItem(value:WorkAttemptStatus.notCompleted,child:Text('Nerealizată'))],onChanged:(v)=>setState(()=>statusFilter=v))),
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
      trailing:l.active&&(widget.isAdmin || widget.canEditCentralizer)?IconButton(tooltip:'Adaugă încă o execuție',onPressed:()=>_addManualExecution(location:l),icon:const Icon(Icons.add_circle_outline)):null,
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
  bool _addingManualExecution = false;

  Future<void> _addManualExecution({Location? location}) async {
    if (_addingManualExecution || !mounted) return;
    _addingManualExecution = true;
    try {
      await _showManualExecution(location: location);
    } finally {
      _addingManualExecution = false;
    }
  }

  Future<void> _showManualExecution({Location? location}) async {
    final allowedTeams = widget.isAdmin
        ? widget.teams
        : widget.teams.where((team) => widget.canEditTeam(team.id)).toList();
    if (allowedTeams.isEmpty) {
      if (mounted) showErrorMessage(context, 'Nu ai o echipă în care poți adăuga execuții.');
      return;
    }
    final draft = await showDialog<_ManualExecutionDraft>(
      context: context,
      builder: (_) => _ManualExecutionDialog(
        title: location == null ? 'Adaugă execuție în Centralizator' : 'Adaugă încă o execuție',
        locations: widget.locations,
        allowedTeams: allowedTeams,
        type: type,
        initialLocation: location,
      ),
    );
    if (draft == null || draft.location == null) return;

    final base = DateTime(draft.date.year, draft.date.month, draft.date.day);
    DateTime? parse(String raw) {
      final parts = raw.trim().split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return DateTime(base.year, base.month, base.day, hour, minute);
    }
    final start = parse(draft.startTime);
    var finish = parse(draft.finishTime);
    if (start == null || finish == null) {
      if (mounted) showErrorMessage(context, 'Orele trebuie scrise HH:MM.');
      return;
    }
    if (finish.isBefore(start)) finish = finish.add(const Duration(days: 1));
    if (!finish.isAfter(start)) {
      if (mounted) showErrorMessage(context, 'Ora FINAL trebuie să fie după ora START.');
      return;
    }

    final note = draft.note.trim();
    final selectedLocation = draft.location!;
    final existing = widget.records.where((record) =>
      record.locationId == selectedLocation.id &&
      record.teamId == draft.teamId &&
      record.status == WorkAttemptStatus.completed &&
      record.startedAt != null &&
      sameDay(record.startedAt!, start)
    ).toList();
    if (existing.isNotEmpty) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Execuție deja înregistrată'),
          content: Text('Există deja ${existing.length} execuție/execuții finalizate pentru această sală, echipă și dată. Dacă vrei să corectezi data sau orele, folosește butonul de editare al intervenției existente. Adaugi totuși o execuție distinctă?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Anulează')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Execuție distinctă')),
          ],
        ),
      ) ?? false;
      if (!confirmed) return;
    }

    final record = CentralizerRecord(
      id: idNow(), teamId: draft.teamId, locationId: selectedLocation.id,
      type: selectedLocation.type, locationNameSnapshot: selectedLocation.name,
      addressSnapshot: selectedLocation.address, startedAt: start, finishedAt: finish,
      status: WorkAttemptStatus.completed, refusalReason: note.isEmpty ? null : note,
      keptForLearning: true, facadePlanned: draft.facadeDone, facadeDone: draft.facadeDone,
    );
    try {
      await widget.saveRecord(record);
      widget.log('Execuție manuală adăugată', selectedLocation.name);
      if (mounted) showSuccessMessage(context, 'Execuția a fost adăugată în Centralizator.');
    } catch (error) {
      if (mounted) showErrorMessage(context, 'Nu s-a putut salva execuția: $error');
    }
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
