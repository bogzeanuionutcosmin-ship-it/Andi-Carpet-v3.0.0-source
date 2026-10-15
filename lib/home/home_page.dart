part of '../main.dart';

class HomePage extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final FirebaseUserProfile profile;
  final HomeDefinitionSources? definitionSources;
  final FirebaseFirestore? syncFirestore;
  final FirebaseFirestore? maintenanceFirestore;
  final FirebaseFirestore? pushFirestore;
  final HomePlatformEffects? platformEffects;
  final HomeMessageQueries? messageQueries;
  final HomeIdentityQueries? identityQueries;
  final HomeOperationalQueries? operationalQueries;
  final HomeSystemQueries? systemQueries;
  final bool Function()? sessionIsCurrent;
  final FirebaseMessaging? messaging;
  final Stream<RemoteMessage>? messageOpenedApp;
  final void Function()? startLocation;
  final Future<void> Function()? initializePush;
  const HomePage({super.key, required this.settings, required this.onSettingsChanged, required this.profile, this.definitionSources, this.syncFirestore, this.maintenanceFirestore, this.pushFirestore, this.platformEffects, this.messageQueries, this.identityQueries, this.operationalQueries, this.systemQueries, this.sessionIsCurrent, this.messaging, this.messageOpenedApp, this.startLocation, this.initializePush});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with _HomeBackupMaintenance, _HomePermissionMaintenance, _HomeDocumentCodecs {
  int tab = 0;
  late final String currentUserId;
  AppSettings get settings => widget.settings;
  bool get _sessionActive => mounted && (widget.sessionIsCurrent?.call() ?? true);

  void _scheduleSettingsChanged() {
    if (!_sessionActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sessionActive) widget.onSettingsChanged();
    });
  }
  FirebaseFirestore get _syncDb => widget.syncFirestore ?? FirebaseFirestore.instance;
  FirebaseFirestore get _maintenanceDb => widget.maintenanceFirestore ?? FirebaseFirestore.instance;
  FirebaseFirestore get _pushDb => widget.pushFirestore ?? FirebaseFirestore.instance;
  late final List<AppUser> users;
  late final List<Team> teams;
  late final List<Car> cars;
  late final List<Location> locations;

  List<Location> _seedLocations() =>
      operational_location_seed.seedOperationalLocations();
  final categories = <LocationCategory>[];
  final functionDefinitions = <FunctionDefinition>[];
  final schedules = <WorkSchedule>[];
  final records = <CentralizerRecord>[];
  final expenses = <Expense>[];
  final perDiems = <PerDiemEntry>[];
  final finances = <TeamFinance>[];
  final settlements = <TravelSettlement>[];
  final notifications = <AppNotification>[];
  final audit = <AuditEntry>[];
  final Set<String> _hiddenUserIds = <String>{};
  Timer? _liveLocationTimer;
  StreamSubscription<Position>? _backgroundLocationSubscription;
  Position? _lastSharedPosition;
  DateTime? _lastSharedAt;
  String _personalLocationMode = 'economic';
  int _personalLocationIntervalMinutes = 10;
  final Map<String,bool> _personalNotificationPreferences=<String,bool>{
    'chat':true,'schedule':true,'arrival':true,'decont':true,'learning':true,'general':true,
  };
  bool _offlineLocationCleared = false;
  bool _permissionSyncInFlight = false;
  bool _automaticBackupInFlight = false;
  final Map<String, DateTime> _autoInsideSince = <String, DateTime>{};
  final Map<String, DateTime> _autoOutsideSince = <String, DateTime>{};
  final Map<String, DateTime> _arrivalSnoozedUntil = <String, DateTime>{};
  final Map<String, int> _arrivalPromptCounts = <String, int>{};
  final Set<String> _automationNotified = <String>{};
  bool _arrivalDialogOpen = false;
  bool _nativeLocationProximityBoost = false;
  final Set<String> _knownNotificationIds = <String>{};
  final Set<String> _knownIncomingMessageIds = <String>{};
  final Set<String> _knownGroupMessageIds = <String>{};
  bool _notificationsPrimed = false;
  bool _messagesPrimed = false;
  bool _groupMessagesPrimed = false;
  int _unreadPrivateMessageCount = 0;
  int _unreadGroupMessageCount = 0;
  int _unreadMessageCount = 0;
  DateTime? _lastGroupChatSeenAt;
  List<QueryDocumentSnapshot<Map<String,dynamic>>> _recentGroupDocs = <QueryDocumentSnapshot<Map<String,dynamic>>>[];
  bool _pushInitializationInFlight = false;
  bool _pushListenersAttached = false;
  bool _pushPermissionDialogShown = false;
  String _lastLiveLocalityLabel = '';
  DateTime? _lastLiveLocalityResolvedAt;
  Position? _lastLiveLocalityPosition;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.profile.uid;
    final current = AppUser(
      id: widget.profile.uid,
      name: widget.profile.name,
      role: widget.profile.isAdmin ? UserRole.director : UserRole.member,
      function: widget.profile.function,
      functionIds: widget.profile.functionIds,
      teamId: null,
      email: widget.profile.email,
      active: widget.profile.active,
      photoBase64: '',
    );
    users = [current];
    teams = [];
    cars = [];
    locations = _seedLocations();
    categories.addAll(defaultLocationCategories());
    functionDefinitions.addAll(defaultFunctionDefinitions());
    _startCoreSync();
    (widget.platformEffects?.startLocation ?? widget.startLocation ?? _startAdaptiveLiveLocation)();
    unawaited((widget.platformEffects?.initializePush ?? widget.initializePush ?? _initPushNotifications)());
  }

  final List<StreamSubscription<dynamic>> _coreSubscriptions = [];
  final List<StreamSubscription<dynamic>> _financialSubscriptions = [];
  String? _financialTeamScope;
  final Map<String, String> _locationCache = {};
  final Map<String, String> _categoryCache = {};
  final Map<String, String> _functionCache = {};
  final Map<String, String> _teamCache = {};
  final Map<String, String> _carCache = {};
  final Map<String, String> _scheduleCache = {};
  final Map<String, String> _recordCache = {};
  final Map<String, String> _expenseCache = {};
  final Map<String, String> _perDiemCache = {};
  final Map<String, String> _financeCache = {};
  final Map<String, String?> _userTeamCache = {};
  String? coreSyncError;

  void _applyTeamMembership() {
    for (final u in users) {
      String? found;
      for (final t in teams) {
        if (t.members.contains(u.id)) {
          found = t.id;
          break;
        }
      }
      u.teamId = found;
    }
  }

  Future<void> _runAutomaticMaintenance() async {
    if (!isAdmin || _automaticBackupInFlight) return;
    _automaticBackupInFlight = true;
    try {
      await _pruneOldNotifications();
      await _pruneAutomaticBackups();
      if (!settings.automaticBackup) return;
      final db = _maintenanceDb;
      final stateRef = db.collection('meta').doc('backupAutomation');
      final state = await stateRef.get();
      final lastRaw = state.data()?['lastRunAt'];
      final last = lastRaw is Timestamp ? lastRaw.toDate() : null;
      if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) return;
      await _createAutomaticBackup();
      await stateRef.set({
        'lastRunAt': FieldValue.serverTimestamp(),
        'lastRunBy': currentUserId,
        'retentionDays': settings.backupRetentionDays,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[home] maintenance_failed');
    } finally {
      _automaticBackupInFlight = false;
    }
  }

  void _startCoreSync() {
    if (!_sessionActive) return;
    final db = _syncDb;

    _startDefinitionsSync(db);

    _startDirectorySync(db);

    _startOwnProfileSync(db);
    _startOperationsSync(db);
    _startNotificationSync(db);
    _startChatSync(db);
    _startSettingsSync(db);

    if (isAdmin) {
      _startAuditSync(db);
      unawaited(_seedLocationsIfNeeded());
      unawaited(_seedDefinitionsIfNeeded());
      unawaited(_migrateFunctionBadgeSystemIfNeeded());
    }
    _startFinancialSync();
  }

  Future<void> _writeLearningEvent({
    required String category,
    required String event,
    String teamId = '',
    String locationId = '',
    String scheduleId = '',
    Map<String, dynamic>? data,
  }) async {
    final cfg = settings.learning[category];
    if (cfg?.enabled == false) return;
    try {
      final id = idNow();
      await FirebaseFirestore.instance.collection('learningEvents').doc(id).set({
        'actorUid': currentUserId,
        'actor': me.name,
        'category': category,
        'event': event,
        'teamId': teamId,
        'locationId': locationId,
        'scheduleId': scheduleId,
        'mode': cfg?.mode.name ?? LearningMode.manualApproval.name,
        'data': data ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[learning] save_event_failed');
    }
  }

  @override
  void dispose() {
    for (final sub in _coreSubscriptions) { sub.cancel(); }
    for (final sub in _financialSubscriptions) { sub.cancel(); }
    _liveLocationTimer?.cancel();
    _backgroundLocationSubscription?.cancel();
    super.dispose();
  }


  AppUser get me => users.firstWhere(
        (u) => u.id == currentUserId,
        orElse: () => AppUser(
          id: widget.profile.uid,
          name: widget.profile.name,
          role: widget.profile.isAdmin ? UserRole.director : UserRole.member,
          function: widget.profile.function,
          functionIds: widget.profile.functionIds,
          email: widget.profile.email,
          active: widget.profile.active,
        ),
      );
  bool get isAdmin => widget.profile.isAdmin;
  bool canEditTeam(String id) {
    if (isAdmin) return true;
    final matches = teams.where((t) => t.id == id);
    return matches.isNotEmpty && matches.first.members.contains(currentUserId);
  }
  String userName(String id) {
    if (!isAdmin && _hiddenUserIds.contains(id)) return 'Sistem';
    return users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: id, name: 'Membru', role: UserRole.member)).name;
  }
  void log(String action, String target) { if (_sessionActive) unawaited(_writeAuditRemote(action, target)); }
  String _notificationCategory(String title,String message){
    final t='$title $message'.toLowerCase();
    if(t.contains('diurn')||t.contains('decont')||t.contains('cheltu'))return 'decont';
    if(t.contains('sosir')||t.contains('locați')||t.contains('locati')||t.contains('gps'))return 'arrival';
    if(t.contains('learning')||t.contains('estim')||t.contains('recomand'))return 'learning';
    if(t.contains('grafic')||t.contains('program')||t.contains('traseu')||t.contains('plan'))return 'schedule';
    return 'general';
  }
  bool _allowPersonalAlert(String title,String message){
    if(title.trim().toLowerCase()=='sistem'||title.trim().toLowerCase().contains('admin'))return true;
    return _personalNotificationPreferences[_notificationCategory(title,message)]??true;
  }
  void notifyUser(String uid, String title, String msg) {
    if (!_sessionActive) return;
    if (!settings.pushNotifications) return;
    final n = AppNotification(id: idNow(), userId: uid, title: title, message: msg, createdAt: DateTime.now());
    if (_sessionActive && (isAdmin || uid == currentUserId)) setState(() => notifications.insert(0, n));
    unawaited(FirebaseFirestore.instance.collection('notifications').doc(n.id).set(_notificationMap(n)).catchError((Object e) {
      if (_sessionActive) setState(() => coreSyncError = 'Notificare: $e');
    }));
  }
  void notifyTeam(String teamId, String title, String msg) {
    if (!_sessionActive) return;
    final matches = teams.where((t) => t.id == teamId);
    if (matches.isEmpty) return;
    for (final uid in matches.first.members) {
      notifyUser(uid, title, msg);
    }
  }
  void refresh() {
    if (!_sessionActive) return;
    // Refresh-urile operaționale nu trebuie să reconstruiască MaterialApp/AuthGate.
    // Tema este propagată separat doar când se schimbă efectiv în Firestore.
    setState(() {});
    if (isAdmin) {
      unawaited(_persistCoreData().catchError((Object e) {
        if (!_sessionActive) return;
        setState(() => coreSyncError = 'Salvare Firestore: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Salvarea nu a reușit: $e')));
      }));
    }
  }

  bool hasPermission(FunctionPermission permission) {
    if (isAdmin) return true;
    final ids = me.functionIds;
    if (ids.isEmpty) return false;
    for (final id in ids) {
      final def = functionById(functionDefinitions, id);
      if (def != null && def.active && def.permissions.contains(permission.name)) return true;
    }
    // Compatibilitate pentru conturile vechi până când colecția functions este populată.
    if (ids.contains(me.function.name)) {
      final fallback = settings.functionPermissions[me.function];
      return fallback?.contains(permission) ?? false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final compactNav = MediaQuery.sizeOf(context).width < 650;
    final myPhoto = decodeProfilePhoto(me.photoBase64);
    final myUnreadNotifications = notifications.where((n) => n.userId == currentUserId && !n.read).length;
    final pages = <Widget>[];
    final destinations = <NavigationDestination>[];
    final tabColors = <Color>[];

    void addPage(bool allowed, Widget page, NavigationDestination destination, Color color) {
      if (!allowed) return;
      pages.add(page);
      destinations.add(destination);
      tabColors.add(color);
    }

    const homeColor = Color(0xff2F6BFF);
    const programColor = Color(0xff7C4DFF);
    const mapColor = Color(0xff00A884);
    const centralizerColor = Color(0xffFF8A00);
    const decontColor = Color(0xff00A86B);
    const messagesColor = Color(0xff0F9D58);
    const docsColor = Color(0xff536DFE);
    const settingsColor = Color(0xff607D8B);

    addPage(hasPermission(FunctionPermission.viewDashboard),
      DashboardPage(teams: teams, users: users, functionDefinitions: functionDefinitions, locations: locations, categories: categories, schedules: schedules, records: records, settings: settings, currentUser: me, canEditProgram: hasPermission(FunctionPermission.editProgram), userName: userName, onChanged: refresh, saveRecord: _saveRecordDirect, saveSchedule: _saveScheduleDirect, log: log),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_dashboard.png', size: 24, accent: homeColor), selectedIcon: appAssetIcon('assets/ui/tab_dashboard.png', size: 27, accent: homeColor, selected: true), label: 'Acasă'), homeColor);
    addPage(hasPermission(FunctionPermission.viewProgram),
      ProgramPage(currentUser: me, teams: teams, cars: cars, locations: locations, categories: categories, schedules: schedules, records: records, settings: settings, canEditTeam: canEditTeam, canEditProgram: hasPermission(FunctionPermission.editProgram), userName: userName, onChanged: refresh, notifyTeam: notifyTeam, log: log, saveSchedule: _saveScheduleDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_grafic.png', size: 24, accent: programColor), selectedIcon: appAssetIcon('assets/ui/tab_grafic.png', size: 27, accent: programColor, selected: true), label: 'Grafic'), programColor);
    addPage(hasPermission(FunctionPermission.viewMap),
      MapPage(currentUser: me, users: users, teams: teams, schedules: schedules, records: records, locations: locations, categories: categories, isAdmin: isAdmin, hiddenUserIds: _hiddenUserIds, onChanged: refresh, log: log, saveLocation: _saveLocationDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_harta.png', size: 24, accent: mapColor), selectedIcon: appAssetIcon('assets/ui/tab_harta.png', size: 27, accent: mapColor, selected: true), label: 'Hartă'), mapColor);
    addPage(hasPermission(FunctionPermission.viewCentralizer),
      CentralizerPage(currentUser: me, teams: teams, locations: locations, categories: categories, schedules: schedules, records: records, isAdmin: isAdmin, canEditTeam: canEditTeam, canEditCentralizer: hasPermission(FunctionPermission.editCentralizer), onChanged: refresh, log: log, saveRecord: _saveRecordDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_centralizator.png', size: 24, accent: centralizerColor), selectedIcon: appAssetIcon('assets/ui/tab_centralizator.png', size: 27, accent: centralizerColor, selected: true), label: compactNav ? 'Central.' : 'Centralizator'), centralizerColor);
    addPage(hasPermission(FunctionPermission.viewOwnDecont) || hasPermission(FunctionPermission.viewOtherDecont),
      ExpensePage(diagnosticSessionIsCurrent: () => _sessionActive, currentUser: me, teams: teams, users: users, expenses: expenses, perDiems: perDiems, finances: finances, settlements: settlements, settings: settings, canEditTeam: canEditTeam, isAdmin: isAdmin, canEditOwnDecont: hasPermission(FunctionPermission.viewOwnDecont), canViewOtherDecont: hasPermission(FunctionPermission.viewOtherDecont), onChanged: refresh, notifyUser: notifyUser, log: log, saveExpense: _saveExpenseDirect, savePerDiem: _savePerDiemDirect, saveFinance: _saveFinanceDirect, saveSettlement: _saveSettlementDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_decont.png', size: 24, accent: decontColor), selectedIcon: appAssetIcon('assets/ui/tab_decont.png', size: 27, accent: decontColor, selected: true), label: 'Decont'), decontColor);
    addPage(hasPermission(FunctionPermission.viewContacts),
      MessagesContactsPage(locations:locations,settings:settings,canEditContacts:hasPermission(FunctionPermission.editContacts),canManageTemplates:hasPermission(FunctionPermission.manageMessageTemplates),onChanged:refresh,log:log),
      NavigationDestination(icon: appAssetIcon('assets/ui/chat_live.png', size: 24, accent: messagesColor), selectedIcon: appAssetIcon('assets/ui/chat_live.png', size: 27, accent: messagesColor, selected: true), label: compactNav ? 'Contacte' : 'Mesaje'), messagesColor);
    addPage(true, DocumentsPage(isAdmin: isAdmin),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_documente.png', size: 24, accent: docsColor), selectedIcon: appAssetIcon('assets/ui/tab_documente.png', size: 27, accent: docsColor, selected: true), label: compactNav ? 'Doc.' : 'Documente'), docsColor);
    addPage(true,
      SettingsPage(user: me, notifications: notifications, settings: settings, onChanged: refresh, onThemeChanged: _scheduleSettingsChanged, onAdmin: isAdmin ? () => _openAdmin() : null, onLogout: () => FirebaseAuth.instance.signOut()),
      const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: settingsColor), label: 'Setări'), settingsColor);

    if (pages.isEmpty) {
      pages.add(const _Empty(icon: Icons.lock_outline, text: 'Contul nu are încă drepturi de acces. Contactează Adminul.'));
      destinations.add(const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Cont'));
      tabColors.add(settingsColor);
    }
    if (tab >= pages.length) tab = 0;
    final selectedColor = tabColors[tab];

    return Scaffold(
      endDrawerEnableOpenDragGesture: true,
      endDrawer: kIsWeb ? Drawer(
        width: math.min(MediaQuery.sizeOf(context).width * .88, 330.0),
        child: SafeArea(child: Column(children: [
          ListTile(title: const Text('Categorii', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), trailing: Builder(builder: (drawerContext) => IconButton(icon: const Icon(Icons.close), tooltip: 'Închide meniul', onPressed: () => Navigator.of(drawerContext).pop()))),
          const Divider(height: 1),
          Expanded(child: ListView.builder(itemCount: destinations.length, itemBuilder: (drawerContext, i) => ListTile(
            leading: destinations[i].icon,
            title: Text(destinations[i].label),
            selected: tab == i,
            selectedTileColor: tabColors[i].withValues(alpha: .15),
            onTap: () { setState(() => tab = i); Navigator.of(drawerContext).pop(); },
          ))),
        ])),
      ) : null,
      body: _AppBackdrop(
        settings: settings,
        child: SafeArea(child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: .90),
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
            ),
            child: Row(children: [
              SizedBox(width:compactNav?104:150,height:38,child:appBrandLogo(settings,width:150,height:38)),
              const SizedBox(width:6),
              compactNav
                ? IconButton(tooltip:'Despre',onPressed:_openAbout,icon:const Icon(Icons.info_outline))
                : TextButton.icon(onPressed:_openAbout,icon:const Icon(Icons.info_outline),label:const Text('Despre')),
              const Spacer(),
              Badge(
                isLabelVisible:myUnreadNotifications>0,
                label:Text(myUnreadNotifications>99?'99+':'$myUnreadNotifications'),
                child: IconButton(
                  tooltip:'Notificări',
                  onPressed:_openNotificationsSheet,
                  icon:const Icon(Icons.notifications_outlined),
                ),
              ),
              const SizedBox(width:6),
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: _openProfile,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: compactNav ? 16 : 17, backgroundImage: myPhoto == null ? null : MemoryImage(myPhoto), child: myPhoto == null ? const Icon(Icons.person, size: 18) : null),
                    if(!compactNav)...[const SizedBox(width:8), const Text('Profil', style: TextStyle(fontWeight: FontWeight.w700))],
                  ]),
                ),
              ),
              const SizedBox(width:6),
              if (kIsWeb) Builder(builder: (menuContext) => IconButton(
                tooltip: 'Deschide categoriile',
                icon: const Icon(Icons.menu_open_rounded, size: 29),
                onPressed: () => Scaffold.of(menuContext).openEndDrawer(),
              )),
              if(compactNav)...[
                IconButton(tooltip:'Membrii',onPressed:()=>_openMembersDirectory(),icon:sectionAssetWidget('Membri', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.people_outline)),
                Badge(isLabelVisible:_unreadMessageCount>0,label:Text(_unreadMessageCount>99?'99+':'$_unreadMessageCount'),child:IconButton(tooltip:'Chat live',onPressed:_openGroupChat,icon:sectionAssetWidget('Chat live', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.forum_outlined))),
              ]else...[
                FilledButton.tonalIcon(onPressed:()=>_openMembersDirectory(),icon:sectionAssetWidget('Membri', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.people_outline),label:const Text('Membrii')),
                const SizedBox(width:8),
                Badge(isLabelVisible:_unreadMessageCount>0,label:Text(_unreadMessageCount>99?'99+':'$_unreadMessageCount'),child:FilledButton.tonalIcon(onPressed:_openGroupChat,icon:sectionAssetWidget('Chat live', size: 19, accent: Theme.of(context).colorScheme.primary, fallbackIcon: Icons.forum_outlined),label:const Text('Chat live'))),
              ],
            ]),
          ),
          Expanded(child: pages[tab]),
        ])),
      ),
      bottomNavigationBar: kIsWeb ? null : NavigationBar(
        height: compactNav ? 66 : 72,
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .97),
        indicatorColor: selectedColor.withValues(alpha: .18),
        labelBehavior: compactNav ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: destinations,
      ),
    );
  }


}

