#!/usr/bin/env python3
"""Safe, idempotent fixes applied to the original v3.0.1 ZIP at build time.

The source archive is not edited; each expected source fragment is verified
before replacement, so a future incompatible version fails rather than
silently removing unrelated features.
"""
from pathlib import Path

source = Path("lib/main.dart")
data = source.read_text(encoding="utf-8")
changes = [
    ("const String _appVersionLabel = '3.0.0+32';",
     "const String _appVersionLabel = '3.0.2+34';"),
    ("Text('Fereastră standard: ${timeText(workWindowStart(workDate))} → ${timeText(workWindowEnd(workDate))}'),",
     ""),

    ("_InfoCard(icon:Icons.info_outline,title:'Estimare traseu complet',text:", "_InfoCard(icon:Icons.info_outline,title:'Estimare geometrică (nu rutieră)',text:"),
    ("Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[",
     "Card(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:14,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.start,children:["),
    ("Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(display,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900))",
     "SizedBox(width:math.min(MediaQuery.sizeOf(context).width-80,340.0),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(display,softWrap:true,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900))"),
    ("isThreeLine: true,\n                            onTap: n.read ? null : () async {",
     "isThreeLine: true,\n                            trailing: n.read ? const Icon(Icons.check_circle_outline) : IconButton(tooltip:'Marchează ca citit',icon:const Icon(Icons.mark_email_read_outlined),onPressed:() async { try { await FirebaseFirestore.instance.collection('notifications').doc(n.id).set({'read': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); n.read = true; if (mounted) setState(() {}); } catch (e) { if (mounted) showErrorMessage(context, 'Nu s-a putut marca notificarea: $e'); } }),\n                            onTap: n.read ? null : () async {"),
    ("(inWindow ? 'Între locații' : 'Liber'), asset: 'assets/ui/tab_harta.png')",
     "(inWindow ? 'Locația echipei: consultă poziția live' : 'Liber'), asset: 'assets/ui/tab_harta.png')"),
    ("    if (isAdmin) return true;\n    final ids = me.functionIds;",
     "    if (isAdmin) return true;\n    // Membrii pot vedea directorul; permisiunile de editare rămân separate.\n    if (permission == FunctionPermission.viewMembers) return true;\n    final ids = me.functionIds;"),
    ("const Expanded(child: Text('Notificări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),\n                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Închide')),",
     "const Expanded(child: Text('Notificări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),\n                    TextButton(onPressed: () async {\n                      final unread = mine.where((n) => !n.read).toList();\n                      if (unread.isEmpty) return;\n                      try {\n                        final db = FirebaseFirestore.instance;\n                        for (var offset = 0; offset < unread.length; offset += 400) {\n                          final batch = db.batch();\n                          for (final n in unread.skip(offset).take(400)) {\n                            batch.set(db.collection('notifications').doc(n.id), {'read': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));\n                          }\n                          await batch.commit();\n                        }\n                        for (final n in unread) { n.read = true; }\n                        if (mounted) setState(() {});\n                        if (c.mounted) Navigator.pop(c);\n                      } catch (e) {\n                        if (mounted) showErrorMessage(context, 'Nu s-au putut marca notificările: $e');\n                      }\n                    }, child: const Text('Toate citite')),\n                    IconButton(tooltip: 'Închide', onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close)),"),
    ("    {'version':'3.0.0+32','title':'Finalizare v3.0.0 · mesaje automate și curățare'", "    {'version':'3.0.2+34','title':'Îmbunătățiri Android și interfață','summary':'Versiune de test: profil adaptat pentru telefon, accesul lucrătorilor la directorul de membri, marcarea notificărilor ca citite, etichete mai clare pentru distanțele geometrice și eliminarea ferestrei standard din Dashboard. Alte funcții sunt în curs de verificare.'},\n    {'version':'3.0.0+32','title':'Finalizare v3.0.0 · mesaje automate și curățare'"),
    ("const Text('Schimbare rapidă între conturi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),",
     """if(widget.user.role == UserRole.director) SwitchListTile.adaptive(
          title: const Text('Ascunde contul Admin din lista membrilor'),
          subtitle: const Text('Contul rămâne activ și poate fi afișat din nou oricând.'),
          value: d['hiddenFromMembers'] == true,
          onChanged: (value) async {
            try { await _updateOwn({'hiddenFromMembers': value}); }
            catch (e) { if (context.mounted) showErrorMessage(context, 'Nu s-a putut schimba vizibilitatea: $e'); }
          },
        ),
        const Text('Schimbare rapidă între conturi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),"""),

    ("canEditProgram: hasPermission(FunctionPermission.editProgram), userName: userName, onChanged: refresh,",
     "canEditProgram: hasPermission(FunctionPermission.editProgram), liveLocalityLabel: _lastLiveLocalityLabel, userName: userName, onChanged: refresh,"),
    ("final AppUser currentUser; final bool canEditProgram; final String Function(String) userName;",
     "final AppUser currentUser; final bool canEditProgram; final String liveLocalityLabel; final String Function(String) userName;"),
    ("required this.currentUser, required this.canEditProgram, required this.userName, required this.onChanged, required this.saveRecord,",
     "required this.currentUser, required this.canEditProgram, required this.liveLocalityLabel, required this.userName, required this.onChanged, required this.saveRecord,"),
    ("(inWindow ? 'Locația echipei: consultă poziția live' : 'Liber'), asset: 'assets/ui/tab_harta.png')",
     "(inWindow ? (widget.liveLocalityLabel.trim().isNotEmpty ? widget.liveLocalityLabel : 'Oraș/județ indisponibil') : 'Liber'), asset: 'assets/ui/tab_harta.png')"),
    ("_StatMini(label:'Km GPS (linie dreaptă)',value:'${km.toStringAsFixed(1)} km',icon:Icons.route),\n              _StatMini(label:'Consum',value:liters>0?'${liters.toStringAsFixed(1)} l':'nesetat',icon:Icons.local_gas_station),\n              _StatMini(label:'Cost carburant',value:cost>0?'${cost.toStringAsFixed(2)} lei':'nesetat',icon:Icons.payments_outlined),",
     """FutureBuilder<double?>(
                future: routeData.complete && routeData.points.length >= 2 ? _roadDistanceForGraph(graphSchedules) : Future<double?>.value(null),
                builder: (context, snapshot) {
                  final roadKm = snapshot.data;
                  final available = roadKm != null && snapshot.connectionState == ConnectionState.done;
                  final distance = roadKm ?? km;
                  final roadLiters = car != null && car.averageConsumption > 0 ? distance * car.averageConsumption / 100 : 0.0;
                  final roadCost = car != null && car.fuelPricePerLiter > 0 ? roadLiters * car.fuelPricePerLiter : 0.0;
                  return Wrap(spacing:8,runSpacing:8,children:[
                    _StatMini(label: available ? 'Km rutieri' : 'Km GPS (linie dreaptă)',value:'${distance.toStringAsFixed(1)} km',icon:Icons.route),
                    _StatMini(label: available ? 'Consum rutier estimat' : 'Consum geometric estimat',value:roadLiters>0?'${roadLiters.toStringAsFixed(1)} l':'nesetat',icon:Icons.local_gas_station),
                    _StatMini(label: available ? 'Cost rutier estimat' : 'Cost geometric estimat',value:roadCost>0?'${roadCost.toStringAsFixed(2)} lei':'nesetat',icon:Icons.payments_outlined),
                  ]);
                },
              ),"""),
    ("Expanded(child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:docs.length + (widget.chatMode ? 1 : 0),itemBuilder:(context,index){",
     "Expanded(child:docs.isEmpty && !widget.chatMode ? const Center(child:Padding(padding:EdgeInsets.all(20),child:Text('Directorul membrilor este gol. Dacă există angajați activi, administratorul trebuie să verifice sincronizarea colecției memberDirectory din Firebase.',textAlign:TextAlign.center))) : ListView.builder(padding:const EdgeInsets.all(12),itemCount:docs.length + (widget.chatMode ? 1 : 0),itemBuilder:(context,index){"),
    ("""    unawaited(_shareLiveLocationIfAllowed());
    if (kIsWeb) {
      // Browserele/PWA pot suspenda complet execuția când aplicația este închisă.
      // Cât timp pagina rulează folosim intervalul adaptiv de mai jos.
      _liveLocationTimer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_shareLiveLocationIfAllowed()));
      return;
    }
    unawaited(_startNativeBackgroundLocationStream());""",
     """    unawaited(_shareLiveLocationIfAllowed());
    // Un stream Android cu foregroundNotificationConfig produce notificare
    // permanentă. Îl activăm doar în timpul unui grafic pornit; în rest
    // păstrăm actualizările economice, fără serviciu foreground.
    _liveLocationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_shareLiveLocationIfAllowed());
      if (!kIsWeb) unawaited(_reconcileNativeLocationStream());
    });
    if (!kIsWeb) unawaited(_reconcileNativeLocationStream());"""),
    ("""  Future<void> _startNativeBackgroundLocationStream() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;""",
     """  bool _needsNativeLocationForeground() {
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final myTeam = me.teamId;
    if (myTeam == null || myTeam.isEmpty) return false;
    return schedules.any((s) =>
      s.teamId == myTeam && sameDay(s.date, workDate) &&
      s.started && !s.closed && !s.paused && !s.postponed);
  }

  Future<void> _reconcileNativeLocationStream() async {
    if (kIsWeb || !mounted) return;
    if (!_needsNativeLocationForeground()) {
      await _backgroundLocationSubscription?.cancel();
      _backgroundLocationSubscription = null;
      _nativeLocationProximityBoost = false;
      return;
    }
    if (_backgroundLocationSubscription == null) {
      await _startNativeBackgroundLocationStream();
    }
  }

  Future<void> _startNativeBackgroundLocationStream() async {
    try {
      if (!_needsNativeLocationForeground()) {
        await _backgroundLocationSubscription?.cancel();
        _backgroundLocationSubscription = null;
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;"""),
    ("""            _lastLiveLocalityLabel = label;
            _lastLiveLocalityResolvedAt = now;
            _lastLiveLocalityPosition = p;
            return label;""",
     """            final changed = _lastLiveLocalityLabel != label;
            _lastLiveLocalityLabel = label;
            _lastLiveLocalityResolvedAt = now;
            _lastLiveLocalityPosition = p;
            if (changed && mounted) setState(() {});
            return label;"""),
    ("      bottomNavigationBar: NavigationBar(\n        height: compactNav ? 66 : 72,\n        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .97),\n        indicatorColor: selectedColor.withValues(alpha: .18),\n        labelBehavior: compactNav ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,\n        selectedIndex: tab,\n        onDestinationSelected: (i) => setState(() => tab = i),\n        destinations: destinations,\n      ),",
     "      bottomNavigationBar: compactNav\n          ? SafeArea(top:false, child: Container(\n              padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),\n              decoration: BoxDecoration(\n                color: Theme.of(context).colorScheme.surface.withValues(alpha:.97),\n                border: Border(top: BorderSide(color:Theme.of(context).colorScheme.outlineVariant)),\n              ),\n              child: LayoutBuilder(builder:(context, constraints) {\n                final columns = (destinations.length / 2).ceil().clamp(1, 8);\n                final cellWidth = constraints.maxWidth / columns;\n                return Wrap(children: List.generate(destinations.length, (i) {\n                  final destination = destinations[i];\n                  final selected = tab == i;\n                  return SizedBox(width:cellWidth,height:60,child: Semantics(\n                    button:true,selected:selected,label:destination.label,\n                    child: Material(color:Colors.transparent,child:InkWell(\n                      borderRadius:BorderRadius.circular(12),\n                      onTap:()=>setState(()=>tab=i),\n                      child: Container(\n                        margin:const EdgeInsets.symmetric(horizontal:2,vertical:2),\n                        decoration:BoxDecoration(\n                          color:selected ? tabColors[i].withValues(alpha:.15) : null,\n                          borderRadius:BorderRadius.circular(12),\n                        ),\n                        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[\n                          SizedBox(height:28,child:Center(child:selected ? (destination.selectedIcon ?? destination.icon) : destination.icon)),\n                          const SizedBox(height:2),\n                          Text(destination.label,maxLines:1,overflow:TextOverflow.ellipsis,\n                            textAlign:TextAlign.center,\n                            style:TextStyle(fontSize:11,fontWeight:selected?FontWeight.w800:FontWeight.w600)),\n                        ]),\n                      ),\n                    )),\n                  ));\n                }));\n              }),\n            ))\n          : NavigationBar(\n              height:72,\n              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha:.97),\n              indicatorColor: selectedColor.withValues(alpha:.18),\n              labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,\n              selectedIndex:tab,\n              onDestinationSelected:(i)=>setState(()=>tab=i),\n              destinations:destinations,\n            ),"),
    ("  bool _nativeLocationProximityBoost = false;",
     "  bool _nativeLocationProximityBoost = false;\n  bool _sideMessagingOpen = false;"),
    ("    addPage(hasPermission(FunctionPermission.viewContacts),\n      MessagesContactsPage(",
     "    addPage(!compactNav && hasPermission(FunctionPermission.viewContacts),\n      MessagesContactsPage("),
    ("const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: settingsColor), label: 'Setări')",
     "const NavigationDestination(icon: Icon(Icons.tune_rounded), selectedIcon: Icon(Icons.display_settings_rounded, color: settingsColor), label: 'Setări')"),
    ("          Container(\n            width: double.infinity,\n            padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),\n            decoration: BoxDecoration(\n              color: Theme.of(context).colorScheme.surface.withValues(alpha: .90),\n              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),\n            ),\n            child: Row(children: [\n              SizedBox(width:compactNav?104:150,height:38,child:appBrandLogo(settings,width:150,height:38)),\n              const SizedBox(width:6),\n              compactNav\n                ? IconButton(tooltip:'Despre',onPressed:_openAbout,icon:const Icon(Icons.info_outline))\n                : TextButton.icon(onPressed:_openAbout,icon:const Icon(Icons.info_outline),label:const Text('Despre')),\n              const Spacer(),\n              Badge(\n                isLabelVisible:myUnreadNotifications>0,\n                label:Text(myUnreadNotifications>99?'99+':'$myUnreadNotifications'),\n                child: IconButton(\n                  tooltip:'Notificări',\n                  onPressed:_openNotificationsSheet,\n                  icon:const Icon(Icons.notifications_outlined),\n                ),\n              ),\n              const SizedBox(width:6),\n              InkWell(\n                borderRadius: BorderRadius.circular(30),\n                onTap: _openProfile,\n                child: Padding(\n                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),\n                  child: Row(mainAxisSize: MainAxisSize.min, children: [\n                    CircleAvatar(radius: compactNav ? 16 : 17, backgroundImage: myPhoto == null ? null : MemoryImage(myPhoto), child: myPhoto == null ? const Icon(Icons.person, size: 18) : null),\n                    if(!compactNav)...[const SizedBox(width:8), const Text('Profil', style: TextStyle(fontWeight: FontWeight.w700))],\n                  ]),\n                ),\n              ),\n              const SizedBox(width:6),\n              if(compactNav)...[\n                if (hasPermission(FunctionPermission.viewMembers)) IconButton(tooltip:'Membrii',onPressed:()=>_openMembersDirectory(),icon:sectionAssetWidget('Membri', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.people_outline)),\n                Badge(isLabelVisible:_unreadMessageCount>0,label:Text(_unreadMessageCount>99?'99+':'$_unreadMessageCount'),child:IconButton(tooltip:'Chat live',onPressed:_openGroupChat,icon:sectionAssetWidget('Chat live', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.forum_outlined))),\n              ]else...[\n                if (hasPermission(FunctionPermission.viewMembers)) FilledButton.tonalIcon(onPressed:()=>_openMembersDirectory(),icon:sectionAssetWidget('Membri', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.people_outline),label:const Text('Membrii')),\n                const SizedBox(width:8),\n                Badge(isLabelVisible:_unreadMessageCount>0,label:Text(_unreadMessageCount>99?'99+':'$_unreadMessageCount'),child:FilledButton.tonalIcon(onPressed:_openGroupChat,icon:sectionAssetWidget('Chat live', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.forum_outlined),label:const Text('Chat live'))),\n              ],\n            ]),\n          ),\n",
     "          Container(\n            width:double.infinity,\n            padding:const EdgeInsets.symmetric(horizontal:14,vertical:7),\n            decoration:BoxDecoration(\n              color:Theme.of(context).colorScheme.surface.withValues(alpha:.93),\n              border:Border(bottom:BorderSide(color:Theme.of(context).colorScheme.outlineVariant)),\n            ),\n            child:Row(children:[\n              InkWell(\n                borderRadius:BorderRadius.circular(28),\n                onTap:_openProfile,\n                child:Padding(padding:const EdgeInsets.symmetric(vertical:3,horizontal:4),\n                  child:Row(children:[\n                    CircleAvatar(radius:20,backgroundImage:myPhoto==null?null:MemoryImage(myPhoto),\n                      child:myPhoto==null?const Icon(Icons.person_outline):null),\n                    const SizedBox(width:10),\n                    ConstrainedBox(constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width-115),\n                      child:Text(me.name,maxLines:1,overflow:TextOverflow.ellipsis,\n                        style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))),\n                  ]),\n                ),\n              ),\n              const Spacer(),\n              if(!compactNav) IconButton(tooltip:'Despre aplicație',onPressed:_openAbout,icon:const Icon(Icons.info_outline)),\n            ]),\n          ),\n"),
    ("      body: _AppBackdrop(\n        settings: settings,\n        child: SafeArea(child: Column(children: [",
     "      body: Stack(children:[\n        _AppBackdrop(\n        settings: settings,\n        child: SafeArea(child: Column(children: ["),
    ("          Expanded(child: pages[tab]),\n        ])),\n      ),\n      bottomNavigationBar:",
     "          Expanded(child: pages[tab]),\n        ])),\n      ),\n      if(compactNav)...[\n        if(_sideMessagingOpen)\n          Positioned.fill(child:GestureDetector(\n            behavior:HitTestBehavior.opaque,\n            onTap:()=>setState(()=>_sideMessagingOpen=false),\n            onHorizontalDragEnd:(details){\n              if((details.primaryVelocity??0)>180) setState(()=>_sideMessagingOpen=false);\n            },\n            child:const ColoredBox(color:Colors.black38))),\n        Positioned(\n          right:0,top:0,bottom:0,\n          child:SafeArea(child:Align(alignment:Alignment.centerRight,child:\n            AnimatedContainer(\n              duration:const Duration(milliseconds:220),\n              curve:Curves.easeOutCubic,\n              width:_sideMessagingOpen?math.min(MediaQuery.sizeOf(context).width-28,295.0):52,\n              child:_sideMessagingOpen\n                ? Material(elevation:12,borderRadius:const BorderRadius.horizontal(left:Radius.circular(20)),\n                    color:Theme.of(context).colorScheme.surface,\n                    child:GestureDetector(\n                      onHorizontalDragEnd:(details){\n                        if((details.primaryVelocity??0)>180) setState(()=>_sideMessagingOpen=false);\n                      },\n                      child:Padding(padding:const EdgeInsets.fromLTRB(12,12,12,16),child:Column(\n                        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[\n                          Row(children:[\n                            const Icon(Icons.forum_rounded),\n                            const SizedBox(width:8),\n                            const Expanded(child:Text('Comunicare',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800))),\n                            IconButton(tooltip:'Notificări',onPressed:(){\n                              setState(()=>_sideMessagingOpen=false);\n                              _openNotificationsSheet();\n                            },icon:Badge(isLabelVisible:myUnreadNotifications>0,\n                              child:const Icon(Icons.notifications_outlined))),\n                            IconButton(tooltip:'Închide',onPressed:()=>setState(()=>_sideMessagingOpen=false),\n                              icon:const Icon(Icons.close_rounded,color:Colors.red)),\n                          ]),\n                          const Divider(),\n                          if(hasPermission(FunctionPermission.viewContacts))\n                            ListTile(leading:const Icon(Icons.mail_outline_rounded),\n                              title:const Text('Mesagerie'),\n                              subtitle:const Text('Contacte și mesaje către locații'),\n                              onTap:(){\n                                setState(()=>_sideMessagingOpen=false);\n                                Navigator.of(context).push(MaterialPageRoute(builder:(_)=>Scaffold(\n                                  appBar:AppBar(title:const Text('Mesagerie')),\n                                  body:MessagesContactsPage(locations:locations,settings:settings,\n                                    canEditContacts:hasPermission(FunctionPermission.editContacts),\n                                    canManageTemplates:hasPermission(FunctionPermission.manageMessageTemplates),\n                                    onChanged:refresh,log:log))));\n                              }),\n                          ListTile(leading:Badge(isLabelVisible:_unreadMessageCount>0,\n                              child:const Icon(Icons.forum_outlined)),\n                            title:const Text('Chat live'),\n                            subtitle:const Text('Conversații cu echipa'),\n                            onTap:(){\n                              setState(()=>_sideMessagingOpen=false);\n                              _openGroupChat();\n                            }),\n                          if(hasPermission(FunctionPermission.viewMembers))\n                            ListTile(leading:const Icon(Icons.people_outline_rounded),\n                              title:const Text('Membrii echipei'),\n                              onTap:(){\n                                setState(()=>_sideMessagingOpen=false);\n                                _openMembersDirectory();\n                              }),\n                        ]),\n                      ),\n                    ))\n                : Align(alignment:Alignment.centerRight,child:Material(\n                    elevation:6,color:Theme.of(context).colorScheme.primaryContainer,\n                    borderRadius:const BorderRadius.horizontal(left:Radius.circular(16)),\n                    child:InkWell(\n                      borderRadius:const BorderRadius.horizontal(left:Radius.circular(16)),\n                      onTap:()=>setState(()=>_sideMessagingOpen=true),\n                      child:GestureDetector(\n                        behavior:HitTestBehavior.translucent,\n                        onHorizontalDragEnd:(details){\n                          if((details.primaryVelocity??0)<-100) setState(()=>_sideMessagingOpen=true);\n                        },\n                        child:Padding(padding:const EdgeInsets.symmetric(vertical:18,horizontal:12),\n                          child:Badge(isLabelVisible:_unreadMessageCount>0,\n                            child:const Icon(Icons.forum_rounded,size:26))),\n                      ),\n                    ),\n                  )),\n            ),\n          )),\n        ),\n      ],\n      ]),\n      bottomNavigationBar:"),
]
for before, after in changes:
    count = data.count(before)
    if count != 1:
        raise SystemExit(f"Expected exactly one occurrence ({count}): {before[:90]}")
    data = data.replace(before, after, 1)
source.write_text(data, encoding="utf-8")

pubspec = Path("pubspec.yaml")
text = pubspec.read_text(encoding="utf-8")
if "version: 3.0.1+33" not in text:
    raise SystemExit("Unexpected pubspec version; manual review required")
pubspec.write_text(text.replace("version: 3.0.1+33", "version: 3.0.2+34", 1), encoding="utf-8")
print("Applied verified UI and version fixes")
