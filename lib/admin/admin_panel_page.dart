part of '../main.dart';

class AdminPanelPage extends StatefulWidget {
  final List<AppUser> users; final List<Team> teams; final List<Car> cars; final List<Location> locations; final List<LocationCategory> categories; final List<FunctionDefinition> functionDefinitions; final List<WorkSchedule> schedules; final List<CentralizerRecord> records; final List<Expense> expenses; final List<PerDiemEntry> perDiems; final List<TeamFinance> finances; final List<TravelSettlement> settlements; final List<AppNotification> notifications; final List<AuditEntry> audit; final AppSettings settings; final String Function(String) userName; final VoidCallback onChanged; final void Function(String,String) log; final Future<void> Function(Location) saveLocation; final Future<void> Function(String) deleteLocation;
  const AdminPanelPage({super.key,required this.users,required this.teams,required this.cars,required this.locations,required this.categories,required this.functionDefinitions,required this.schedules,required this.records,required this.expenses,required this.perDiems,required this.finances,required this.settlements,required this.notifications,required this.audit,required this.settings,required this.userName,required this.onChanged,required this.log,required this.saveLocation,required this.deleteLocation});
  @override State<AdminPanelPage> createState()=>_AdminPanelPageState();
}
class _AdminPanelPageState extends State<AdminPanelPage> with _AdminBackupActions, _AdminTeamActions, _AdminMemberActions, _AdminCarActions, _AdminLocationActions, _AdminOperationsActions, _AdminLearningActions {
  List<AppUser> get users => widget.users; List<Team> get teams => widget.teams; List<Car> get cars => widget.cars; List<Location> get locations => widget.locations; List<LocationCategory> get categories => widget.categories; List<FunctionDefinition> get functionDefinitions => widget.functionDefinitions; List<WorkSchedule> get schedules => widget.schedules; List<CentralizerRecord> get records => widget.records; List<Expense> get expenses => widget.expenses; List<PerDiemEntry> get perDiems => widget.perDiems; List<TeamFinance> get finances => widget.finances; List<TravelSettlement> get settlements => widget.settlements; List<AppNotification> get notifications => widget.notifications; List<AuditEntry> get audit => widget.audit; AppSettings get settings => widget.settings;
  int section = 0;
  final names = const [
    'Dashboard','Echipe','Membri / Conturi','Mașini','Locații','Categorii locații','Grafice de lucru','Centralizator','Decont & Financiar','Learning Center','Learning OCR','Notificări','Rapoarte','Istoric / Audit','Funcții & Drepturi','Setări sistem','Backup & Recuperare'
  ];

  Widget _adminLeading(int i, Color accent) {
    final asset = _adminSectionAsset(i);
    return asset == null ? Icon(_adminSectionIcon(i)) : appAssetIcon(asset, size: 22, accent: accent, selected: section == i);
  }

  Widget _adminMenu({required bool closeDrawer}) {
    final widgets = <Widget>[];
    String? previousGroup;
    for (var i = 0; i < names.length; i++) {
      final group = _adminSectionGroup(i);
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
          avatar: Icon(_adminSectionIcon(i), size:18),
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
