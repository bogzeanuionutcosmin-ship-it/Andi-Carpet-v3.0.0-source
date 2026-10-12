part of '../main.dart';

class HomePage extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final FirebaseUserProfile profile;
  const HomePage({super.key, required this.settings, required this.onSettingsChanged, required this.profile});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with _HomeBackupMaintenance {
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
    _startAdaptiveLiveLocation();
    unawaited(_initPushNotifications());
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

  String _pushTokenDocId(String token) => base64UrlEncode(utf8.encode(token)).replaceAll('=', '');

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
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    _backgroundLocationSubscription?.cancel();
    _backgroundLocationSubscription = null;
    unawaited(_shareLiveLocationIfAllowed());
    if (kIsWeb) {
      // Browserele/PWA pot suspenda complet execuția când aplicația este închisă.
      // Cât timp pagina rulează folosim intervalul adaptiv de mai jos.
      _liveLocationTimer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_shareLiveLocationIfAllowed()));
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

      await _backgroundLocationSubscription?.cancel();
      _backgroundLocationSubscription = null;

      // Mod economic: cât timp suntem departe de următoarea sală folosim mai puține
      // actualizări. La apropierea de traseul activ activăm temporar precizia ridicată.
      final economical = _personalLocationMode == 'economic' && !_nativeLocationProximityBoost;
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
      _backgroundLocationSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) => unawaited(_shareLiveLocationIfAllowed(position)),
        onError: (Object e) => debugPrint('[location] Background stream: $e'),
      );
    } catch (e) {
      debugPrint('[location] Nu am putut porni tracking-ul nativ în background: $e');
    }
  }

  void _updateNativeLocationProximityBoost(Position p, DateTime workDate) {
    if (kIsWeb || _personalLocationMode != 'economic') return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty) return;
    final active = schedules.where((s) => s.teamId == teamId && sameDay(s.date, workDate) && s.started && !s.closed && !s.paused && !s.postponed).toList();
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
    final shouldBoost = nearest <= 3000;
    final shouldRelax = nearest > 5000 || nearest == double.infinity;
    if (shouldBoost && !_nativeLocationProximityBoost) {
      _nativeLocationProximityBoost = true;
      Future<void>.delayed(const Duration(milliseconds: 250), () => _startNativeBackgroundLocationStream());
    } else if (shouldRelax && _nativeLocationProximityBoost) {
      _nativeLocationProximityBoost = false;
      Future<void>.delayed(const Duration(milliseconds: 250), () => _startNativeBackgroundLocationStream());
    }
  }

  Future<String> _resolveLiveLocality(Position p) async {
    final now = DateTime.now();
    if (_lastLiveLocalityLabel.isNotEmpty && _lastLiveLocalityResolvedAt != null && _lastLiveLocalityPosition != null) {
      final moved = Geolocator.distanceBetween(_lastLiveLocalityPosition!.latitude, _lastLiveLocalityPosition!.longitude, p.latitude, p.longitude);
      if (moved < 5000 && now.difference(_lastLiveLocalityResolvedAt!) < const Duration(minutes: 30)) return _lastLiveLocalityLabel;
    }
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
          String first(List<String> keys) {
            for (final key in keys) {
              final v = a[key]?.toString().trim() ?? '';
              if (v.isNotEmpty) return v;
            }
            return '';
          }
          final city = first(['city','town','municipality','village']);
          final county = first(['county','state']);
          final label = city.isNotEmpty && county.isNotEmpty && city.toLowerCase() != county.toLowerCase() ? '$city · $county' : (city.isNotEmpty ? city : county);
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
      var effectiveMode = _personalLocationMode;
      if (inWork && effectiveMode == 'offline') effectiveMode = 'economic';
      if (!inWork && effectiveMode == 'offline') {
        if (!_offlineLocationCleared) {
          await FirebaseFirestore.instance.collection('liveLocations').doc(currentUserId).delete();
          _offlineLocationCleared = true;
          _lastSharedAt = null;
          _lastSharedPosition = null;
        }
        return;
      }
      _offlineLocationCleared = false;

      final configured = _personalLocationIntervalMinutes.clamp(1, 60).toInt();
      final minGap = _nativeLocationProximityBoost && inWork
          ? const Duration(seconds: 20)
          : effectiveMode == 'live'
              ? const Duration(minutes: 1)
              : Duration(minutes: inWork ? configured.clamp(1, 3).toInt() : configured);
      if (_lastSharedAt != null && now.difference(_lastSharedAt!) < minGap) return;

      final accuracy = effectiveMode == 'live' || inWork ? LocationAccuracy.high : LocationAccuracy.medium;
      final p = suppliedPosition ?? await Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: accuracy));
      _updateNativeLocationProximityBoost(p, workDate);
      var moved = true;
      if (_lastSharedPosition != null) {
        final meters = Geolocator.distanceBetween(_lastSharedPosition!.latitude, _lastSharedPosition!.longitude, p.latitude, p.longitude);
        final threshold = effectiveMode == 'live' ? 10.0 : (inWork ? 25.0 : 150.0);
        moved = meters >= threshold;
      }
      final heartbeatDue = _lastSharedAt == null || inWork || (effectiveMode == 'live' && now.difference(_lastSharedAt!) >= const Duration(minutes: 5));
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
    final list = records.where((r) => r.teamId == teamId && r.locationId == locationId && recordBelongsToWorkDate(r, workDate)).toList()
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
    if (!p.latitude.isFinite || !p.longitude.isFinite ||
        p.latitude < -90 || p.latitude > 90 ||
        p.longitude < -180 || p.longitude > 180) return;
    if (!p.accuracy.isFinite || p.accuracy < 0 || p.accuracy > 80) return;
    if (p.timestamp.isAfter(now.add(const Duration(minutes: 1))) ||
        now.difference(p.timestamp) > const Duration(minutes: 2)) return;
    if (p.speed.isFinite && p.speed > 8) return;
    if (!hasPermission(FunctionPermission.editProgram)) return;
    final teamId = me.teamId;
    if (teamId == null || teamId.isEmpty || !canEditTeam(teamId)) return;

    await _maybeAutoCloseResolvedSchedules(workDate);

    final active = schedules.where((s) => s.teamId == teamId && sameDay(s.date, workDate) && s.started && !s.closed && !s.paused && !s.postponed).toList();
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
    final candidates = <(ScheduleItem, Location, double)>[];
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
      // GPS-ul cu eroare mare nu trebuie să declanșeze promptul la marginea razei.
      // Cerem ca distanța + eroarea estimată să rămână în raza de 250 m.
      if (meters + p.accuracy <= 250) candidates.add((item, loc, meters));
    }
    if (candidates.isEmpty) {
      _autoInsideSince.clear();
      _arrivalSnoozedUntil.clear();
      _arrivalPromptCounts.clear();
      _automationNotified.removeWhere((key) => key.startsWith('arrival_'));
      return;
    }

    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    final item = candidates.first.$1;
    final meters = candidates.first.$3;
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
    if (existing?.status == WorkAttemptStatus.running || existing?.status == WorkAttemptStatus.waitingAccess || existing?.completed == true) return;
    final started = CentralizerRecord(
      id: existing?.id ?? idNow(), teamId: teamId, locationId: item.locationId, type: item.typeSnapshot,
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
    if (existing?.status == WorkAttemptStatus.running || existing?.status == WorkAttemptStatus.waitingAccess || existing?.completed == true) return;
    final waiting = CentralizerRecord(
      id: existing?.id ?? idNow(), teamId: teamId, locationId: item.locationId, type: item.typeSnapshot,
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

  List<Location> _seedLocations() {
    return [
      // MAGIC — toate cele 36 de locații din ANEXA MAGIC FEBR.
      Location(id:'magic01',name:'MAGIC Alexandria',address:'Jud. Teleorman, Mun. Alexandria, Str. București, Bl. G103, parter',type:LocationType.magic,notes:'Anexa indică aproximativ 45–50 mp; tipul suprafeței nu este precizat explicit.'),
      Location(id:'magic02',name:'MAGIC Brăila',address:'Jud. Brăila, Mun. Brăila, Str. Școlilor, nr. 52, bl. 15, parter',type:LocationType.magic,surfaceM2:133,facadeM2:264),
      Location(id:'magic03',name:'MAGIC Brăila 2',address:'Jud. Brăila, Mun. Brăila, Calea Călărașilor, nr. 55, bl. 11, parter',type:LocationType.magic,surfaceM2:212,facadeM2:168),
      Location(id:'magic04',name:'MAGIC Brăila 3',address:'Jud. Brăila, Mun. Brăila, Dorobanților, parter',type:LocationType.magic,surfaceM2:92,facadeM2:112),
      Location(id:'magic05',name:'MAGIC Buzău',address:'Jud. Buzău, Mun. Buzău, Bd. Unirii, bl. 18D',type:LocationType.magic,surfaceM2:168,facadeM2:15),
      Location(id:'magic06',name:'MAGIC Buzău 2',address:'Buzău, Str. 1 Decembrie 1918',type:LocationType.magic,facadeM2:5),
      Location(id:'magic07',name:'MAGIC Sălăjan',address:'București, Bd. N. Grigorescu nr. 51A, clădirea C1, Sector 3',type:LocationType.magic,surfaceM2:200,facadeM2:75),
      Location(id:'magic08',name:'MAGIC Octavian Goga',address:'București, Sector 3, Bd. Octavian Goga nr. 22, Tronson I, Magazin 1, parter',type:LocationType.magic,surfaceM2:107,facadeM2:140),
      Location(id:'magic09',name:'MAGIC Herăstrău',address:'București, Sector 1, Str. Nicolae G. Caramfil nr. 4',type:LocationType.magic,facadeM2:250),
      Location(id:'magic10',name:'MAGIC Theodor Pallady',address:'București, Str. Victor Brauner nr. 29 (Theodor Pallady)',type:LocationType.magic,facadeM2:150),
      Location(id:'magic11',name:'MAGIC Giurgiului',address:'București, Sector 4, Șos. Giurgiului nr. 121, bl. 5, parter',type:LocationType.magic,facadeM2:60),
      Location(id:'magic12',name:'MAGIC Popești-Leordeni',address:'Popești-Leordeni, Str. Amurgului nr. 34',type:LocationType.magic,surfaceM2:58),
      Location(id:'magic13',name:'MAGIC Bragadiru',address:'Jud. Ilfov, Bragadiru, Str. Cristalului nr. 1',type:LocationType.magic,facadeM2:50),
      Location(id:'magic14',name:'MAGIC Otopeni',address:'Jud. Ilfov, Otopeni, Str. 23 August nr. 204',type:LocationType.magic,facadeM2:60),
      Location(id:'magic15',name:'MAGIC Colentina',address:'București, Str. Colentina nr. 76',type:LocationType.magic,facadeM2:60),
      Location(id:'magic16',name:'MAGIC Prosper',address:'București, 13 Septembrie nr. 221 (Prosper)',type:LocationType.magic,facadeM2:60),
      Location(id:'magic17',name:'MAGIC Andronache',address:'București, Colentina nr. 261 (Andronache)',type:LocationType.magic,facadeM2:95),
      Location(id:'magic18',name:'MAGIC Constanța',address:'Jud. Constanța, Mun. Constanța, Bd. 1 Decembrie 1918 nr. 43, bl. L24',type:LocationType.magic,facadeM2:150),
      Location(id:'magic19',name:'MAGIC Reșița',address:'Jud. Caraș-Severin, Mun. Reșița, Bd. Republicii nr. 24',type:LocationType.magic,surfaceM2:101,facadeM2:15),
      Location(id:'magic20',name:'MAGIC Reșița 2',address:'Jud. Caraș-Severin, Mun. Reșița, Bd. Republicii nr. 13',type:LocationType.magic,surfaceM2:79,facadeM2:20),
      Location(id:'magic21',name:'MAGIC Reșița 3',address:'Jud. Caraș-Severin, Mun. Reșița, Str. Ion Luca Caragiale nr. 1',type:LocationType.magic,facadeM2:20),
      Location(id:'magic22',name:'MAGIC Drobeta Turnu Severin',address:'Jud. Mehedinți, Drobeta Turnu Severin, Bd. Tudor Vladimirescu nr. 130, bl. IS3A, parter',type:LocationType.magic,surfaceM2:109,facadeM2:10),
      Location(id:'magic23',name:'MAGIC Focșani',address:'Jud. Vrancea, Mun. Focșani, Bd. Brăilei nr. 102, unitatea GF08',type:LocationType.magic,facadeM2:20),
      Location(id:'magic24',name:'MAGIC Galați',address:'Jud. Galați, Mun. Galați, Bd. George Coșbuc nr. 2, parter hotel',type:LocationType.magic,facadeM2:544),
      Location(id:'magic25',name:'MAGIC Hunedoara',address:'Jud. Hunedoara, Mun. Hunedoara, Bd. Dacia nr. 6 Bis',type:LocationType.magic,facadeM2:10),
      Location(id:'magic26',name:'MAGIC Lugoj',address:'Jud. Timiș, Mun. Lugoj, Str. Bucegi nr. 28',type:LocationType.magic,facadeM2:30),
      Location(id:'magic27',name:'MAGIC Lugoj 2',address:'Jud. Timiș, Mun. Lugoj, Str. Huniade nr. 5',type:LocationType.magic,surfaceM2:40,facadeM2:25),
      Location(id:'magic28',name:'MAGIC Ploiești',address:'Ploiești, Șoseaua Nordului nr. 1',type:LocationType.magic,surfaceM2:200),
      Location(id:'magic29',name:'MAGIC Slobozia 2',address:'Jud. Ialomița, Mun. Slobozia, Bd. Matei Basarab, bl. 35, sc. A',type:LocationType.magic,surfaceM2:240,facadeM2:130),
      Location(id:'magic30',name:'MAGIC Sfântu Gheorghe',address:'Jud. Covasna, Mun. Sfântu Gheorghe, Str. Nicolae Iorga nr. 61, bl. 10, sc. E/A',type:LocationType.magic,facadeM2:38),
      Location(id:'magic31',name:'MAGIC Sibiu Gara',address:'Sibiu, Piața 1 Decembrie 1918 (în gară)',type:LocationType.magic),
      Location(id:'magic32',name:'MAGIC Târgu Jiu',address:'Jud. Gorj, Mun. Târgu Jiu, Str. Victoriei, bl. 35, sc. 1, parter',type:LocationType.magic,facadeM2:55),
      Location(id:'magic33',name:'MAGIC Sediu București',address:'București, Calea Floreasca nr. 55',type:LocationType.magic,surfaceM2:334),
      Location(id:'magic34',name:'MAGIC Slatina',address:'Slatina, Bd. Alexandru Ioan Cuza nr. 9',type:LocationType.magic,facadeM2:100),
      Location(id:'magic35',name:'MAGIC Constanța Mamaia',address:'Constanța, Bd. Mamaia nr. 264',type:LocationType.magic,surfaceM2:350,notes:'Anexa indică 350 mp fără separare mochetă/fațadă'),
      Location(id:'magic36',name:'MAGIC Constanța Traian',address:'Constanța, Str. Traian nr. 62',type:LocationType.magic,surfaceM2:425,notes:'Anexa indică 425 mp fără separare mochetă/fațadă'),
      // MILLION — toate cele 67 de locații din ANEXE LUNARE- MILION.pdf
      Location(id:'million01',name:'Ard:Revolutiei_83',address:'Ard:Revolutiei_83',type:LocationType.million,surfaceM2:127,notes:'Anexa: 301 mp total, 127 mp parțial.',contacts:[LocationContact(name:'KARINA RACZ',phone:'0755831706')]),
      Location(id:'million02',name:'Bac:CaleaRepublicii_181',address:'Bac:CaleaRepublicii_181',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRU ANDRIAN',phone:'0733330524')]),
      Location(id:'million03',name:'Bac:MihaiViteazu_2-4',address:'Bac:MihaiViteazu_2-4',type:LocationType.million,surfaceM2:161,contacts:[LocationContact(name:'MUTU IULIANA',phone:'0730076826')]),
      Location(id:'million04',name:'Bam:Republicii_14A',address:'Bam:Republicii_14A',type:LocationType.million,surfaceM2:163,contacts:[LocationContact(name:'DIANA CIMPAN',phone:'0732650525')]),
      Location(id:'million05',name:'Bam:Unirii 12',address:'Bam:Unirii 12',type:LocationType.million,surfaceM2:102,contacts:[LocationContact(name:'DIANA DURIJAN',phone:'0730899364')]),
      Location(id:'million06',name:'Bra:NicolaeBalcescu 68',address:'Bra:NicolaeBalcescu 68',type:LocationType.million,surfaceM2:89,contacts:[LocationContact(name:'MARIA HERMECZI',phone:'0748685308')]),
      Location(id:'million07',name:'Brl:Calea_Calarasilor_66',address:'Brl:Calea_Calarasilor_66',type:LocationType.million,contacts:[LocationContact(name:'COSMINA NEDELCU',phone:'0755365479')]),
      Location(id:'million08',name:'Brl:Eminescu_59',address:'Brl:Eminescu_59',type:LocationType.million,contacts:[LocationContact(name:'ADRIAN GRIGORE',phone:'0723629259')]),
      Location(id:'million09',name:'Braila 3',address:'Braila 3',type:LocationType.million,facadeM2:250,notes:'Anexa menționează fațadă 250 m².'),
      Location(id:'million10',name:'Buz:Unirii 232',address:'Buz:Unirii 232',type:LocationType.million,surfaceM2:475),
      Location(id:'million11',name:'Car:MihaiViteazul',address:'Car:MihaiViteazul',type:LocationType.million,surfaceM2:151,contacts:[LocationContact(name:'NICOLAE ARMAS',phone:'0790052585'),LocationContact(name:'CRISTINA COVACIU',phone:'0731014101')]),
      Location(id:'million12',name:'Crv:Calea_Bucuresti_80',address:'Crv:Calea_Bucuresti_80',type:LocationType.million,surfaceM2:439,notes:'Anexa menționează separat terasă 49,6 m².',contacts:[LocationContact(name:'LOREDANA ZANFIRACHE',phone:'0765177503')]),
      Location(id:'million13',name:'Crv:CaleaBucuresti_18',address:'Crv:CaleaBucuresti_18',type:LocationType.million,surfaceM2:199,contacts:[LocationContact(name:'TOMINA CALIN',phone:'0732650506')]),
      Location(id:'million14',name:'Crv:IonMaiorescu_nr.3',address:'Crv:IonMaiorescu_nr.3',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA DRAGHICI',phone:'0760188002')]),
      Location(id:'million15',name:'Crv:PiataGarii - Daciei',address:'Crv:PiataGarii - Daciei',type:LocationType.million,surfaceM2:159,contacts:[LocationContact(name:'EMILIA PUNCIOIU',phone:'0763014497')]),
      Location(id:'million16',name:'Craiova - George Enescu 76',address:'Craiova - George Enescu 76',type:LocationType.million,contacts:[LocationContact(name:'SIMONA BURDANGIU',phone:'0766905285')]),
      Location(id:'million17',name:'Craiova - Bd Oltenia nr 50',address:'Craiova - Bd Oltenia nr 50',type:LocationType.million,surfaceM2:72,contacts:[LocationContact(name:'CRISTINA NICU',phone:'0726736680')]),
      Location(id:'million18',name:'Craiova, bld Sarari /Henri Coanda',address:'Craiova, bld Sarari /Henri Coanda',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA NICA',phone:'0769393550')]),
      Location(id:'million19',name:'Craiova General Averescu',address:'Craiova General Averescu',type:LocationType.million,surfaceM2:90,contacts:[LocationContact(name:'ELENA OPREA',phone:'0763653557')]),
      Location(id:'million20',name:'Craiova, str Brazda Novac -Lamaitei',address:'Craiova, str Brazda Novac -Lamaitei',type:LocationType.million,contacts:[LocationContact(name:'EMILIAN STRECHE',phone:'0760870784')]),
      Location(id:'million21',name:'Craiova, 1 mai',address:'Craiova, 1 mai',type:LocationType.million,surfaceM2:106,contacts:[LocationContact(name:'ANDREEA BICU',phone:'0760712372')]),
      Location(id:'million22',name:'Craiova - George Enescu nr 100',address:'Craiova - George Enescu nr 100',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA DRAGHICI',phone:'0760188002')]),
      Location(id:'million23',name:'Ctn:1Decembrie_1918',address:'Ctn:1Decembrie_1918',type:LocationType.million,surfaceM2:135,contacts:[LocationContact(name:'IULIA NASTASE',phone:'0737587406')]),
      Location(id:'million24',name:'Ctn:Soveja',address:'Ctn:Soveja',type:LocationType.million,surfaceM2:140,notes:'Anexa: locația s-a mărit cu magazinul de încălțăminte.',contacts:[LocationContact(name:'ELENA CHIVU',phone:'0731610509')]),
      Location(id:'million25',name:'Ctn:Tomis 391',address:'Ctn:Tomis 391',type:LocationType.million,surfaceM2:205,contacts:[LocationContact(name:'OANA FODULU',phone:'0724970734')]),
      Location(id:'million26',name:'Ctn: Dezrobirii, nr 143',address:'Ctn: Dezrobirii, nr 143',type:LocationType.million,surfaceM2:115,contacts:[LocationContact(name:'CRISTINA BOTOSENCU',phone:'0747925278')]),
      Location(id:'million27',name:'Cta Navodari',address:'Cta Navodari',type:LocationType.million,surfaceM2:74,contacts:[LocationContact(name:'FLORENTINA PANDELE',phone:'0784292802')]),
      Location(id:'million28',name:'Foc:CaleaMoldovei_32',address:'Foc:CaleaMoldovei_32',type:LocationType.million,surfaceM2:107,contacts:[LocationContact(name:'BOGDAN CHIRIAC',phone:'0730025129')]),
      Location(id:'million29',name:'Foc:Brailei_102',address:'Foc:Brailei_102',type:LocationType.million,contacts:[LocationContact(name:'NISAN PERINDAG',phone:'0732650523')]),
      Location(id:'million30',name:'Foc:Unirii_14',address:'Foc:Unirii_14',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA IOSIF',phone:'0731036859')]),
      Location(id:'million31',name:'Foc:Unirii_65',address:'Foc:Unirii_65',type:LocationType.million,contacts:[LocationContact(name:'OVIDIU VATASOIU',phone:'0728977321'),LocationContact(name:'NICOLETA URZICA',phone:'0728398423')]),
      Location(id:'million32',name:'Ias:Anastasie_Panu_31',address:'Ias:Anastasie_Panu_31',type:LocationType.million,contacts:[LocationContact(name:'LAURA LEFTER',phone:'0725795603')]),
      Location(id:'million33',name:'Ias:TudorVladimirescu',address:'Ias:TudorVladimirescu',type:LocationType.million,surfaceM2:457,contacts:[LocationContact(name:'ANDREEA CALIMAN',phone:'0734010791'),LocationContact(name:'ELENA GRASU',phone:'0738099719'),LocationContact(name:'ANDREEA SULUGIUC',phone:'0739935667'),LocationContact(name:'LAVINIA GRADINARIU',phone:'0735784696'),LocationContact(name:'ROXANA HUJA',phone:'0725054453')]),
      Location(id:'million34',name:'Oradea , str Transilvaniei nr 24',address:'Oradea , str Transilvaniei nr 24',type:LocationType.million,contacts:[LocationContact(name:'ALEXANDRA SANDOR',phone:'0758044994')]),
      Location(id:'million35',name:'Pit:MaiorSantu_D2',address:'Pit:MaiorSantu_D2',type:LocationType.million,surfaceM2:139,contacts:[LocationContact(name:'SANDRA STANCESCU',phone:'0741438284')]),
      Location(id:'million36',name:'Plo:Republicii_17-25-1',address:'Plo:Republicii_17-25-1',type:LocationType.million,surfaceM2:154,contacts:[LocationContact(name:'STEFAN BAILESCU',phone:'0769398966')]),
      Location(id:'million37',name:'Plo:Nordului_1A',address:'Plo:Nordului_1A',type:LocationType.million,surfaceM2:294,contacts:[LocationContact(name:'TUDOR GAVRILOIU',phone:'0724107970'),LocationContact(name:'GEORGIANA CISMARU',phone:'0721356133')]),
      Location(id:'million38',name:'Rmv:ReginaMaria_4',address:'Rmv:ReginaMaria_4',type:LocationType.million,surfaceM2:351,contacts:[LocationContact(name:'GEORGE NICOLAE',phone:'0724220687'),LocationContact(name:'DIANA DUMITRA',phone:'0766643255')]),
      Location(id:'million39',name:'Rmv:MateiBasarab_1',address:'Rmv:MateiBasarab_1',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA DRAGOMIR',phone:'0765058278')]),
      Location(id:'million40',name:'Rmv:Tineretului',address:'Rmv:Tineretului',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA MIJA',phone:'0756623935')]),
      Location(id:'million41',name:'Rmv:Rapsodiei_19',address:'Rmv:Rapsodiei_19',type:LocationType.million,contacts:[LocationContact(name:'ANA MARIA CIOCHINA',phone:'0742898106')]),
      Location(id:'million42',name:'Sgm:1Decembrie1918',address:'Sgm:1Decembrie1918',type:LocationType.million,surfaceM2:93,contacts:[LocationContact(name:'ANAMARIA AILOAIE',phone:'0733330490')]),
      Location(id:'million43',name:'Sgm:Cuza Voda',address:'Sgm:Cuza Voda',type:LocationType.million,surfaceM2:75,contacts:[LocationContact(name:'STEFANIA ILES',phone:'0734703667')]),
      Location(id:'million44',name:'Slo:MateiBasarab_K1',address:'Slo:MateiBasarab_K1',type:LocationType.million,contacts:[LocationContact(name:'MADALINA PRELIPCEAN',phone:'0735787761')]),
      Location(id:'million45',name:'Sib:Shopping_City',address:'Sib:Shopping_City / Selimbar',type:LocationType.million,surfaceM2:150,contacts:[LocationContact(name:'VIOLETA TUDOR',phone:'0752549262')]),
      Location(id:'million46',name:'Sib:Promenada',address:'Sib:Promenada',type:LocationType.million,contacts:[LocationContact(name:'LAVINIA VATAU',phone:'0768999793')]),
      Location(id:'million47',name:'Stm:AlexandruIoanCuza 2',address:'Stm:AlexandruIoanCuza 2',type:LocationType.million,contacts:[LocationContact(name:'ANDREEA TULIAN',phone:'0750824911')]),
      Location(id:'million48',name:'Stm:Careiului 17',address:'Stm:Careiului 17',type:LocationType.million,contacts:[LocationContact(name:'ONDINA PRINTI',phone:'0752661435'),LocationContact(name:'ALEXANDRA SZARAZ',phone:'0771041469'),LocationContact(name:'VANESSA POP',phone:'0745345380')]),
      Location(id:'million49',name:'Stm:Independentei 53',address:'Stm:Independentei 53',type:LocationType.million,surfaceM2:51,contacts:[LocationContact(name:'HENRIETTA BARTHA',phone:'0751243463')]),
      Location(id:'million50',name:'Sf Gheorghe, str Lunca Oltului nr 46',address:'Sf Gheorghe, str Lunca Oltului nr 46',type:LocationType.million,contacts:[LocationContact(name:'ANA MARIA TREFAN',phone:'0733560824')]),
      Location(id:'million51',name:'Tgj:Eroilor_nr.6',address:'Tgj:Eroilor_nr.6',type:LocationType.million,surfaceM2:300,contacts:[LocationContact(name:'IRINEL MALAESCU',phone:'0732650510'),LocationContact(name:'PREDOI IONELA',phone:'0764286861')]),
      Location(id:'million52',name:'Tgj:9Mai',address:'Tgj:9Mai',type:LocationType.million,contacts:[LocationContact(name:'RALUCA CALINA',phone:'0742891086')]),
      Location(id:'million53',name:'Tgv:ConstantinBrancoveanu_58',address:'Tgv:ConstantinBrancoveanu_58',type:LocationType.million,surfaceM2:90,contacts:[LocationContact(name:'NICOLETA MIHALCIOIU',phone:'0766644272')]),
      Location(id:'million54',name:'Tgv:Independentei_O2 (Nicolae Radian)',address:'Tgv:Independentei_O2 (Nicolae Radian)',type:LocationType.million,surfaceM2:148,contacts:[LocationContact(name:'MARIUS RADU',phone:'0730015087'),LocationContact(name:'GABRIELA NICOLAE',phone:'0724641567')]),
      Location(id:'million55',name:'Tgv:Dambovita_Mall',address:'Tgv:Dambovita_Mall',type:LocationType.million,surfaceM2:279,contacts:[LocationContact(name:'ALEXANDRU ANGHEL',phone:'0732890921')]),
      Location(id:'million56',name:'Targoviste 4 (unirii nr 60 )',address:'Targoviste 4 (unirii nr 60 )',type:LocationType.million,contacts:[LocationContact(name:'GINA PANAIT',phone:'0731810865')]),
      Location(id:'million57',name:'Tim:PiataMarasti_nr.1-2',address:'Tim:PiataMarasti_nr.1-2',type:LocationType.million,contacts:[LocationContact(name:'GIORGIANA STANCIU',phone:'0747568526')]),
      Location(id:'million58',name:'Bucuresti- Octavian Goga',address:'Bucuresti- Octavian Goga',type:LocationType.million,contacts:[LocationContact(name:'CLAUDIA PARASCHIV',phone:'0730233505')]),
      Location(id:'million59',name:'Bucuresti- Decebal',address:'Bucuresti- Decebal',type:LocationType.million,surfaceM2:200,contacts:[LocationContact(name:'IONELA CIMPOERU',phone:'0720058965')]),
      Location(id:'million60',name:'Bucuresti- Crangasi',address:'Bucuresti- Crangasi',type:LocationType.million,contacts:[LocationContact(name:'ANAMARIA NANCY',phone:'0734200358')]),
      Location(id:'million61',name:'Bucuresti - Ctin Brancoveanu',address:'Bucuresti - Ctin Brancoveanu',type:LocationType.million,surfaceM2:70,contacts:[LocationContact(name:'RADU LUMINITA',phone:'0730531020')]),
      Location(id:'million62',name:'Bucuresti - 13 septembrie',address:'Bucuresti - 13 septembrie',type:LocationType.million,surfaceM2:80,contacts:[LocationContact(name:'ISABELA TUDORA',phone:'0766748597')]),
      Location(id:'million63',name:'Slatina',address:'Slatina',type:LocationType.million,contacts:[LocationContact(name:'ALECSANDRA BOGHEANU',phone:'0757176083')]),
      Location(id:'million64',name:'Bucuresti bld Drumul Taberei',address:'Bucuresti bld Drumul Taberei',type:LocationType.million,contacts:[LocationContact(name:'IONUT ALEXANDRU',phone:'0733330487')]),
      Location(id:'million65',name:'Sibiu Str Lunga',address:'Sibiu Str Lunga',type:LocationType.million,contacts:[LocationContact(name:'MARIA MALAI',phone:'0743354536')]),
      Location(id:'million66',name:'Ploiesti Veronica Micle',address:'Ploiesti Veronica Micle',type:LocationType.million,contacts:[LocationContact(name:'ANDREI CISMARU',phone:'0739935665')]),
      Location(id:'million67',name:'Piata Victoriei Ploiesti',address:'Piata Victoriei Ploiesti',type:LocationType.million,contacts:[LocationContact(name:'MIHAELA STOICA',phone:'0799923020')]),
    ];
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

  Map<String, dynamic> _locationMap(Location l) => {
    'name': l.name,
    'address': l.address,
    'type': l.type.name,
    'categoryId': l.categoryId,
    'status': l.status.name,
    'latitude': l.latitude,
    'longitude': l.longitude,
    'phone': l.phone,
    'contacts': l.contacts.map((c) => {'name': c.name, 'phone': c.phone, 'role': c.role, 'smsEnabled': c.smsEnabled}).toList(),
    'surfaceM2': l.surfaceM2,
    'facadeM2': l.facadeM2,
    'notes': l.notes,
    'active': l.active,
  };

  Location _locationFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    LocationType type = LocationType.million;
    final typeText = (d['type'] ?? 'million').toString();
    for (final item in LocationType.values) {
      if (item.name == typeText) type = item;
    }
    final rawContacts = d['contacts'];
    final contacts = <LocationContact>[];
    if (rawContacts is List) {
      for (final item in rawContacts) {
        if (item is Map) {
          contacts.add(LocationContact(
            name: (item['name'] ?? '').toString(),
            phone: (item['phone'] ?? '').toString(),
            role: (item['role'] ?? 'Manager').toString(),
            smsEnabled: item['smsEnabled'] != false,
          ));
        }
      }
    }
    double? numberOrNull(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }
    var status = LocationStatus.open;
    final statusText = (d['status'] ?? (d['active'] == false ? 'permanentlyClosed' : 'open')).toString();
    for (final value in LocationStatus.values) {
      if (value.name == statusText) status = value;
    }
    final categoryId = (d['categoryId'] ?? defaultCategoryIdForType(type)).toString();
    return Location(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      address: (d['address'] ?? '').toString(),
      type: type,
      categoryId: categoryId,
      status: status,
      latitude: numberOrNull(d['latitude']),
      longitude: numberOrNull(d['longitude']),
      phone: d['phone']?.toString(),
      contacts: contacts,
      surfaceM2: numberOrNull(d['surfaceM2']) ?? 0,
      facadeM2: numberOrNull(d['facadeM2']) ?? 0,
      notes: (d['notes'] ?? '').toString(),
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _categoryMap(LocationCategory c) => {
    'name': c.name,
    'colorValue': c.colorValue,
    'active': c.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  LocationCategory _categoryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return LocationCategory(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      colorValue: d['colorValue'] is num ? (d['colorValue'] as num).toInt() : int.tryParse('${d['colorValue']}') ?? Colors.blueGrey.value,
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _functionMap(FunctionDefinition f) => {
    'name': f.name,
    'iconKey': f.iconKey,
    'badgeKeys': f.badgeKeys,
    'colorValue': f.colorValue,
    'permissions': f.permissions.toList()..sort(),
    'active': f.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  FunctionDefinition _functionFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final raw = d['permissions'];
    final rawIconKey = (d['iconKey'] ?? 'badge_driver').toString();
    final iconKey = rawIconKey == 'badge_coordinator' || rawIconKey == 'badge_machine' ? 'badge_worker' : rawIconKey;
    final badgeKeys = (d['badgeKeys'] is List
        ? (d['badgeKeys'] as List).map((e) => e.toString())
        : <String>[iconKey])
      .where((e) => e.isNotEmpty && e != 'badge_coordinator')
      .map((e) => e == 'badge_machine' ? 'badge_worker' : e)
      .toSet()
      .take(3)
      .toList();
    if (badgeKeys.isEmpty) badgeKeys.add(iconKey);
    return FunctionDefinition(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      iconKey: iconKey,
      badgeKeys: badgeKeys,
      colorValue: d['colorValue'] is num ? (d['colorValue'] as num).toInt() : int.tryParse('${d['colorValue']}') ?? Colors.blueGrey.value,
      permissions: raw is List ? raw.map((e) => e.toString()).toSet() : <String>{},
      active: d['active'] != false,
    );
  }

  Map<String, dynamic> _teamMap(Team t) => {
    'name': t.name,
    'members': t.members,
    'carId': t.carId,
    'financialManagerId': t.financialManagerId,
    'active': t.active,
  };

  Team _teamFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final raw = d['members'];
    return Team(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      members: raw is List ? raw.map((e) => e.toString()).toList() : <String>[],
      carId: d['carId']?.toString(),
      financialManagerId: d['financialManagerId']?.toString(),
      active: d['active'] != false,
    );
  }

  String? _dateString(DateTime? d) => d?.toIso8601String();

  DateTime? _dateFrom(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> _carMap(Car c) => {
    'plate': c.plate,
    'makeModel': c.makeModel,
    'active': c.active,
    'rcaUntil': _dateString(c.rcaUntil),
    'itpUntil': _dateString(c.itpUntil),
    'rovinietaUntil': _dateString(c.rovinietaUntil),
    'averageConsumption': c.averageConsumption,
    'fuelPricePerLiter': c.fuelPricePerLiter,
    'fuelType': c.fuelType,
  };

  Car _carFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Car(
      id: doc.id,
      plate: (d['plate'] ?? '').toString(),
      makeModel: (d['makeModel'] ?? '').toString(),
      active: d['active'] != false,
      rcaUntil: _dateFrom(d['rcaUntil']),
      itpUntil: _dateFrom(d['itpUntil']),
      rovinietaUntil: _dateFrom(d['rovinietaUntil']),
      averageConsumption: (d['averageConsumption'] is num) ? (d['averageConsumption'] as num).toDouble() : 0,
      fuelPricePerLiter: (d['fuelPricePerLiter'] is num) ? (d['fuelPricePerLiter'] as num).toDouble() : 0,
      fuelType: (d['fuelType'] ?? 'Motorină').toString(),
    );
  }

  Map<String, dynamic> _scheduleMap(WorkSchedule s) => {
    'teamId': s.teamId,
    'graphId': s.graphId,
    'graphName': s.graphName,
    'date': Timestamp.fromDate(s.date),
    'active': s.active,
    'closed': s.closed,
    'started': s.started,
    'paused': s.paused,
    'postponed': s.postponed,
    'autoProposed': s.autoProposed,
    'planAlertAt': s.planAlertAt == null ? null : Timestamp.fromDate(s.planAlertAt!),
    'planAlertReason': s.planAlertReason,
    'lastRecalculatedAt': s.lastRecalculatedAt == null ? null : Timestamp.fromDate(s.lastRecalculatedAt!),
    'recalculationCount': s.recalculationCount,
    'learningExplanation': s.learningExplanation,
    'learningConfidence': s.learningConfidence,
    'learningSamples': s.learningSamples,
    'departureName': s.departureName,
    'departureLatitude': s.departureLatitude,
    'departureLongitude': s.departureLongitude,
    'returnName': s.returnName,
    'returnLatitude': s.returnLatitude,
    'returnLongitude': s.returnLongitude,
    'items': s.items.map((i) => {
      'locationId': i.locationId,
      'locationNameSnapshot': i.locationNameSnapshot,
      'addressSnapshot': i.addressSnapshot,
      'typeSnapshot': i.typeSnapshot.name,
      'categoryIdSnapshot': i.categoryIdSnapshot,
      'order': i.order,
      'transferred': i.transferred,
      'facadePlanned': i.facadePlanned,
    }).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  WorkSchedule _scheduleFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final rawItems = d['items'];
    final items = <ScheduleItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        var type = LocationType.million;
        final typeText = (raw['typeSnapshot'] ?? 'million').toString();
        for (final value in LocationType.values) {
          if (value.name == typeText) type = value;
        }
        items.add(ScheduleItem(
          locationId: (raw['locationId'] ?? '').toString(),
          locationNameSnapshot: (raw['locationNameSnapshot'] ?? '').toString(),
          addressSnapshot: (raw['addressSnapshot'] ?? '').toString(),
          typeSnapshot: type,
          categoryIdSnapshot: (raw['categoryIdSnapshot'] ?? defaultCategoryIdForType(type)).toString(),
          order: raw['order'] is num ? (raw['order'] as num).toInt() : int.tryParse('${raw['order']}') ?? 0,
          transferred: raw['transferred'] == true,
          facadePlanned: raw['facadePlanned'] == true,
        ));
      }
    }
    items.sort((a, b) => a.order.compareTo(b.order));
    return WorkSchedule(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      graphId: (d['graphId'] ?? '').toString().trim().isNotEmpty
          ? (d['graphId'] ?? '').toString()
          : 'legacy_${(d['teamId'] ?? '').toString()}_${(_dateFrom(d['date']) ?? DateTime.now()).year}_${(_dateFrom(d['date']) ?? DateTime.now()).month.toString().padLeft(2, '0')}',
      graphName: (d['graphName'] ?? '').toString().trim().isNotEmpty
          ? (d['graphName'] ?? '').toString()
          : graphDefaultName(_dateFrom(d['date']) ?? DateTime.now()),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      items: items,
      active: d['active'] != false,
      closed: d['closed'] == true,
      started: d['started'] == true,
      paused: d['paused'] == true,
      postponed: d['postponed'] == true,
      autoProposed: d['autoProposed'] == true,
      planAlertAt: _dateFrom(d['planAlertAt']),
      planAlertReason: (d['planAlertReason'] ?? '').toString(),
      lastRecalculatedAt: _dateFrom(d['lastRecalculatedAt']),
      recalculationCount: d['recalculationCount'] is num ? (d['recalculationCount'] as num).toInt() : int.tryParse('${d['recalculationCount']}') ?? 0,
      learningExplanation: (d['learningExplanation'] ?? '').toString(),
      learningConfidence: d['learningConfidence'] is num ? (d['learningConfidence'] as num).toDouble() : 0,
      learningSamples: d['learningSamples'] is num ? (d['learningSamples'] as num).toInt() : 0,
      departureName: (d['departureName'] ?? '').toString(),
      departureLatitude: d['departureLatitude'] is num ? (d['departureLatitude'] as num).toDouble() : null,
      departureLongitude: d['departureLongitude'] is num ? (d['departureLongitude'] as num).toDouble() : null,
      returnName: (d['returnName'] ?? '').toString(),
      returnLatitude: d['returnLatitude'] is num ? (d['returnLatitude'] as num).toDouble() : null,
      returnLongitude: d['returnLongitude'] is num ? (d['returnLongitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> _recordMap(CentralizerRecord r) => {
    'teamId': r.teamId,
    'locationId': r.locationId,
    'type': r.type.name,
    'locationNameSnapshot': r.locationNameSnapshot,
    'addressSnapshot': r.addressSnapshot,
    'waitingStartedAt': r.waitingStartedAt == null ? null : Timestamp.fromDate(r.waitingStartedAt!),
    'waitingEndedAt': r.waitingEndedAt == null ? null : Timestamp.fromDate(r.waitingEndedAt!),
    'startedAt': r.startedAt == null ? null : Timestamp.fromDate(r.startedAt!),
    'finishedAt': r.finishedAt == null ? null : Timestamp.fromDate(r.finishedAt!),
    'status': r.status.name,
    'refusalReason': r.refusalReason,
    'keptForLearning': r.keptForLearning,
    'facadePlanned': r.facadePlanned,
    'facadeDone': r.facadeDone,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  CentralizerRecord _recordFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var type = LocationType.million;
    for (final value in LocationType.values) {
      if (value.name == (d['type'] ?? 'million').toString()) type = value;
    }
    var status = WorkAttemptStatus.waitingAccess;
    for (final value in WorkAttemptStatus.values) {
      if (value.name == (d['status'] ?? 'waitingAccess').toString()) status = value;
    }
    return CentralizerRecord(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      locationId: (d['locationId'] ?? '').toString(),
      type: type,
      locationNameSnapshot: (d['locationNameSnapshot'] ?? '').toString(),
      addressSnapshot: (d['addressSnapshot'] ?? '').toString(),
      waitingStartedAt: _dateFrom(d['waitingStartedAt']),
      waitingEndedAt: _dateFrom(d['waitingEndedAt']),
      startedAt: _dateFrom(d['startedAt']),
      finishedAt: _dateFrom(d['finishedAt']),
      status: status,
      refusalReason: d['refusalReason']?.toString(),
      keptForLearning: d['keptForLearning'] != false,
      facadePlanned: d['facadePlanned'] == true,
      facadeDone: d['facadeDone'] == true,
    );
  }

  Map<String, dynamic> _notificationMap(AppNotification n) => {
    'userId': n.userId,
    'title': n.title,
    'message': n.message,
    'createdAt': Timestamp.fromDate(n.createdAt),
    'read': n.read,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  AppNotification _notificationFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AppNotification(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      createdAt: _dateFrom(d['createdAt']) ?? DateTime.now(),
      read: d['read'] == true,
    );
  }

  double _doubleFrom(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _expenseMap(Expense e) => {
    'teamId': e.teamId,
    'settlementId': e.settlementId,
    'category': e.category,
    'description': e.description,
    'amount': e.amount,
    'date': Timestamp.fromDate(e.date),
    'documentType': e.documentType.name,
    'documentNumber': e.documentNumber,
    'supplier': e.supplier,
    'liters': e.liters,
    'pricePerLiter': e.pricePerLiter,
    'documentImageBase64': e.documentImageBase64,
    'imageFingerprint': e.imageFingerprint,
    'ocrRawText': e.ocrRawText,
    'ocrConfidence': e.ocrConfidence,
    'confirmed': e.confirmed,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Expense _expenseFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var docType = ExpenseDocumentType.fiscalReceipt;
    for (final value in ExpenseDocumentType.values) {
      if (value.name == (d['documentType'] ?? '').toString()) docType = value;
    }
    return Expense(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      settlementId: d['settlementId']?.toString(),
      category: (d['category'] ?? 'Alte cheltuieli').toString(),
      description: (d['description'] ?? '').toString(),
      amount: _doubleFrom(d['amount']),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      documentType: docType,
      documentNumber: (d['documentNumber'] ?? '').toString(),
      supplier: (d['supplier'] ?? '').toString(),
      liters: d['liters'] == null ? null : _doubleFrom(d['liters']),
      pricePerLiter: d['pricePerLiter'] == null ? null : _doubleFrom(d['pricePerLiter']),
      documentImageBase64: (d['documentImageBase64'] ?? '').toString(),
      imageFingerprint: (d['imageFingerprint'] ?? '').toString(),
      ocrRawText: (d['ocrRawText'] ?? '').toString(),
      ocrConfidence: _doubleFrom(d['ocrConfidence']),
      confirmed: d['confirmed'] != false,
    );
  }

  Map<String, dynamic> _perDiemMap(PerDiemEntry d) => {
    'teamId': d.teamId,
    'settlementId': d.settlementId,
    'memberId': d.memberId,
    'date': Timestamp.fromDate(d.date),
    'amount': d.amount,
    'status': d.status.name,
    'method': d.method?.name,
    'distributedBy': d.distributedBy,
    'distributedAt': d.distributedAt == null ? null : Timestamp.fromDate(d.distributedAt!),
    'confirmedAt': d.confirmedAt == null ? null : Timestamp.fromDate(d.confirmedAt!),
    'received': d.received,
    'actualReceivedAmount': d.actualReceivedAmount,
    'supplementaryFor': d.supplementaryFor,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  PerDiemEntry _perDiemFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    var status = PerDiemStatus.notGranted;
    for (final value in PerDiemStatus.values) {
      if (value.name == (d['status'] ?? '').toString()) status = value;
    }
    PerDiemPaymentMethod? method;
    for (final value in PerDiemPaymentMethod.values) {
      if (value.name == (d['method'] ?? '').toString()) method = value;
    }
    return PerDiemEntry(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      settlementId: d['settlementId']?.toString(),
      memberId: (d['memberId'] ?? '').toString(),
      date: _dateFrom(d['date']) ?? DateTime.now(),
      amount: _doubleFrom(d['amount']),
      status: status,
      method: method,
      distributedBy: d['distributedBy']?.toString(),
      distributedAt: _dateFrom(d['distributedAt']),
      confirmedAt: _dateFrom(d['confirmedAt']),
      received: d['received'] is bool ? d['received'] as bool : null,
      actualReceivedAmount: d['actualReceivedAmount'] == null ? null : _doubleFrom(d['actualReceivedAmount']),
      supplementaryFor: d['supplementaryFor']?.toString(),
    );
  }

  Map<String, dynamic> _settlementMap(TravelSettlement s) => {
    'teamId': s.teamId,
    'name': s.name,
    'startDate': Timestamp.fromDate(s.startDate),
    'endDate': s.endDate == null ? null : Timestamp.fromDate(s.endDate!),
    'managerId': s.managerId,
    'receivedDeparture': s.departureTotal,
    'receivedDuring': s.duringTotal,
    'receivedEntries': s.receivedEntries.map((e)=>{
      'id': e.id, 'kind': e.kind, 'amount': e.amount, 'method': e.method, 'fromName': e.fromName, 'date': Timestamp.fromDate(e.date),
    }).toList(),
    'perDiemRate': s.perDiemRate,
    'closed': s.closed,
    'createdAt': Timestamp.fromDate(s.createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TravelSettlement _settlementFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final receivedEntries=<ReceivedMoneyEntry>[];
    final rawReceived=d['receivedEntries'];
    if(rawReceived is List){
      for(final raw in rawReceived){
        if(raw is! Map)continue;
        receivedEntries.add(ReceivedMoneyEntry(
          id:(raw['id']??idNow()).toString(),
          kind:(raw['kind']??'during').toString(),
          amount:_doubleFrom(raw['amount']),
          method:(raw['method']??'Cash').toString(),
          fromName:(raw['fromName']??'').toString(),
          date:_dateFrom(raw['date'])??DateTime.now(),
        ));
      }
    }
    return TravelSettlement(
      id: doc.id,
      teamId: (d['teamId'] ?? '').toString(),
      name: (d['name'] ?? 'Deplasare').toString(),
      startDate: _dateFrom(d['startDate']) ?? DateTime.now(),
      endDate: _dateFrom(d['endDate']),
      managerId: d['managerId']?.toString(),
      receivedDeparture: _doubleFrom(d['receivedDeparture']),
      receivedDuring: _doubleFrom(d['receivedDuring']),
      receivedEntries: receivedEntries,
      perDiemRate: _doubleFrom(d['perDiemRate'], settings.defaultPerDiem),
      closed: d['closed'] == true,
      createdAt: _dateFrom(d['createdAt']),
    );
  }

  Map<String, dynamic> _financeMap(TeamFinance f) => {
    'teamId': f.teamId,
    'managerId': f.managerId,
    'receivedDeparture': f.departureTotal,
    'receivedDuring': f.duringTotal,
    'receivedEntries': f.receivedEntries.map((e)=>{
      'id': e.id, 'kind': e.kind, 'amount': e.amount, 'method': e.method, 'fromName': e.fromName, 'date': Timestamp.fromDate(e.date),
    }).toList(),
    'perDiemRate': f.perDiemRate,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TeamFinance _financeFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final receivedEntries=<ReceivedMoneyEntry>[];
    final rawReceived=d['receivedEntries'];
    if(rawReceived is List){
      for(final raw in rawReceived){
        if(raw is! Map)continue;
        receivedEntries.add(ReceivedMoneyEntry(
          id:(raw['id']??idNow()).toString(),
          kind:(raw['kind']??'during').toString(),
          amount:_doubleFrom(raw['amount']),
          method:(raw['method']??'Cash').toString(),
          fromName:(raw['fromName']??'').toString(),
          date:_dateFrom(raw['date'])??DateTime.now(),
        ));
      }
    }
    return TeamFinance(
      teamId: doc.id,
      managerId: d['managerId']?.toString(),
      receivedDeparture: _doubleFrom(d['receivedDeparture']),
      receivedDuring: _doubleFrom(d['receivedDuring']),
      receivedEntries: receivedEntries,
      perDiemRate: _doubleFrom(d['perDiemRate'], settings.defaultPerDiem),
    );
  }

  String _encoded(Map<String, dynamic> value) => jsonEncode(value.map((key, value) {
    if (value is FieldValue) return MapEntry(key, '<serverTimestamp>');
    if (value is Timestamp) return MapEntry(key, value.toDate().toIso8601String());
    if (value is List) {
      return MapEntry(key, value.map((e) {
        if (e is Map) return e.map((k, v) => MapEntry(k.toString(), v is Timestamp ? v.toDate().toIso8601String() : v));
        return e;
      }).toList());
    }
    return MapEntry(key, value);
  }));

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

  void _startFinancialSync() {
    final canViewAll = isAdmin || hasPermission(FunctionPermission.viewOtherDecont);
    final scope = canViewAll ? '*' : me.teamId;
    if (_financialTeamScope == scope) return;
    _financialTeamScope = scope;
    for (final sub in _financialSubscriptions) { sub.cancel(); }
    _financialSubscriptions.clear();
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

  Future<void> _pruneOldNotifications() async {
    final db = FirebaseFirestore.instance;
    final cutoff = DateTime.now().subtract(Duration(days: settings.notificationHistoryDays.clamp(1, 365)));
    final old = await db.collection('notifications').where('createdAt', isLessThan: Timestamp.fromDate(cutoff)).get();
    WriteBatch batch = db.batch();
    var count = 0;
    for (final doc in old.docs) {
      batch.delete(doc.reference);
      count++;
      if (count >= 300) { await batch.commit(); batch = db.batch(); count = 0; }
    }
    if (count > 0) await batch.commit();
  }

  void _startCoreSync() {
    final db = FirebaseFirestore.instance;

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

    String visibleSenderName(Map<String, dynamic> data) {
      final senderId = (data['senderId'] ?? '').toString();
      if (!isAdmin && _hiddenUserIds.contains(senderId)) return 'Sistem';
      return (data['senderName'] ?? 'un membru').toString();
    }

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

    if (isAdmin) {
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
      unawaited(_seedLocationsIfNeeded());
      unawaited(_seedDefinitionsIfNeeded());
      unawaited(_migrateFunctionBadgeSystemIfNeeded());
    }
    _startFinancialSync();
  }

  Set<String> _effectivePermissionsForIds(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      final def = functionById(functionDefinitions, id);
      if (def != null && def.active) out.addAll(def.permissions);
    }
    return out;
  }

  Future<void> _syncUserPermissionSnapshots() async {
    if (!isAdmin || _permissionSyncInFlight || functionDefinitions.isEmpty) return;
    _permissionSyncInFlight = true;
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db.collection('users').get();
      final batch = db.batch();
      var writes = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final role = (d['role'] ?? 'member').toString();
        final functionIds = d['functionIds'] is List
            ? (d['functionIds'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
            : <String>[(role == 'admin' ? 'admin' : '').trim()].where((e) => e.isNotEmpty).toList();
        final effective = role == 'admin'
            ? FunctionPermission.values.map((e) => e.name).toSet()
            : _effectivePermissionsForIds(functionIds);
        final current = d['effectivePermissions'] is List
            ? (d['effectivePermissions'] as List).map((e) => e.toString()).toSet()
            : <String>{};
        if (current.length == effective.length && current.containsAll(effective)) continue;
        final sorted = effective.toList()..sort();
        batch.set(doc.reference, {
          'effectivePermissions': sorted,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        writes++;
      }
      if (writes > 0) await batch.commit();
    } catch (e) {
      if (mounted) setState(() => coreSyncError = 'Sincronizare drepturi: $e');
    } finally {
      _permissionSyncInFlight = false;
    }
  }

  Future<void> _seedLocationsIfNeeded() async {
    final col = FirebaseFirestore.instance.collection('locations');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final l in _seedLocations()) {
      batch.set(col.doc(l.id), _locationMap(l));
    }
    await batch.commit();
  }

  Future<void> _seedDefinitionsIfNeeded() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final categoriesCol = db.collection('locationCategories');
    final functionsCol = db.collection('functions');
    final existingCategories = await categoriesCol.limit(1).get();
    final existingFunctions = await functionsCol.limit(1).get();
    final batch = db.batch();
    var writes = 0;
    if (existingCategories.docs.isEmpty) {
      for (final c in defaultLocationCategories()) { batch.set(categoriesCol.doc(c.id), _categoryMap(c)); writes++; }
    }
    if (existingFunctions.docs.isEmpty) {
      for (final f in defaultFunctionDefinitions()) { batch.set(functionsCol.doc(f.id), _functionMap(f)); writes++; }
    }
    if (writes > 0) await batch.commit();
  }

  Future<void> _migrateFunctionBadgeSystemIfNeeded() async {
    if (!isAdmin) return;
    final db = FirebaseFirestore.instance;
    final metaRef = db.collection('meta').doc('uiSettings');
    final metaSnap = await metaRef.get();
    if ((metaSnap.data()?['functionSystemVersion'] ?? '').toString() == 'badge_v2') return;

    final usersSnap = await db.collection('users').get();
    final functionsSnap = await db.collection('functions').get();
    final adminFunction = defaultFunctionDefinitions().first;
    final allPermissions = FunctionPermission.values.map((e) => e.name).toList()..sort();

    WriteBatch batch = db.batch();
    var writes = 0;
    Future<void> flush() async {
      if (writes == 0) return;
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }

    for (final doc in functionsSnap.docs) {
      batch.delete(doc.reference);
      writes++;
      if (writes >= 350) await flush();
    }
    batch.set(db.collection('functions').doc(adminFunction.id), _functionMap(adminFunction));
    writes++;
    if (writes >= 350) await flush();

    for (final doc in usersSnap.docs) {
      final role = (doc.data()['role'] ?? 'member').toString();
      final isDocAdmin = role == 'admin';
      batch.set(doc.reference, {
        'function': isDocAdmin ? 'admin' : '',
        'functionIds': isDocAdmin ? <String>['admin'] : <String>[],
        'effectivePermissions': isDocAdmin ? allPermissions : <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      writes++;
      if (writes >= 350) await flush();
    }

    batch.set(metaRef, {'functionSystemVersion': 'badge_v2', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    writes++;
    await flush();
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

  Future<void> _saveScheduleDirect(WorkSchedule schedule) async {
    if (!canEditTeam(schedule.teamId) || !hasPermission(FunctionPermission.editProgram)) {
      throw StateError('Nu ai dreptul să modifici acest Grafic de lucru.');
    }
    final data = _scheduleMap(schedule);
    await FirebaseFirestore.instance.collection('schedules').doc(schedule.id).set(data, SetOptions(merge: true));
    unawaited(_writeLearningEvent(category: 'program', event: 'schedule_saved', teamId: schedule.teamId, scheduleId: schedule.id, data: {
      'date': schedule.date.toIso8601String(), 'started': schedule.started, 'closed': schedule.closed,
      'paused': schedule.paused, 'postponed': schedule.postponed, 'order': schedule.items.map((e) => e.locationId).toList(),
      'autoProposed': schedule.autoProposed, 'learningConfidence': schedule.learningConfidence,
    }));
    _scheduleCache[schedule.id] = _encoded(data);
    if (!mounted) return;
    setState(() {
      final index = schedules.indexWhere((x) => x.id == schedule.id);
      if (index >= 0) {
        schedules[index] = schedule;
      } else {
        schedules.add(schedule);
      }
    });
  }

  Future<void> _saveRecordDirect(CentralizerRecord record) async {
    final canWriteRecord = hasPermission(FunctionPermission.editProgram) || hasPermission(FunctionPermission.editCentralizer);
    if (!canEditTeam(record.teamId) || !canWriteRecord) {
      throw StateError('Nu ai dreptul să modifici execuțiile acestei echipe.');
    }
    final data = _recordMap(record);
    await FirebaseFirestore.instance.collection('records').doc(record.id).set(data, SetOptions(merge: true));
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
  void log(String action, String target) { unawaited(_writeAuditRemote(action, target)); }
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

