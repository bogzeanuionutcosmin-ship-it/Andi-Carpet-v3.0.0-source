part of '../main.dart';

extension _HomeLiveLocation on _HomePageState {
  void _startAdaptiveLiveLocation() {
    if (!_sessionActive) return;
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
    if (!_sessionActive) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      if (!_sessionActive) return;
      var permission = await Geolocator.checkPermission();
      if (!_sessionActive) return;
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (!_sessionActive) return;
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      await _backgroundLocationSubscription?.cancel();
      if (!_sessionActive) return;
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
        onError: (Object e) {
          if (!_sessionActive) return;
          VisionErrorTelemetry.report(area: 'gps', code: 'background_stream_failed');
          debugPrint('[location] Background stream: $e');
        },
      );
    } catch (e) {
      if (_sessionActive) VisionErrorTelemetry.report(area: 'gps', code: 'background_start_failed');
      debugPrint('[location] Nu am putut porni tracking-ul nativ în background: $e');
    }
  }

  void _updateNativeLocationProximityBoost(Position p, DateTime workDate) {
    if (!_sessionActive) return;
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
    if (!_sessionActive) return '';
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
      if (!_sessionActive) return '';
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
    if (!_sessionActive) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (!_sessionActive) return;
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      if (!_sessionActive) return;
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
          if (!_sessionActive) return;
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
      if (!_sessionActive) return;
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
      if (!_sessionActive) return;
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
      if (!_sessionActive) return;
      _lastSharedPosition = p;
      _lastSharedAt = now;
      await _applyWorkAutomationFromPosition(p, now, workDate);
    } catch (e) {
      if (_sessionActive) VisionErrorTelemetry.report(area: 'gps', code: 'location_update_failed');
      debugPrint('[location] Actualizarea locației a eșuat: $e');
    }
  }

}
