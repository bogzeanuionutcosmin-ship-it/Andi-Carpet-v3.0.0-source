part of '../main.dart';

class HomePage extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final FirebaseUserProfile profile;
  const HomePage({super.key, required this.settings, required this.onSettingsChanged, required this.profile});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with _HomeBackupMaintenance, _HomePermissionMaintenance, _HomeDocumentCodecs, _HomeLocationSeed {
  int tab = 0;
  late final String currentUserId;
  AppSettings get settings => widget.settings;
  late final List<AppUser> users;
  late final List<Team> teams;
  late final List<Car> cars;
  late final List<Location> locations;
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
  final HomeLiveLocationResources _liveLocationResources = HomeLiveLocationResources();
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
    if (!usesLocalFirebaseEmulators) {
      _startAdaptiveLiveLocation();
      unawaited(_initPushNotifications());
    }
  }

  void _showIncomingPopup({required String title, required String body, VoidCallback? onView}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff1F2937),
          duration: const Duration(seconds: 7),
          content: Row(children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              if (body.trim().isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
            ])),
          ]),
          action: onView == null ? null : SnackBarAction(label: 'VEZI', textColor: Colors.white, onPressed: onView),
        ));
    });
  }

  Future<void> _openChatFromAlert(String otherUserId) async {
    if (!mounted || otherUserId.trim().isEmpty || otherUserId == currentUserId) return;
    if (!isAdmin && _hiddenUserIds.contains(otherUserId)) return;
    try {
      final snap = await FirebaseFirestore.instance.collection(isAdmin ? 'users' : 'memberDirectory').doc(otherUserId).get();
      if (!mounted) return;
      final d = snap.data() ?? <String, dynamic>{};
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrivateChatPage(
        currentUser: me,
        otherUserId: otherUserId,
        otherName: (d['name'] ?? d['email'] ?? 'Membru').toString(),
        otherPhotoBase64: (d['photoBase64'] ?? '').toString(),
      )));
    } catch (_) {
      if (mounted) _openMembersDirectory();
    }
  }

  String _pushTokenDocId(String token) => pushTokenDocumentId(token);

  Future<void> _savePushToken(String token) async {
    if (token.trim().isEmpty) return;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    await FirebaseFirestore.instance
        .collection('users').doc(currentUserId)
        .collection('pushTokens').doc(_pushTokenDocId(token))
        .set({
          'token': token,
          'platform': platform,
          'deviceOwnerUid': currentUserId,
          'active': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _offerPushPermissionAutomatically() {
    if (_pushPermissionDialogShown || !mounted) return;
    _pushPermissionDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.notifications_active_outlined),
            SizedBox(width: 10),
            Expanded(child: Text('Activează notificările')),
          ]),
          content: const Text(
            'Andi Carpetă îți va înregistra automat acest dispozitiv pentru notificări. '
            'Trebuie doar să confirmi o singură dată permisiunea sistemului. După aceea nu mai este nevoie de „Reînregistrează dispozitivul”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Mai târziu'),
            ),
            FilledButton.icon(
              onPressed: () {
                // Important pentru Web/iOS: requestPermission trebuie pornit direct
                // din gestul utilizatorului. Pornim înainte de a închide dialogul.
                unawaited(_initPushNotifications(fromUserGesture: true));
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Activează'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _initPushNotifications({bool fromUserGesture = false}) async {
    if (_pushInitializationInFlight) return;
    _pushInitializationInFlight = true;
    try {
      final messaging = FirebaseMessaging.instance;

      NotificationSettings permission;
      if (kIsWeb && fromUserGesture) {
        // Pe Web (inclusiv PWA iPhone), cererea trebuie lansată direct dintr-un
        // gest al utilizatorului. Nu facem niciun await înainte de apelul acesta.
        permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
      } else {
        permission = await messaging.getNotificationSettings();
        if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
          if (kIsWeb) {
            // Nu cerem utilizatorului să intre în Profil. Afișăm automat dialogul
            // de activare, iar după tap tokenul este creat și salvat singur.
            _offerPushPermissionAutomatically();
            return;
          }
          permission = await messaging.requestPermission(alert: true, badge: true, sound: true);
        }
      }

      if (permission.authorizationStatus == AuthorizationStatus.denied ||
          permission.authorizationStatus == AuthorizationStatus.deniedPermanently) {
        debugPrint('[push] Permisiunea pentru notificări este refuzată.');
        return;
      }
      if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (kIsWeb) _offerPushPermissionAutomatically();
        return;
      }

      if (kIsWeb) {
        if (_webPushVapidKey.trim().isEmpty) {
          debugPrint('[push] FCM_WEB_VAPID_KEY lipsește din build.');
          return;
        }
        // După acordarea permisiunii, dăm service worker-ului o clipă să fie gata.
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _webPushVapidKey)
          : await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[push] Firebase Messaging nu a returnat un token.');
        return;
      }

      await _savePushToken(token);
      debugPrint('[push] Token FCM înregistrat AUTOMAT și salvat pentru $currentUserId.');

      if (!_pushListenersAttached) {
        _pushListenersAttached = true;
        _coreSubscriptions.add(messaging.onTokenRefresh.listen(
          (value) => unawaited(_savePushToken(value)),
          onError: (Object error) => debugPrint('[push] onTokenRefresh: $error'),
        ));
        _coreSubscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final type = (message.data['type'] ?? '').toString();
          if (type == 'chat') {
            final senderId = (message.data['senderId'] ?? '').toString();
            if (senderId.isNotEmpty) unawaited(_openChatFromAlert(senderId));
          }
        }));
      }

      final initial = await messaging.getInitialMessage();
      if (initial != null && (initial.data['type'] ?? '').toString() == 'chat') {
        final senderId = (initial.data['senderId'] ?? '').toString();
        if (senderId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_openChatFromAlert(senderId)));
        }
      }
    } catch (e, st) {
      debugPrint('[push] Inițializarea FCM a eșuat: $e');
      debugPrintStack(stackTrace: st);
      // Butonul din Profil rămâne doar ca diagnostic/fallback. Înregistrarea
      // normală se face automat la fiecare pornire/login.
    } finally {
      _pushInitializationInFlight = false;
    }
  }

  void _startAdaptiveLiveLocation() {
    if (usesLocalFirebaseEmulators) return;
    unawaited(_liveLocationResources.stop());
    unawaited(_shareLiveLocationIfAllowed());
    if (kIsWeb) {
      // Browserele/PWA pot suspenda complet execuția când aplicația este închisă.
      // Cât timp pagina rulează folosim intervalul adaptiv de mai jos.
      _liveLocationResources.startPeriodicPolling(
        interval: const Duration(minutes: 1),
        onTick: () => unawaited(_shareLiveLocationIfAllowed()),
      );
      return;
    }
    unawaited(_startNativeBackgroundLocationStream());
  }

  Future<void> _startNativeBackgroundLocationStream() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      await _liveLocationResources.clearPositionSubscription();

      // Mod economic: cât timp suntem departe de următoarea sală folosim mai puține
      // actualizări. La apropierea de traseul activ activăm temporar precizia ridicată.
      final economical = homeUsesEconomicalLocationTracking(
        locationMode: _personalLocationMode,
        proximityBoost: _nativeLocationProximityBoost,
      );
      LocationSettings settings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: economical ? LocationAccuracy.medium : LocationAccuracy.high,
          distanceFilter: economical ? 60 : 10,
          intervalDuration: economical ? const Duration(minutes: 1) : const Duration(seconds: 20),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: 'Andi Carpetă · locație activă',
            notificationText: economical
                ? 'Localizare economică activă. Precizia crește automat lângă următoarea sală.'
                : 'Te apropii de o locație programată. Detectarea sosirii este activă.',
            enableWakeLock: !economical,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        settings = AppleSettings(
          accuracy: economical ? LocationAccuracy.medium : LocationAccuracy.high,
          distanceFilter: economical ? 60 : 10,
          pauseLocationUpdatesAutomatically: economical,
          showBackgroundLocationIndicator: true,
        );
      } else {
        settings = LocationSettings(
          accuracy: economical ? LocationAccuracy.medium : LocationAccuracy.high,
          distanceFilter: economical ? 60 : 10,
        );
      }
      await _liveLocationResources.replacePositionSubscription(
        Geolocator.getPositionStream(locationSettings: settings).listen(
          (position) => unawaited(_shareLiveLocationIfAllowed(position)),
          onError: (Object e) => debugPrint('[location] Background stream: $e'),
        ),
      );
    } catch (e) {
      debugPrint('[location] Nu am putut porni tracking-ul nativ în background: $e');
    }
  }

  void _updateNativeLocationProximityBoost(Position p, DateTime workDate) {
    if (kIsWeb || _personalLocationMode != 'economic') return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty) return;
    final active = homeActiveSchedulesForWorkDate<WorkSchedule>(
      schedules: schedules,
      teamId: teamId,
      workDate: workDate,
      teamIdOf: (schedule) => schedule.teamId,
      dateOf: (schedule) => schedule.date,
      isStarted: (schedule) => schedule.started,
      isClosed: (schedule) => schedule.closed,
      isPaused: (schedule) => schedule.paused,
      isPostponed: (schedule) => schedule.postponed,
      sameDay: sameDay,
    );
    var nearest = double.infinity;
    for (final schedule in active) {
      for (final item in schedule.items) {
        final r = _homeLatestRecord(teamId, item.locationId, workDate);
        if (r?.status == WorkAttemptStatus.completed || r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted) continue;
        final loc = _homeLocationById(item.locationId);
        if (loc?.latitude == null || loc?.longitude == null) continue;
        final meters = Geolocator.distanceBetween(p.latitude, p.longitude, loc!.latitude!, loc.longitude!);
        if (meters < nearest) nearest = meters;
      }
    }
    final action = homeLocationProximityAction(
      isBoosted: _nativeLocationProximityBoost,
      nearestMeters: nearest,
    );
    if (action == HomeLocationProximityAction.boost) {
      _nativeLocationProximityBoost = true;
      Future<void>.delayed(const Duration(milliseconds: 250), () => _startNativeBackgroundLocationStream());
    } else if (action == HomeLocationProximityAction.relax) {
      _nativeLocationProximityBoost = false;
      Future<void>.delayed(const Duration(milliseconds: 250), () => _startNativeBackgroundLocationStream());
    }
  }

  Future<String> _resolveLiveLocality(Position p) async {
    final now = DateTime.now();
    final resolvedAt = _lastLiveLocalityResolvedAt;
    final lastPosition = _lastLiveLocalityPosition;
    final movedMeters = _lastLiveLocalityLabel.isNotEmpty && resolvedAt != null && lastPosition != null
        ? Geolocator.distanceBetween(lastPosition.latitude, lastPosition.longitude, p.latitude, p.longitude)
        : null;
    if (shouldReuseLiveLocalityCache(
      label: _lastLiveLocalityLabel,
      resolvedAt: resolvedAt,
      distanceMovedMeters: movedMeters,
      now: now,
    )) return _lastLiveLocalityLabel;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': p.latitude.toStringAsFixed(7),
        'lon': p.longitude.toStringAsFixed(7),
        'zoom': '10',
        'addressdetails': '1',
        'accept-language': 'ro',
      });
      final headers = <String,String>{'Accept':'application/json','Accept-Language':'ro'};
      if (!kIsWeb) headers['User-Agent'] = 'AndiCarpeta/2.0.8 (internal operations app)';
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['address'] is Map) {
          final a = decoded['address'] as Map;
          final label = liveLocalityLabelFromAddress(a);
          if (label.isNotEmpty) {
            _lastLiveLocalityLabel = label;
            _lastLiveLocalityResolvedAt = now;
            _lastLiveLocalityPosition = p;
            return label;
          }
        }
      }
    } catch (e) {
      debugPrint('[location] Localitatea nu a putut fi identificată: $e');
    }
    return _lastLiveLocalityLabel;
  }

  Future<void> _shareLiveLocationIfAllowed([Position? suppliedPosition]) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final now = DateTime.now();
      final workDate = operationalWorkDate(now);
      final inWork = isInsideWorkWindow(now, workDate);

      // Preferința personală poate fi live / economic / offline. În timpul programului
      // modul offline este ridicat automat la economic, ca detectarea operațională să aibă date.
      final locationPolicy = liveLocationSharePolicy(
        personalMode: _personalLocationMode,
        inWork: inWork,
        nativeLocationProximityBoost: _nativeLocationProximityBoost,
        preferredIntervalMinutes: _personalLocationIntervalMinutes,
        now: now,
        lastSharedAt: _lastSharedAt,
      );
      final effectiveMode = locationPolicy.effectiveMode;
      if (locationPolicy.clearWhenOutsideWork) {
        if (!_offlineLocationCleared) {
          await FirebaseFirestore.instance.collection('liveLocations').doc(currentUserId).delete();
          _offlineLocationCleared = true;
          _lastSharedAt = null;
          _lastSharedPosition = null;
        }
        return;
      }
      _offlineLocationCleared = false;

      if (_lastSharedAt != null &&
          now.difference(_lastSharedAt!) < locationPolicy.minimumInterval) {
        return;
      }

      final accuracy = locationPolicy.useHighAccuracy
          ? LocationAccuracy.high
          : LocationAccuracy.medium;
      final p = suppliedPosition ?? await Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: accuracy));
      _updateNativeLocationProximityBoost(p, workDate);
      var moved = true;
      if (_lastSharedPosition != null) {
        final meters = Geolocator.distanceBetween(_lastSharedPosition!.latitude, _lastSharedPosition!.longitude, p.latitude, p.longitude);
        moved = meters >= locationPolicy.movementThresholdMeters;
      }
      final heartbeatDue = locationPolicy.heartbeatDue;
      if (!moved && !heartbeatDue) return;
      final myTeam = me.teamId;
      final localityLabel = await _resolveLiveLocality(p);
      await FirebaseFirestore.instance.collection('liveLocations').doc(currentUserId).set({
        'userId': currentUserId,
        'name': me.name,
        'teamId': myTeam,
        'photoBase64': me.photoBase64,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'mode': inWork ? 'operational-$effectiveMode' : effectiveMode,
        'nativeBackground': !kIsWeb,
        'localityLabel': localityLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _lastSharedPosition = p;
      _lastSharedAt = now;
      await _applyWorkAutomationFromPosition(p, now, workDate);
    } catch (e) {
      debugPrint('[location] Actualizarea locației a eșuat: $e');
    }
  }

  Location? _homeLocationById(String id) {
    for (final l in locations) { if (l.id == id) return l; }
    return null;
  }

  CentralizerRecord? _homeLatestRecord(String teamId, String locationId, DateTime workDate) {
    final list = records.where((r) => r.teamId == teamId && r.locationId == locationId && (recordHasOpenAttempt(r) || recordBelongsToWorkDate(r, workDate))).toList()
      ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    return list.isEmpty ? null : list.last;
  }

  void _automationNotifyOnce(String key, String title, String message) {
    if (_automationNotified.add(key)) notifyUser(currentUserId, title, message);
  }

  Future<void> _applyWorkAutomationFromPosition(Position p, DateTime now, DateTime workDate) async {
    // Geofencing-ul nu poate confirma sosirea dintr-o poziție GPS imprecisă,
    // veche sau raportată în timpul deplasării rapide. Nu pornim niciodată
    // o intervenție fără alegerea explicită a utilizatorului.
    if (!isUsableGeofencePosition(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyMeters: p.accuracy,
      speedMetersPerSecond: p.speed,
      timestamp: p.timestamp,
      now: now,
    )) return;
    if (!hasPermission(FunctionPermission.editProgram)) return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty || !canEditTeam(teamId)) return;

    await _maybeAutoCloseResolvedSchedules(workDate);

    final active = homeActiveSchedulesForWorkDate<WorkSchedule>(
      schedules: schedules,
      teamId: teamId,
      workDate: workDate,
      teamIdOf: (schedule) => schedule.teamId,
      dateOf: (schedule) => schedule.date,
      isStarted: (schedule) => schedule.started,
      isClosed: (schedule) => schedule.closed,
      isPaused: (schedule) => schedule.paused,
      isPostponed: (schedule) => schedule.postponed,
      sameDay: sameDay,
    );
    if (active.isEmpty) return;
    if (active.length > 1) {
      _automationNotifyOnce('multi_${teamId}_${workDate.toIso8601String().substring(0,10)}', 'Automatizare suspendată', 'Sunt mai multe grafice pornite pentru aceeași echipă. Alege manual locația pentru INTRĂ/IEȘI.');
      return;
    }
    final schedule = active.first;
    final access = settings.learning['access'];

    final running = records.where((r) => r.teamId == teamId && r.status == WorkAttemptStatus.running && r.finishedAt == null && recordBelongsToWorkDate(r, workDate)).toList()
      ..sort((a, b) => recordEventTime(b).compareTo(recordEventTime(a)));

    // Finalizarea automată rămâne disponibilă doar dacă Learning pentru acces este activ.
    if (running.isNotEmpty) {
      if (settings.autoFinish && access?.enabled == true) {
        final current = running.first;
        final loc = _homeLocationById(current.locationId);
        if (loc?.latitude != null && loc?.longitude != null && current.startedAt != null) {
          final meters = Geolocator.distanceBetween(p.latitude, p.longitude, loc!.latitude!, loc.longitude!);
          final elapsed = now.difference(current.startedAt!);
          if (meters >= 220 && elapsed >= const Duration(minutes: 5)) {
            final firstOutside = _autoOutsideSince.putIfAbsent(current.id, () => now);
            if (now.difference(firstOutside) >= const Duration(seconds: 45)) {
              // Nu mai închidem automat intervenția: răspunsul despre fațadă este obligatoriu.
              _automationNotifyOnce(
                'finish_${current.id}',
                'Confirmă ieșirea din locație',
                'Te-ai îndepărtat ${meters.round()} m de ${current.locationNameSnapshot}. Apasă STOP și răspunde obligatoriu dacă fațada a fost realizată.',
              );
            }
          } else {
            _autoOutsideSince.remove(current.id);
            _automationNotified.remove('finish_${current.id}');
          }
        }
      }
      return;
    }

    // Sosirea la sală cere întotdeauna confirmarea omului. Nu pornim lucrarea doar
    // pentru că GPS-ul spune că telefonul este în apropiere.
    final candidates = <HomeArrivalCandidate<(ScheduleItem, Location)>>[];
    for (final item in schedule.items) {
      final r = _homeLatestRecord(teamId, item.locationId, workDate);
      if (r?.status == WorkAttemptStatus.completed ||
          r?.status == WorkAttemptStatus.refused ||
          r?.status == WorkAttemptStatus.notCompleted ||
          r?.status == WorkAttemptStatus.waitingAccess ||
          r?.status == WorkAttemptStatus.running) continue;
      final loc = _homeLocationById(item.locationId);
      if (loc?.latitude == null || loc?.longitude == null) continue;
      final meters = Geolocator.distanceBetween(p.latitude, p.longitude, loc!.latitude!, loc.longitude!);
      candidates.add(HomeArrivalCandidate(value: (item, loc), meters: meters));
    }
    final candidate = nearestEligibleHomeArrivalCandidate<(ScheduleItem, Location)>(
      candidates: candidates,
      accuracyMeters: p.accuracy,
    );
    if (candidate == null) {
      _autoInsideSince.clear();
      _arrivalSnoozedUntil.clear();
      _arrivalPromptCounts.clear();
      _automationNotified.removeWhere((key) => key.startsWith('arrival_'));
      return;
    }

    final item = candidate.value.$1;
    final meters = candidate.meters;
    final key = '${schedule.id}_${item.locationId}_${workDate.year}${two(workDate.month)}${two(workDate.day)}';
    final firstInside = _autoInsideSince.putIfAbsent(key, () => now);
    _autoInsideSince.removeWhere((k, _) => k != key);

    // Mic dwell pentru a evita întrebarea când doar trecem pe lângă locație.
    if (now.difference(firstInside) < const Duration(seconds: 20)) return;
    final snoozedUntil = _arrivalSnoozedUntil[key];
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) return;
    if ((_arrivalPromptCounts[key] ?? 0) >= 2) return;

    await _handleArrivalDetected(schedule, item, meters, workDate, key);
  }

  Future<void> _handleArrivalDetected(WorkSchedule schedule, ScheduleItem item, double meters, DateTime workDate, String key) async {
    final notificationKey = 'arrival_$key';
    _automationNotifyOnce(
      notificationKey,
      'Ai ajuns la ${item.locationNameSnapshot}',
      'Ești la aproximativ ${meters.round()} m. Ai început lucrul sau ești în așteptare?',
    );
    if (!mounted || _arrivalDialogOpen) return;

    _arrivalDialogOpen = true;
    _arrivalPromptCounts[key] = (_arrivalPromptCounts[key] ?? 0) + 1;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ai ajuns la locație'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.locationNameSnapshot, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text('Detectat la aproximativ ${meters.round()} m de locație.'),
          const SizedBox(height: 12),
          const Text('Ce se întâmplă acum?'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'later'), child: const Text('NU ÎNCĂ')),
          OutlinedButton.icon(onPressed: () => Navigator.pop(dialogContext, 'waiting'), icon: const Icon(Icons.hourglass_top), label: const Text('SUNT ÎN AȘTEPTARE')),
          FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, 'start'), icon: const Icon(Icons.play_arrow), label: const Text('ÎNCEP LUCRUL')),
        ],
      ),
    );
    _arrivalDialogOpen = false;
    if (!mounted) return;

    if (choice == 'later') {
      _arrivalSnoozedUntil[key] = DateTime.now().add(const Duration(minutes: 10));
      // Permitem o singură reamintire după 10 minute dacă membrul este încă acolo.
      _automationNotified.remove(notificationKey);
      return;
    }
    if (choice == 'waiting') {
      await _saveArrivalWaiting(schedule, item, workDate);
      return;
    }
    if (choice == 'start') {
      await _saveArrivalStart(schedule, item, workDate);
    }
  }

  Future<void> _saveArrivalStart(WorkSchedule schedule, ScheduleItem item, DateTime workDate) async {
    final teamId = schedule.teamId;
    final now = DateTime.now();
    final existing = _homeLatestRecord(teamId, item.locationId, workDate);
    // Dacă între timp colegul a stabilit deja starea, nu dublăm execuția.
    if (!canWriteHomeArrivalChoice(existing)) return;
    final started = CentralizerRecord(
      id: existing?.id ?? idNow(), writeBaseline: existing?.writeBaseline, teamId: teamId, locationId: item.locationId, type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot, addressSnapshot: item.addressSnapshot,
      waitingStartedAt: existing?.waitingStartedAt,
      waitingEndedAt: existing?.waitingStartedAt != null && existing?.waitingEndedAt == null ? now : existing?.waitingEndedAt,
      startedAt: now, finishedAt: null, status: WorkAttemptStatus.running,
      refusalReason: null, keptForLearning: existing?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: existing?.facadeDone ?? false,
    );
    try {
      await _saveRecordDirect(started);
      log('INTRĂ confirmat la sosire', '${item.locationNameSnapshot} · ${timeText(now)}');
      if (mounted) showSuccessMessage(context, 'Lucrarea a început la ${item.locationNameSnapshot}.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Pornirea lucrării nu a putut fi salvată: $e');
    }
  }

  Future<void> _saveArrivalWaiting(WorkSchedule schedule, ScheduleItem item, DateTime workDate) async {
    final teamId = schedule.teamId;
    final now = DateTime.now();
    final existing = _homeLatestRecord(teamId, item.locationId, workDate);
    if (!canWriteHomeArrivalChoice(existing)) return;
    final waiting = CentralizerRecord(
      id: existing?.id ?? idNow(), writeBaseline: existing?.writeBaseline, teamId: teamId, locationId: item.locationId, type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot, addressSnapshot: item.addressSnapshot,
      waitingStartedAt: existing?.waitingStartedAt ?? now, waitingEndedAt: null,
      startedAt: null, finishedAt: null, status: WorkAttemptStatus.waitingAccess,
      refusalReason: null, keptForLearning: existing?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: existing?.facadeDone ?? false,
    );
    try {
      await _saveRecordDirect(waiting);
      log('Așteptare confirmată la sosire', '${item.locationNameSnapshot} · ${timeText(now)}');
      if (mounted) showSuccessMessage(context, 'Așteptarea a fost pornită la ${item.locationNameSnapshot}.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Așteptarea nu a putut fi salvată: $e');
    }
  }

  Future<void> _maybeAutoCloseResolvedSchedules(DateTime workDate) async {
    if (!settings.autoCloseWhenAllDone || !hasPermission(FunctionPermission.editProgram)) return;
    final programLearning = settings.learning['program'];
    if (programLearning?.enabled != true) return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty || !canEditTeam(teamId)) return;
    final active = schedules.where((s) => s.teamId == teamId && sameDay(s.date, workDate) && s.started && !s.closed).toList();
    for (final schedule in active) {
      if (schedule.items.isEmpty) continue;
      var allResolved = true;
      for (final item in schedule.items) {
        final r = _homeLatestRecord(teamId, item.locationId, workDate);
        if (r == null || (r.status != WorkAttemptStatus.completed && r.status != WorkAttemptStatus.refused && r.status != WorkAttemptStatus.notCompleted)) {
          allResolved = false; break;
        }
      }
      if (!allResolved) continue;
      final key = 'close_${schedule.id}';
      if (programLearning!.mode == LearningMode.manualApproval) {
        _automationNotifyOnce(key, 'Grafic terminat', '${schedule.graphName} are toate locațiile rezolvate. Poți închide graficul.');
        continue;
      }
      schedule.closed = true;
      schedule.active = false;
      schedule.paused = false;
      try {
        await _saveScheduleDirect(schedule);
        log('Grafic închis automat Learning', '${schedule.graphName} · ${formatDate(schedule.date)}');
        _automationNotified.add(key);
      } catch (_) {}
    }
  }

  final _coreSubscriptions = HomeSubscriptionRegistry();
  final _financialSubscriptions = HomeSubscriptionRegistry();
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
    final teamIds = projectHomeTeamMembership(
      userIds: users.map((user) => user.id),
      teams: teams,
    );
    for (var index = 0; index < users.length; index++) {
      users[index].teamId = teamIds[index];
    }
  }

  void _startFinancialSync() {
    final canViewOtherDeconts = hasPermission(FunctionPermission.viewOtherDecont);
    final canViewAll = isAdmin || canViewOtherDeconts;
    final scope = homeFinancialSyncScope(
      isAdmin: isAdmin,
      canViewOtherDeconts: canViewOtherDeconts,
      teamId: me.teamId,
    );
    if (!shouldRestartHomeFinancialSync(_financialTeamScope, scope)) return;
    _financialTeamScope = scope;
    unawaited(_financialSubscriptions.cancelAll());
    expenses.clear(); perDiems.clear(); finances.clear(); settlements.clear();
    if (scope == null || scope.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final db=FirebaseFirestore.instance;
    final Query<Map<String,dynamic>> expensesQuery = canViewAll ? db.collection('expenses') : db.collection('expenses').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> perDiemQuery = canViewAll ? db.collection('perDiems') : db.collection('perDiems').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> financeQuery = canViewAll ? db.collection('finance') : db.collection('finance').where('teamId',isEqualTo:scope);
    final Query<Map<String,dynamic>> settlementQuery = canViewAll ? db.collection('settlements') : db.collection('settlements').where('teamId',isEqualTo:scope);
    _financialSubscriptions.add(expensesQuery.snapshots().listen((snap){
      final list=snap.docs.map(_expenseFromDoc).toList()..sort((a,b)=>a.date.compareTo(b.date));
      if(!mounted)return;setState((){expenses..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Cheltuieli: $e');}));
    _financialSubscriptions.add(perDiemQuery.snapshots().listen((snap){
      final list=snap.docs.map(_perDiemFromDoc).toList()..sort((a,b)=>a.date.compareTo(b.date));
      if(!mounted)return;setState((){perDiems..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Diurne: $e');}));
    _financialSubscriptions.add(financeQuery.snapshots().listen((snap){
      final list=snap.docs.map(_financeFromDoc).toList();
      if(!mounted)return;setState((){finances..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Financiar: $e');}));
    _financialSubscriptions.add(settlementQuery.snapshots().listen((snap){
      final list=snap.docs.map(_settlementFromDoc).toList()..sort((a,b)=>b.startDate.compareTo(a.startDate));
      if(!mounted)return;setState((){settlements..clear()..addAll(list);});
    },onError:(Object e){if(mounted)setState(()=>coreSyncError='Deplasări: $e');}));
  }

  Future<void> _runAutomaticMaintenance() async {
    if (!isAdmin || _automaticBackupInFlight) return;
    _automaticBackupInFlight = true;
    try {
      await _pruneOldNotifications();
      await _pruneAutomaticBackups();
      if (!settings.automaticBackup) return;
      final db = FirebaseFirestore.instance;
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
      debugPrint('Mentenanță automată: $e');
    } finally {
      _automaticBackupInFlight = false;
    }
  }

  void _startAuditSync(FirebaseFirestore db) {
    if (!isAdmin) return;
    _coreSubscriptions.add(
      db.collection('audit').orderBy('at', descending: true).limit(500).snapshots().listen((snap) {
        final list = snap.docs.map((doc) {
          final d = doc.data();
          return AuditEntry(
            id: doc.id,
            actor: (d['actor'] ?? '').toString(),
            action: (d['action'] ?? '').toString(),
            target: (d['target'] ?? '').toString(),
            at: _dateFrom(d['at']) ?? DateTime.now(),
          );
        }).toList();
        if (!mounted) return;
        setState(() {
          audit
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Audit: $e');
      }),
    );
  }

  void _startDefinitionsSync(FirebaseFirestore db) {
    _coreSubscriptions.add(
      db.collection('locationCategories').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedDefinitionsIfNeeded());
          return;
        }
        final list = snap.docs.map(_categoryFromDoc).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final item = _categoryFromDoc(doc);
          _categoryCache[item.id] = _encoded(_categoryMap(item));
        }
        if (!mounted) return;
        setState(() { categories..clear()..addAll(list); });
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Categorii: $e'); }),
    );

    _coreSubscriptions.add(
      db.collection('backgrounds').snapshots().listen((snap) {
        final next=<String,Map<String,String>>{};
        for(final doc in snap.docs){
          final d=doc.data();
          if(d['active']==false)continue;
          final image=(d['imageBase64']??'').toString();
          if(image.isEmpty)continue;
          next[doc.id]={'name':(d['name']??doc.id).toString(),'imageBase64':image};
        }
        if(!mounted)return;
        setState((){settings.customBackgrounds..clear()..addAll(next);});
        WidgetsBinding.instance.addPostFrameCallback((_)=>widget.onSettingsChanged());
      },onError:(Object e){if(mounted)setState(()=>coreSyncError='Fundaluri: $e');}),
    );

    _coreSubscriptions.add(
      db.collection('functions').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedDefinitionsIfNeeded());
          return;
        }
        final list = snap.docs.map(_functionFromDoc).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final item = _functionFromDoc(doc);
          _functionCache[item.id] = _encoded(_functionMap(item));
        }
        if (!mounted) return;
        setState(() { functionDefinitions..clear()..addAll(list); });
        _startFinancialSync();
        if (isAdmin) unawaited(_syncUserPermissionSnapshots());
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Funcții: $e'); }),
    );

  }

  void _startDirectorySync(FirebaseFirestore db) {
    _coreSubscriptions.add(
      (isAdmin ? db.collection('users') : db.collection('memberDirectory')).snapshots().listen((snap) {
        final list = snap.docs.map((doc) {
          final d = doc.data();
          final roleText = (d['role'] ?? 'member').toString();
          final role = roleText == 'admin' ? UserRole.director : UserRole.member;
          final function = FirebaseUserProfile._functionFrom(d['function']?.toString(), roleText);
          final email = (d['email'] ?? '').toString();
          var name = (d['name'] ?? '').toString().trim();
          final nickname = (d['nickname'] ?? '').toString().trim();
          if (d['useNickname'] == true && nickname.isNotEmpty) name = nickname;
          if (name.isEmpty) name = roleText == 'admin' ? 'Administrator' : (email.isEmpty ? doc.id : email.split('@').first);
          _userTeamCache[doc.id] = d['teamId']?.toString();
          if (doc.id == currentUserId) {
            _personalLocationMode = (d['locationMode'] ?? 'economic').toString();
            _personalLocationIntervalMinutes = (d['locationIntervalMinutes'] is num) ? (d['locationIntervalMinutes'] as num).toInt().clamp(1, 60).toInt() : 10;
            final rawNotificationPreferences=d['notificationPreferences'];
            if(rawNotificationPreferences is Map){for(final key in _personalNotificationPreferences.keys.toList()){if(rawNotificationPreferences[key] is bool)_personalNotificationPreferences[key]=rawNotificationPreferences[key] as bool;}}
            final rawGroupSeen = d['lastGroupChatSeenAt'];
            _lastGroupChatSeenAt = rawGroupSeen is Timestamp ? rawGroupSeen.toDate() : null;
            if (_recentGroupDocs.isNotEmpty) _recomputeGroupUnread();
            final personalTheme = AppThemeChoice.values.firstWhere((x) => x.name == (d['theme'] ?? settings.theme.name).toString(), orElse: () => settings.theme);
            final personalFont = _normalizeFontChoice((d['fontFamily'] ?? settings.fontFamily).toString());
            final visualChanged = personalTheme != settings.theme || personalFont != settings.fontFamily;
            settings.theme = personalTheme;
            // Fundalul este global și este controlat exclusiv de Admin.
            settings.personalBackgroundId = 'global';
            settings.fontFamily = personalFont;
            if (visualChanged) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSettingsChanged());
          }
          final functionIds = d['functionIds'] is List
              ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
              : <String>[(roleText == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList();
          return AppUser(
            id: doc.id,
            name: name,
            role: role,
            function: function,
            functionIds: functionIds,
            teamId: d['teamId']?.toString(),
            email: email,
            active: d['active'] == true,
            hiddenFromMembers: d['hiddenFromMembers'] == true,
            photoBase64: (d['photoBase64'] ?? '').toString(),
          );
        }).where((u) => isAdmin || !u.hiddenFromMembers || u.id == currentUserId).toList();
        final hiddenIds = snap.docs.where((doc) {
          final d = doc.data();
          return (d['role'] ?? '').toString() == 'admin' && d['hiddenFromMembers'] == true;
        }).map((doc) => doc.id).toSet();
        list.sort((a, b) {
          if (a.role != b.role) return a.role == UserRole.director ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        if (!mounted) return;
        setState(() {
          _hiddenUserIds
            ..clear()
            ..addAll(hiddenIds);
          users
            ..clear()
            ..addAll(list);
          if (!users.any((u) => u.id == currentUserId)) {
            users.add(AppUser(
              id: widget.profile.uid,
              name: widget.profile.name,
              role: widget.profile.isAdmin ? UserRole.director : UserRole.member,
              function: widget.profile.function,
              functionIds: widget.profile.functionIds,
              email: widget.profile.email,
              active: widget.profile.active,
            ));
          }
          _applyTeamMembership();
        });
        _startFinancialSync();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Conturi: $e');
      }),
    );

  }

  void _startOwnProfileSync(FirebaseFirestore db) {
    // Datele private ale contului propriu nu sunt in directorul public.
    if (!isAdmin) _coreSubscriptions.add(
      db.collection('users').doc(currentUserId).snapshots().listen((snap) {
        final d = snap.data();
        if (d == null || !mounted) return;
        _personalLocationMode = (d['locationMode'] ?? 'economic').toString();
        _personalLocationIntervalMinutes = (d['locationIntervalMinutes'] is num)
            ? (d['locationIntervalMinutes'] as num).toInt().clamp(1, 60).toInt() : 10;
        final prefs = d['notificationPreferences'];
        if (prefs is Map) {
          for (final key in _personalNotificationPreferences.keys.toList()) {
            if (prefs[key] is bool) _personalNotificationPreferences[key] = prefs[key] as bool;
          }
        }
        final seen = d['lastGroupChatSeenAt'];
        _lastGroupChatSeenAt = seen is Timestamp ? seen.toDate() : null;
        if (_recentGroupDocs.isNotEmpty) _recomputeGroupUnread();
        final personalTheme = AppThemeChoice.values.firstWhere(
          (x) => x.name == (d['theme'] ?? settings.theme.name).toString(),
          orElse: () => settings.theme);
        final personalFont = _normalizeFontChoice((d['fontFamily'] ?? settings.fontFamily).toString());
        final visualChanged = personalTheme != settings.theme || personalFont != settings.fontFamily;
        settings.theme = personalTheme;
        settings.personalBackgroundId = 'global';
        settings.fontFamily = personalFont;
        if (visualChanged) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSettingsChanged());
      }, onError: (Object e) { if (mounted) setState(() => coreSyncError = 'Profil propriu: $e'); }),
    );

  }

  void _startOperationsSync(FirebaseFirestore db) {
    _coreSubscriptions.add(
      db.collection('teams').snapshots().listen((snap) {
        final list = snap.docs.map(_teamFromDoc).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final doc in snap.docs) {
          final t = _teamFromDoc(doc);
          _teamCache[doc.id] = _encoded(_teamMap(t));
        }
        if (!mounted) return;
        setState(() {
          teams
            ..clear()
            ..addAll(list);
          _applyTeamMembership();
        });
        _startFinancialSync();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Echipe: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('cars').snapshots().listen((snap) {
        final list = snap.docs.map(_carFromDoc).toList()..sort((a, b) => a.plate.compareTo(b.plate));
        for (final doc in snap.docs) {
          final c = _carFromDoc(doc);
          _carCache[doc.id] = _encoded(_carMap(c));
        }
        if (!mounted) return;
        setState(() {
          cars
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Mașini: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('locations').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          if (isAdmin) unawaited(_seedLocationsIfNeeded());
          return;
        }
        final list = snap.docs.map(_locationFromDoc).toList()..sort((a, b) => a.id.compareTo(b.id));
        for (final doc in snap.docs) {
          final l = _locationFromDoc(doc);
          _locationCache[doc.id] = _encoded(_locationMap(l));
        }
        if (!mounted) return;
        setState(() {
          locations
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Locații: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('schedules').snapshots().listen((snap) {
        final list = snap.docs.map(_scheduleFromDoc).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        for (final doc in snap.docs) {
          final item = _scheduleFromDoc(doc);
          _scheduleCache[doc.id] = _encoded(_scheduleMap(item));
        }
        if (!mounted) return;
        setState(() {
          schedules
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Grafice de lucru: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('records').snapshots().listen((snap) {
        final list = snap.docs.map(_recordFromDoc).toList()
          ..sort((a, b) => (a.startedAt ?? DateTime(2000)).compareTo(b.startedAt ?? DateTime(2000)));
        for (final doc in snap.docs) {
          final item = _recordFromDoc(doc);
          _recordCache[doc.id] = _encoded(_recordMap(item));
        }
        if (!mounted) return;
        setState(() {
          records
            ..clear()
            ..addAll(list);
        });
        unawaited(_maybeAutoCloseResolvedSchedules(operationalWorkDate(DateTime.now())));
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Execuții: $e');
      }),
    );


  }

  void _startNotificationSync(FirebaseFirestore db) {
    final Query<Map<String, dynamic>> notificationQuery = isAdmin
        ? db.collection('notifications')
        : db.collection('notifications').where('userId', isEqualTo: currentUserId);
    _coreSubscriptions.add(
      notificationQuery.snapshots().listen((snap) {
        final list = snap.docs.map(_notificationFromDoc).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final ownUnread = snap.docs.where((d) {
          final data = d.data();
          return (data['userId'] ?? '').toString() == currentUserId && data['read'] != true;
        }).toList();
        if (!_notificationsPrimed) {
          _knownNotificationIds.addAll(snap.docs.map((d) => d.id));
          _notificationsPrimed = true;
          final alertable=ownUnread.where((doc){final d=doc.data();return _allowPersonalAlert((d['title']??'Notificare').toString(),(d['message']??'').toString());}).toList();
          if (alertable.isNotEmpty) {
            _showIncomingPopup(
              title: alertable.length == 1 ? (alertable.first.data()['title']??'Notificare nouă').toString() : '${alertable.length} notificări necitite',
              body: alertable.length == 1 ? (alertable.first.data()['message'] ?? '').toString() : 'Le găsești în Setări → Istoric notificări.',
            );
          }
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null || (data['userId'] ?? '').toString() != currentUserId || data['read'] == true) continue;
            if (!_knownNotificationIds.add(doc.id)) continue;
            final title=(data['title']??'Notificare nouă').toString();final body=(data['message']??'').toString();
            if(_allowPersonalAlert(title,body))_showIncomingPopup(title:title,body:body);
          }
          _knownNotificationIds.addAll(snap.docs.map((d) => d.id));
        }
        if (!mounted) return;
        setState(() {
          notifications
            ..clear()
            ..addAll(list);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Notificări: $e');
      }),
    );

  }

  void _startChatSync(FirebaseFirestore db) {
    String visibleSenderName(Map<String, dynamic> data) =>
        visibleChatSenderName(data, isAdmin: isAdmin, hiddenUserIds: _hiddenUserIds);

    bool mandatoryChatAlert(Map<String,dynamic> data) {
      final senderId=(data['senderId']??'').toString();
      if(_hiddenUserIds.contains(senderId))return true;
      return users.any((u)=>u.id==senderId&&u.role==UserRole.director);
    }

    _coreSubscriptions.add(
      db.collection('chatMessages').where('recipientId', isEqualTo: currentUserId).snapshots().listen((snap) {
        final unread = snap.docs.where((d) {
          final data = d.data();
          final deletedFor = data['deletedFor'];
          final senderId = (data['senderId'] ?? '').toString();
          if (!isAdmin && _hiddenUserIds.contains(senderId)) return false;
          return data['read'] != true && !(deletedFor is List && deletedFor.map((e) => e.toString()).contains(currentUserId));
        }).toList();
        if (!_messagesPrimed) {
          _knownIncomingMessageIds.addAll(snap.docs.map((d) => d.id));
          _messagesPrimed = true;
          final mandatoryUnread=unread.any((doc)=>mandatoryChatAlert(doc.data()));
          if (unread.isNotEmpty && ((_personalNotificationPreferences['chat']??true)||mandatoryUnread)) {
            final one = unread.length == 1 ? unread.first.data() : null;
            _showIncomingPopup(
              title: unread.length == 1 ? 'Mesaj nou de la ${visibleSenderName(one!)}' : '${unread.length} mesaje necitite',
              body: unread.length == 1 ? (one?['text'] ?? '').toString() : 'Deschide Chat live pentru conversații.',
              onView: one == null ? ()=>_openMembersDirectory(chatMode:true) : () => unawaited(_openChatFromAlert((one['senderId'] ?? '').toString())),
            );
          }
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null || data['read'] == true || !_knownIncomingMessageIds.add(doc.id)) continue;
            if((_personalNotificationPreferences['chat']??true)||mandatoryChatAlert(data))_showIncomingPopup(
              title: 'Mesaj nou de la ${visibleSenderName(data)}',
              body: (data['text'] ?? '').toString(),
              onView: () => unawaited(_openChatFromAlert((data['senderId'] ?? '').toString())),
            );
          }
          _knownIncomingMessageIds.addAll(snap.docs.map((d) => d.id));
        }
        _unreadPrivateMessageCount = unread.length;
        _refreshUnreadMessageCount();
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Mesaje: $e');
      }),
    );

    _coreSubscriptions.add(
      db.collection('groupChatMessages').orderBy('createdAt', descending: true).limit(20).snapshots().listen((snap) {
        final docs = snap.docs;
        _recentGroupDocs = docs;
        _recomputeGroupUnread();
        if (!_groupMessagesPrimed) {
          _knownGroupMessageIds.addAll(docs.map((d) => d.id));
          _groupMessagesPrimed = true;
        } else {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            final data = doc.data();
            if (data == null) continue;
            if ((data['senderId'] ?? '').toString() == currentUserId || !_knownGroupMessageIds.add(doc.id)) continue;
            if (_personalNotificationPreferences['chat'] ?? true) {
              _showIncomingPopup(
                title: 'Mesaj nou în Chat live',
                body: '${(data['senderName'] ?? 'Membru').toString()}: ${(data['text'] ?? '').toString()}',
                onView: _openGroupChat,
              );
            }
          }
          _knownGroupMessageIds.addAll(docs.map((d) => d.id));
        }
      }, onError: (Object e) {
        if (mounted) setState(() => coreSyncError = 'Chat comun: $e');
      }),
    );

  }

  void _startSettingsSync(FirebaseFirestore db) {
    _coreSubscriptions.add(
      db.collection('meta').doc('uiSettings').snapshots().listen((snap) {
        final d = snap.data();
        if (!mounted) return;
        if (d == null) { if (isAdmin) unawaited(_runAutomaticMaintenance()); return; }
        setState(() {
          settings.background = (d['background'] ?? settings.background).toString();
          settings.brandingBackgroundId = (d['brandingBackgroundId'] ?? settings.brandingBackgroundId).toString();
          settings.brandingLogoId = (d['brandingLogoId'] ?? settings.brandingLogoId).toString();
          settings.androidDownloadUrl = (d['androidDownloadUrl'] ?? settings.androidDownloadUrl).toString();
          final smsTime = (d['smsPreviousDayTime'] ?? settings.smsPreviousDayTime).toString().trim();
          if (RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(smsTime)) settings.smsPreviousDayTime = smsTime;
          final rawTemplates = d['smsTemplates'];
          if (rawTemplates is Map) {
            for (final key in <String>['initial','rescheduled','postponed']) {
              final value = rawTemplates[key]?.toString().trim();
              if (value != null && value.isNotEmpty) settings.smsTemplates[key] = value;
            }
          }
          if (d['backgroundOpacity'] is num) settings.backgroundOpacity = (d['backgroundOpacity'] as num).toDouble().clamp(0.0, .70).toDouble();
          if (d['defaultPerDiem'] is num) settings.defaultPerDiem = (d['defaultPerDiem'] as num).toDouble();
          if (d['allowUndo'] is bool) settings.allowUndo = d['allowUndo'] as bool;
          if (d['autoStart'] is bool) settings.autoStart = d['autoStart'] as bool;
          if (d['autoFinish'] is bool) settings.autoFinish = d['autoFinish'] as bool;
          if (d['autoCloseWhenAllDone'] is bool) settings.autoCloseWhenAllDone = d['autoCloseWhenAllDone'] as bool;
          if (d['pushNotifications'] is bool) settings.pushNotifications = d['pushNotifications'] as bool;
          if (d['automaticBackup'] is bool) settings.automaticBackup = d['automaticBackup'] as bool;
          if (d['backupRetentionDays'] is num) settings.backupRetentionDays = (d['backupRetentionDays'] as num).toInt().clamp(1,365).toInt();
          if (d['notificationHistoryDays'] is num) settings.notificationHistoryDays = (d['notificationHistoryDays'] as num).toInt().clamp(1,365).toInt();
          final rawLearning = d['learning'];
          if (rawLearning is Map) {
            for (final entry in settings.learning.entries) {
              final raw = rawLearning[entry.key];
              if (raw is! Map) continue;
              if (raw['enabled'] is bool) entry.value.enabled = raw['enabled'] as bool;
              final modeName = raw['mode']?.toString();
              for (final mode in LearningMode.values) {
                if (mode.name == modeName) entry.value.mode = mode;
              }
            }
          }
        });
        if (isAdmin) unawaited(_runAutomaticMaintenance());
      }, onError: (Object e) {
        if (mounted && isAdmin) setState(() => coreSyncError = 'Setări UI: $e');
      }),
    );

  }

  void _startCoreSync() {
    final db = FirebaseFirestore.instance;

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
      debugPrint('[learning] Nu s-a putut salva evenimentul $category/$event: $e');
    }
  }

  Future<void> _deleteLocationDirect(String id) async {
    if (!isAdmin) throw StateError('Doar Adminul poate șterge locații.');
    await FirebaseFirestore.instance.collection('locations').doc(id).delete();
    unawaited(_writeLearningEvent(category: 'operations', event: 'location_deleted', locationId: id));
    _locationCache.remove(id);
    if (!mounted) return;
    setState(() => locations.removeWhere((x) => x.id == id));
  }

  Future<void> _saveLocationDirect(Location l) async {
    if (!isAdmin) throw StateError('Doar Adminul poate modifica locații.');
    final data = _locationMap(l);
    await FirebaseFirestore.instance.collection('locations').doc(l.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'operations', event: 'location_saved', locationId: l.id, data: {
      'name': l.name, 'status': l.status.name, 'active': l.active, 'hasGps': l.latitude != null && l.longitude != null,
    }));
    _locationCache[l.id] = _encoded(data);
    if (!mounted) return;
    setState(() {
      final index = locations.indexWhere((x) => x.id == l.id);
      if (index >= 0) {
        locations[index] = l;
      } else {
        locations.add(l);
      }
      locations.sort((a, b) => a.id.compareTo(b.id));
    });
  }

  Future<void> _saveScheduleDirect(WorkSchedule schedule) => _saveSchedulesDirect(<WorkSchedule>[schedule]);

  /// Commits a whole-graph change in one Firestore transaction. Comparing each
  /// loaded updatedAt timestamp prevents a second editor from silently
  /// replacing a newer day, while the transaction keeps multi-day writes atomic.
  /// Local state is updated only after Firestore confirms the transaction.
  Future<void> _saveSchedulesDirect(List<WorkSchedule> batchSchedules) async {
    if (batchSchedules.isEmpty) return;
    if (batchSchedules.length > 500) {
      throw StateError('Graficul depășește limita sigură de 500 de zile pentru o singură salvare.');
    }
    final ids = <String>{};
    final teamId = batchSchedules.first.teamId;
    final graphId = batchSchedules.first.graphId;
    for (final schedule in batchSchedules) {
      if (schedule.id.trim().isEmpty || !ids.add(schedule.id)) {
        throw StateError('Graficul conține identificatori de zile lipsă sau duplicați; nicio modificare nu a fost salvată.');
      }
      if (schedule.teamId != teamId || schedule.graphId != graphId) {
        throw StateError('Salvarea grupată trebuie să conțină zile dintr-un singur grafic și o singură echipă.');
      }
      if (!canEditTeam(schedule.teamId) || !hasPermission(FunctionPermission.editProgram)) {
        throw StateError('Nu ai dreptul să modifici graficul echipei ${schedule.teamId}.');
      }
    }

    final db = FirebaseFirestore.instance;
    final committedAt = DateTime.now();
    final writeTokens = <String, String>{
      for (final schedule in batchSchedules)
        schedule.id: '${committedAt.microsecondsSinceEpoch}-${idNow()}-${schedule.id}',
    };
    await db.runTransaction((transaction) async {
      final refs = <String, DocumentReference<Map<String, dynamic>>>{};
      for (final schedule in batchSchedules) {
        final reference = db.collection('schedules').doc(schedule.id);
        refs[schedule.id] = reference;
        final snapshot = await transaction.get(reference);
        // Existence is independent of revision metadata: a deleted legacy day
        // with no timestamp/token must not be mistaken for a new day.
        if (schedule.persisted != snapshot.exists) {
          throw StateError('Ziua de grafic a fost ștearsă sau identificatorul este deja folosit. Reîncarcă graficul.');
        }
        final remoteData = snapshot.data();
        final rawUpdatedAt = remoteData?['updatedAt'];
        final remoteUpdatedAt = rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null;
        final rawWriteToken = remoteData?['writeToken'];
        final remoteWriteToken = rawWriteToken is String ? rawWriteToken : null;
        if (rawUpdatedAt != null && remoteUpdatedAt == null) {
          throw StateError('Graficul ${schedule.graphName} conține un timestamp de versiune invalid. Reîncarcă aplicația și cere administratorului să verifice datele.');
        }
        if (rawWriteToken != null && remoteWriteToken == null) {
          throw StateError('Graficul ${schedule.graphName} conține un token de versiune invalid. Reîncarcă aplicația și cere administratorului să verifice datele.');
        }
        final expectedUpdatedAt = schedule.updatedAt;
        final timestampChanged = snapshot.exists
            ? expectedUpdatedAt == null
                ? remoteUpdatedAt != null
                : remoteUpdatedAt == null || !remoteUpdatedAt.isAtSameMomentAs(expectedUpdatedAt)
            : expectedUpdatedAt != null;
        final tokenChanged = snapshot.exists
            ? schedule.writeToken == null
                ? remoteWriteToken != null
                : remoteWriteToken != schedule.writeToken
            : schedule.writeToken != null;
        if (timestampChanged || tokenChanged) {
          throw StateError('Ziua ${formatDate(schedule.date)} din graficul ${schedule.graphName} a fost modificată sau ștearsă de pe alt dispozitiv. Reîncarcă graficul și aplică din nou modificarea.');
        }
      }
      for (final schedule in batchSchedules) {
        final data = _scheduleMap(schedule);
        data['updatedAt'] = Timestamp.fromDate(committedAt);
        data['writeToken'] = writeTokens[schedule.id];
        transaction.set(refs[schedule.id]!, data, SetOptions(merge: true));
      }
    });

    for (final schedule in batchSchedules) {
      schedule.persisted = true;
      schedule.updatedAt = committedAt;
      schedule.writeToken = writeTokens[schedule.id];
      final data = _scheduleMap(schedule);
      _scheduleCache[schedule.id] = _encoded(data);
      unawaited(_writeLearningEvent(category: 'program', event: 'schedule_saved', teamId: schedule.teamId, scheduleId: schedule.id, data: {
        'date': schedule.date.toIso8601String(), 'started': schedule.started, 'closed': schedule.closed,
        'paused': schedule.paused, 'postponed': schedule.postponed, 'order': schedule.items.map((e) => e.locationId).toList(),
        'autoProposed': schedule.autoProposed, 'learningConfidence': schedule.learningConfidence,
      }));
    }
    if (!mounted) return;
    setState(() {
      for (final schedule in batchSchedules) {
        final index = schedules.indexWhere((x) => x.id == schedule.id);
        if (index >= 0) {
          schedules[index] = schedule;
        } else {
          schedules.add(schedule);
        }
      }
    });
  }

  Future<void> _saveRecordDirect(CentralizerRecord record) async {
    final canWriteRecord = hasPermission(FunctionPermission.editProgram) || hasPermission(FunctionPermission.editCentralizer);
    if (!canEditTeam(record.teamId) || !canWriteRecord) {
      throw StateError('Nu ai dreptul să modifici execuțiile acestei echipe.');
    }
    final data = _recordMap(record);
    await saveRecordCompared(FirebaseFirestore.instance, record.id, data, expected: record.writeBaseline);
    record.writeBaseline = Map<String, dynamic>.from(data)..remove('updatedAt');
    unawaited(_writeLearningEvent(category: 'duration', event: 'execution_${record.status.name}', teamId: record.teamId, locationId: record.locationId, data: {
      'startedAt': record.startedAt?.toIso8601String(), 'finishedAt': record.finishedAt?.toIso8601String(),
      'durationSeconds': record.duration?.inSeconds, 'waitingSeconds': record.waitingDuration?.inSeconds,
      'refusalReason': record.refusalReason ?? '', 'keptForLearning': record.keptForLearning,
    }));
    _recordCache[record.id] = _encoded(data);
    if (!mounted) return;
    setState(() {
      final index = records.indexWhere((x) => x.id == record.id);
      if (index >= 0) {
        records[index] = record;
      } else {
        records.add(record);
      }
    });
  }

  // Centralizer corrections are compare-and-swap updates, never upserts.
  // A stale editor cannot resurrect a deleted record or overwrite a newer correction.
  Future<void> _correctCentralizerRecord(
    CentralizerRecord original,
    CentralizerRecord corrected,
  ) async {
    if (!hasPermission(FunctionPermission.editCentralizer) ||
        !canEditTeam(original.teamId) ||
        original.id != corrected.id ||
        original.teamId != corrected.teamId ||
        original.locationId != corrected.locationId ||
        original.type != corrected.type) {
      throw StateError('Corecția intervenției nu este autorizată.');
    }
    final expected = <String, Object?>{
      'teamId': original.teamId,
      'locationId': original.locationId,
      'type': original.type.name,
      'startedAt': original.startedAt,
      'finishedAt': original.finishedAt,
      'status': original.status.name,
      'facadeDone': original.facadeDone,
      'facadePlanned': original.facadePlanned,
    };
    final changes = <String, dynamic>{
      'startedAt': corrected.startedAt == null ? null : Timestamp.fromDate(corrected.startedAt!),
      'finishedAt': corrected.finishedAt == null ? null : Timestamp.fromDate(corrected.finishedAt!),
      'facadeDone': corrected.facadeDone,
      'facadePlanned': corrected.facadePlanned,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await correctCentralizerRecordCompared(
      FirebaseFirestore.instance, original.id, expected: expected, changes: changes,
    );
    if (!mounted) return;
    setState(() {
      final index = records.indexWhere((item) => item.id == corrected.id);
      if (index >= 0) records[index] = corrected;
    });
  }

  Future<void> _saveExpenseDirect(Expense expense) async {
    if (!canEditTeam(expense.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw StateError('Nu ai dreptul să modifici Decontul acestei echipe.');
    }
    final data = _expenseMap(expense);
    await FirebaseFirestore.instance.collection('expenses').doc(expense.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: expense.ocrRawText.trim().isNotEmpty ? 'ocr' : 'finance', event: 'expense_saved', teamId: expense.teamId, data: {
      'category': expense.category, 'amount': expense.amount, 'documentType': expense.documentType.name,
      'ocrConfidence': expense.ocrConfidence, 'confirmed': expense.confirmed, 'hasImage': expense.hasImage,
    }));
    _expenseCache[expense.id] = _encoded(data);
  }

  Future<void> _savePerDiemDirect(PerDiemEntry entry) async {
    final canWrite = isAdmin || entry.memberId == currentUserId ||
        (canEditTeam(entry.teamId) && hasPermission(FunctionPermission.viewOwnDecont));
    if (!canWrite) throw StateError('Nu ai dreptul să modifici această diurnă.');
    final data = _perDiemMap(entry);
    // Confirmarea sau refuzul se salvează atomic. Verificarea exclusiv în UI
    // nu poate preveni două confirmări simultane de pe dispozitive diferite.
    final isReceiptResponse = entry.distributedBy != null &&
        (entry.status == PerDiemStatus.confirmed ||
         (entry.status == PerDiemStatus.awaitingConfirmation && entry.received == false));
    final db = FirebaseFirestore.instance;
    final ref = db.collection('perDiems').doc(entry.id);
    if (isReceiptResponse) {
      if (entry.memberId != currentUserId) {
        throw StateError('Doar beneficiarul poate confirma primirea diurnei.');
      }
      // 79–86: validarea se face înainte de tranzacție, iar în tranzacție
      // verificăm documentul curent, nu datele posibil învechite din UI.
      final received = entry.actualReceivedAmount;
      final receivedBani = received == null ? null :
          (received.isFinite ? parsePerDiemBani(received.toString()) : null);
      final isRefusal = entry.received == false &&
          entry.status == PerDiemStatus.awaitingConfirmation && received == null;
      if (!isRefusal && (entry.status != PerDiemStatus.confirmed ||
          entry.received != true || receivedBani == null || receivedBani <= 0)) {
        throw StateError('Confirmare invalidă: suma primită trebuie să fie pozitivă.');
      }
      if (FirebaseAuth.instance.currentUser?.uid != currentUserId) {
        throw StateError('Sesiunea de autentificare nu corespunde beneficiarului.');
      }
      final auditRef = ref.collection('receiptAudit').doc();
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Distribuirea nu mai există.');
        final previous = snap.data()!;
        if (previous['memberId'] != currentUserId ||
            previous['distributedBy'] == null ||
            previous['status'] != PerDiemStatus.awaitingConfirmation.name ||
            previous['actualReceivedAmount'] != null) {
          throw StateError('Diurna a fost deja confirmată sau modificată. Reîncarcă datele.');
        }
        if (previous['distributedBy'] is! String ||
            (previous['distributedBy'] as String).isEmpty) {
          throw StateError('Distribuitorul acestei diurne este invalid.');
        }
        final declared = previous['amount'];
        if (declared is! num || !declared.toDouble().isFinite ||
            declared <= 0 || parsePerDiemBani(declared.toString()) == null) {
          throw StateError('Suma declarată nu este validă.');
        }
        if (isRefusal && previous['received'] == false) {
          throw StateError('Refuzul a fost deja înregistrat.');
        }
        // Valoarea declarată, identitatea și echipa NU sunt modificate.
        final declaredBani = parsePerDiemBani(declared.toString())!;
        final changes = <String, dynamic>{
          'received': !isRefusal,
          'actualReceivedAmount': isRefusal ? null : receivedBani! / 100,
          'status': isRefusal ? PerDiemStatus.awaitingConfirmation.name
              : PerDiemStatus.confirmed.name,
          'confirmedAt': isRefusal ? null : FieldValue.serverTimestamp(),
          'receiptUpdatedAt': FieldValue.serverTimestamp(),
        };
        tx.update(ref, changes);
        tx.set(auditRef, {
          'actorUid': currentUserId,
          'action': isRefusal ? 'reported_missing' : 'confirmed_received',
          'distributorId': previous['distributedBy'],
          'beneficiaryId': previous['memberId'],
          'declaredAmountBani': declaredBani,
          'actualReceivedBani': isRefusal ? 0 : receivedBani,
          'differenceBani': declaredBani - (isRefusal ? 0 : receivedBani!),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      // Distribuirea este imuabilă: nu suprascriem confirmări existente.
      await db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) {
          throw StateError('Această distribuire există deja.');
        }
        tx.set(ref, data);
      });
    }
    unawaited(_writeLearningEvent(category: 'finance', event: 'per_diem_saved', teamId: entry.teamId, data: {
      'memberId': entry.memberId, 'amount': entry.amount, 'status': entry.status.name, 'method': entry.method?.name ?? '',
    }));
    _perDiemCache[entry.id] = _encoded(data);
  }

  Future<void> _saveSettlementDirect(TravelSettlement settlement) async {
    if (!canEditTeam(settlement.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw StateError('Nu ai dreptul să modifici această deplasare.');
    }
    await FirebaseFirestore.instance.collection('settlements').doc(settlement.id).set(_settlementMap(settlement), SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'finance', event: 'settlement_saved', teamId: settlement.teamId, data: {
      'name': settlement.name, 'closed': settlement.closed, 'received': settlement.totalReceived,
    }));
  }

  Future<void> _saveFinanceDirect(TeamFinance finance) async {
    if (!canEditTeam(finance.teamId) || !hasPermission(FunctionPermission.viewOwnDecont)) {
      throw StateError('Nu ai dreptul să modifici datele financiare ale acestei echipe.');
    }
    final data = _financeMap(finance);
    await FirebaseFirestore.instance.collection('finance').doc(finance.teamId).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'finance', event: 'team_finance_saved', teamId: finance.teamId, data: {
      'receivedDeparture': finance.receivedDeparture, 'receivedDuring': finance.receivedDuring, 'perDiemRate': finance.perDiemRate,
    }));
    _financeCache[finance.teamId] = _encoded(data);
  }

  Future<void> _writeAuditRemote(String action, String target) async {
    final entry = AuditEntry(id: idNow(), actor: me.name, action: action, target: target, at: DateTime.now());
    if (isAdmin && mounted) {
      setState(() => audit.insert(0, entry));
    }
    try {
      await FirebaseFirestore.instance.collection('audit').doc(entry.id).set({
        'actorUid': currentUserId,
        'actor': me.name,
        'action': action,
        'target': target,
        'at': Timestamp.fromDate(entry.at),
      });
      unawaited(_writeLearningEvent(category: 'operations', event: 'audit_action', data: {'action': action, 'target': target}));
    } catch (_) {
      // Auditul nu trebuie să blocheze operația principală; eroarea poate fi urmărită separat.
    }
  }

  Future<void> _persistCoreData() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final pendingLocations = <String, String>{};
    final pendingTeams = <String, String>{};
    final pendingCars = <String, String>{};
    final pendingUsers = <String, String?>{};
    var writes = 0;

    for (final l in locations) {
      final data = _locationMap(l);
      final encoded = _encoded(data);
      if (_locationCache[l.id] != encoded) {
        batch.set(db.collection('locations').doc(l.id), data, SetOptions(merge: true));
        pendingLocations[l.id] = encoded;
        writes++;
      }
    }

    for (final t in teams) {
      final data = _teamMap(t);
      final encoded = _encoded(data);
      if (_teamCache[t.id] != encoded) {
        batch.set(db.collection('teams').doc(t.id), data, SetOptions(merge: true));
        pendingTeams[t.id] = encoded;
        writes++;
      }
    }

    for (final c in cars) {
      final data = _carMap(c);
      final encoded = _encoded(data);
      if (_carCache[c.id] != encoded) {
        batch.set(db.collection('cars').doc(c.id), data, SetOptions(merge: true));
        pendingCars[c.id] = encoded;
        writes++;
      }
    }

    for (final u in users) {
      if (_userTeamCache[u.id] != u.teamId) {
        batch.set(db.collection('users').doc(u.id), {'teamId': u.teamId}, SetOptions(merge: true));
        pendingUsers[u.id] = u.teamId;
        writes++;
      }
    }

    if (writes == 0) return;
    await batch.commit();
    _locationCache.addAll(pendingLocations);
    _teamCache.addAll(pendingTeams);
    _carCache.addAll(pendingCars);
    _userTeamCache.addAll(pendingUsers);
  }

  @override
  void dispose() {
    unawaited(_coreSubscriptions.dispose());
    unawaited(_financialSubscriptions.dispose());
    unawaited(_liveLocationResources.dispose());
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
  void log(String action, String target) { unawaited(_writeAuditRemote(action, target)); }
  String _notificationCategory(String title, String message) =>
      personalAlertCategory(title, message);

  bool _allowPersonalAlert(String title, String message) =>
      allowsPersonalAlert(
        title: title,
        message: message,
        preferences: _personalNotificationPreferences,
      );
  void notifyUser(String uid, String title, String msg) {
    if (!settings.pushNotifications) return;
    final n = AppNotification(id: idNow(), userId: uid, title: title, message: msg, createdAt: DateTime.now());
    if (mounted && (isAdmin || uid == currentUserId)) setState(() => notifications.insert(0, n));
    unawaited(FirebaseFirestore.instance.collection('notifications').doc(n.id).set(_notificationMap(n)).catchError((Object e) {
      if (mounted) setState(() => coreSyncError = 'Notificare: $e');
    }));
  }
  void notifyTeam(String teamId, String title, String msg) {
    final matches = teams.where((t) => t.id == teamId);
    if (matches.isEmpty) return;
    for (final uid in matches.first.members) {
      notifyUser(uid, title, msg);
    }
  }
  void refresh() {
    // Refresh-urile operaționale nu trebuie să reconstruiască MaterialApp/AuthGate.
    // Tema este propagată separat doar când se schimbă efectiv în Firestore.
    setState(() {});
    if (isAdmin) {
      unawaited(_persistCoreData().catchError((Object e) {
        if (!mounted) return;
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

  void _recomputeGroupUnread() {
    final seenAt = _lastGroupChatSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    _unreadGroupMessageCount = _recentGroupDocs.where((doc) {
      final data = doc.data();
      if ((data['senderId'] ?? '').toString() == currentUserId) return false;
      final raw = data['createdAt'];
      final createdAt = raw is Timestamp ? raw.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      return createdAt.isAfter(seenAt);
    }).length;
    _refreshUnreadMessageCount();
  }

  void _refreshUnreadMessageCount() {
    if (!mounted) return;
    setState(() => _unreadMessageCount = _unreadPrivateMessageCount + _unreadGroupMessageCount);
  }

  void _openGroupChat() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupChatPage(currentUser: me, users: users, functionDefinitions: functionDefinitions))).then((_) {
      _unreadGroupMessageCount = 0;
      _refreshUnreadMessageCount();
    });
  }

  void _openMembersDirectory({bool chatMode=false}) {
    // Directorul membrilor este disponibil tuturor utilizatorilor autentificați.
    // Documentele sunt proiectate în memberDirectory fără date private.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MembersDirectoryPage(currentUser: me, functionDefinitions: functionDefinitions, chatMode: chatMode),
    ));
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage(
      user: me,
      teams: teams,
      functionDefinitions: functionDefinitions,
      records: records,
      perDiems: perDiems,
    )));
  }

  Future<void> _openNotificationsSheet() async {
    final mine = notifications.where((n) => n.userId == currentUserId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Notificări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Închide')),
                  ],
                ),
              ),
              Expanded(
                child: mine.isEmpty
                    ? const Center(child: Text('Nu ai notificări.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                        children: mine.take(50).map((n) => Card(
                          child: ListTile(
                            leading: Icon(n.read ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined),
                            title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w900)),
                            subtitle: Text('${n.message}\n${formatDate(n.createdAt)} · ${timeText(n.createdAt)}'),
                            isThreeLine: true,
                            onTap: n.read ? null : () async {
                              n.read = true;
                              await FirebaseFirestore.instance.collection('notifications').doc(n.id).set({'read': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                              if (mounted) setState(() {});
                            },
                          ),
                        )).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppInformationPage(settings: settings, isAdmin: isAdmin)));
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
      DashboardPage(teams: teams, users: users, functionDefinitions: functionDefinitions, locations: locations, categories: categories, schedules: schedules, records: records, settings: settings, currentUser: me, canEditProgram: hasPermission(FunctionPermission.editProgram), userName: userName, onChanged: refresh, saveRecord: _saveRecordDirect, saveSchedule: _saveScheduleDirect, saveSchedules: _saveSchedulesDirect, log: log),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_dashboard.png', size: 24, accent: homeColor), selectedIcon: appAssetIcon('assets/ui/tab_dashboard.png', size: 27, accent: homeColor, selected: true), label: 'Acasă'), homeColor);
    addPage(hasPermission(FunctionPermission.viewProgram),
      ProgramPage(currentUser: me, teams: teams, cars: cars, locations: locations, categories: categories, schedules: schedules, records: records, settings: settings, canEditTeam: canEditTeam, canEditProgram: hasPermission(FunctionPermission.editProgram), userName: userName, onChanged: refresh, notifyTeam: notifyTeam, log: log, saveSchedules: _saveSchedulesDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_grafic.png', size: 24, accent: programColor), selectedIcon: appAssetIcon('assets/ui/tab_grafic.png', size: 27, accent: programColor, selected: true), label: 'Grafic'), programColor);
    addPage(hasPermission(FunctionPermission.viewMap),
      MapPage(currentUser: me, users: users, teams: teams, schedules: schedules, records: records, locations: locations, categories: categories, isAdmin: isAdmin, hiddenUserIds: _hiddenUserIds, onChanged: refresh, log: log, saveLocation: _saveLocationDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_harta.png', size: 24, accent: mapColor), selectedIcon: appAssetIcon('assets/ui/tab_harta.png', size: 27, accent: mapColor, selected: true), label: 'Hartă'), mapColor);
    addPage(hasPermission(FunctionPermission.viewCentralizer),
      CentralizerPage(currentUser: me, teams: teams, locations: locations, categories: categories, schedules: schedules, records: records, isAdmin: isAdmin, canEditTeam: canEditTeam, canEditCentralizer: hasPermission(FunctionPermission.editCentralizer), onChanged: refresh, log: log, saveRecord: _saveRecordDirect, correctRecord: _correctCentralizerRecord),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_centralizator.png', size: 24, accent: centralizerColor), selectedIcon: appAssetIcon('assets/ui/tab_centralizator.png', size: 27, accent: centralizerColor, selected: true), label: compactNav ? 'Central.' : 'Centralizator'), centralizerColor);
    addPage(hasPermission(FunctionPermission.viewOwnDecont) || hasPermission(FunctionPermission.viewOtherDecont),
      ExpensePage(currentUser: me, teams: teams, users: users, expenses: expenses, perDiems: perDiems, finances: finances, settlements: settlements, settings: settings, canEditTeam: canEditTeam, isAdmin: isAdmin, canEditOwnDecont: hasPermission(FunctionPermission.viewOwnDecont), canViewOtherDecont: hasPermission(FunctionPermission.viewOtherDecont), onChanged: refresh, notifyUser: notifyUser, log: log, saveExpense: _saveExpenseDirect, savePerDiem: _savePerDiemDirect, saveFinance: _saveFinanceDirect, saveSettlement: _saveSettlementDirect),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_decont.png', size: 24, accent: decontColor), selectedIcon: appAssetIcon('assets/ui/tab_decont.png', size: 27, accent: decontColor, selected: true), label: 'Decont'), decontColor);
    addPage(hasPermission(FunctionPermission.viewContacts),
      MessagesContactsPage(locations:locations,settings:settings,canEditContacts:hasPermission(FunctionPermission.editContacts),canManageTemplates:hasPermission(FunctionPermission.manageMessageTemplates),onChanged:refresh,log:log),
      NavigationDestination(icon: appAssetIcon('assets/ui/chat_live.png', size: 24, accent: messagesColor), selectedIcon: appAssetIcon('assets/ui/chat_live.png', size: 27, accent: messagesColor, selected: true), label: compactNav ? 'Contacte' : 'Mesaje'), messagesColor);
    addPage(true, DocumentsPage(isAdmin: isAdmin),
      NavigationDestination(icon: appAssetIcon('assets/ui/tab_documente.png', size: 24, accent: docsColor), selectedIcon: appAssetIcon('assets/ui/tab_documente.png', size: 27, accent: docsColor, selected: true), label: compactNav ? 'Doc.' : 'Documente'), docsColor);
    addPage(true,
      SettingsPage(user: me, notifications: notifications, settings: settings, onChanged: refresh, onThemeChanged: widget.onSettingsChanged, onAdmin: isAdmin ? () => _openAdmin() : null, onLogout: () => FirebaseAuth.instance.signOut()),
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

  void _openAdmin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminPanelPage(users: users, teams: teams, cars: cars, locations: locations, categories: categories, functionDefinitions: functionDefinitions, schedules: schedules, records: records, expenses: expenses, perDiems: perDiems, finances: finances, settlements: settlements, notifications: notifications, audit: audit, settings: settings, userName: userName, onChanged: refresh, log: log, saveLocation: _saveLocationDirect, deleteLocation: _deleteLocationDirect)));
  }
}

