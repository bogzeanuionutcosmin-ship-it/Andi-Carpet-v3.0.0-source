part of '../main.dart';

class MapPage extends StatefulWidget {
  final AppUser currentUser;
  final List<AppUser> users;
  final List<Team> teams;
  final List<WorkSchedule> schedules;
  final List<CentralizerRecord> records;
  final List<Location> locations;
  final List<LocationCategory> categories;
  final bool isAdmin;
  final Set<String> hiddenUserIds;
  final VoidCallback onChanged;
  final void Function(String, String) log;
  final Future<void> Function(Location) saveLocation;
  const MapPage({
    super.key,
    required this.currentUser,
    required this.users,
    required this.teams,
    required this.schedules,
    required this.records,
    required this.locations,
    required this.categories,
    required this.isAdmin,
    required this.hiddenUserIds,
    required this.onChanged,
    required this.log,
    required this.saveLocation,
  });
  @override State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  Position? _myPosition;
  String? _gpsError;
  bool _locating = false;
  bool saving = false;
  bool findingAddress = false;
  String? selectedLocationId;
  final Set<String> _selectedCategoryIds = <String>{};
  final Set<LocationStatus> _selectedStatuses = <LocationStatus>{...LocationStatus.values};
  bool _showGraphRoute = true;
  String? _routeGraphId;
  String? _roadGeometryKey;
  Future<List<List<double>>?>? _roadGeometryFuture;
  DateTime? _roadGeometryRequestedAt;

  Future<List<List<double>>?> _loadRoadGeometry(List<LatLng> points) {
    final key = points.map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}').join('|');
    final stale = _roadGeometryRequestedAt == null ||
        DateTime.now().difference(_roadGeometryRequestedAt!) > const Duration(minutes: 5);
    if (_roadGeometryKey != key || _roadGeometryFuture == null || stale) {
      _roadGeometryKey = key;
      _roadGeometryRequestedAt = DateTime.now();
      _roadGeometryFuture = _mapboxServices.drivingGeometry(
        points.map((p) => <double>[p.latitude, p.longitude]).toList(),
      );
    }
    return _roadGeometryFuture!;
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds.addAll(widget.categories.where((c) => c.active).map((c) => c.id));
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  List<LocationCategory> get visibleCategories {
    final list = widget.categories.where((c) => c.active).toList();
    list.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<String?> _reverseGeocodePoint(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toStringAsFixed(7),
        'lon': point.longitude.toStringAsFixed(7),
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'ro',
      });
      final headers = <String,String>{'Accept': 'application/json', 'Accept-Language': 'ro'};
      if (!kIsWeb) headers['User-Agent'] = 'AndiCarpeta/1.5.1 (internal operations app)';
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.body.isEmpty) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final address = decoded['address'];
      if (address is Map) {
        String first(List<String> keys) {
          for (final key in keys) {
            final value = address[key]?.toString().trim() ?? '';
            if (value.isNotEmpty) return value;
          }
          return '';
        }
        final road = first(['road','pedestrian','residential','footway','path']);
        final number = first(['house_number']);
        final locality = first(['city','town','municipality','village','suburb']);
        final county = first(['county']);
        final parts = <String>[];
        final street = [road, number].where((x) => x.isNotEmpty).join(' ');
        if (street.isNotEmpty) parts.add(street);
        if (locality.isNotEmpty && !parts.contains(locality)) parts.add(locality);
        if (county.isNotEmpty && county != locality) parts.add(county);
        if (parts.isNotEmpty) return parts.join(', ');
      }
      final display = decoded['display_name']?.toString().trim() ?? '';
      return display.isEmpty ? null : display;
    } catch (_) {
      return null;
    }
  }

  Color _color(Location l) => categoryColor(widget.categories, l.categoryId, fallbackType: l.type);
  String _categoryName(Location l) => categoryName(widget.categories, l.categoryId, fallbackType: l.type);

  // Include graficele închise în ziua de lucru: markerul rămâne verde
  // după închiderea graficului, nu dispare din hartă.
  List<WorkSchedule> get _todayOperationalSchedules {
    final workDate = operationalWorkDate(DateTime.now());
    final teamId = widget.currentUser.teamId;
    return widget.schedules.where((s) =>
      s.started && sameDay(s.date, workDate) &&
      (widget.isAdmin || (teamId != null && s.teamId == teamId))
    ).toList();
  }

  List<CentralizerRecord> _todayRecordsFor(String locationId, String teamId) {
    final workDate = operationalWorkDate(DateTime.now());
    return widget.records.where((r) =>
      r.teamId == teamId && r.locationId == locationId &&
      recordBelongsToWorkDate(r, workDate)
    ).toList();
  }

  Color? _workBadgeColor(Location l) {
    final schedules = _todayOperationalSchedules;
    if (schedules.isEmpty) return null;
    var assignments = 0;
    var finishedAssignments = 0;
    var nextOrRunning = false;
    for (final day in schedules) {
      final ordered = [...day.items]..sort((a, b) => a.order.compareTo(b.order));
      ScheduleItem? nextItem;
      for (final item in ordered) {
        final records = _todayRecordsFor(item.locationId, day.teamId);
        final done = records.any((r) => r.completed);
        final running = records.any((r) =>
          r.status == WorkAttemptStatus.running ||
          r.status == WorkAttemptStatus.waitingAccess);
        final cancelled = records.isNotEmpty && records.every((r) =>
          r.status == WorkAttemptStatus.refused ||
          r.status == WorkAttemptStatus.notCompleted);
        if (item.locationId == l.id) {
          assignments++;
          if (done) finishedAssignments++;
          if (!done && running) nextOrRunning = true;
        }
        if (nextItem == null && !done && !cancelled) nextItem = item;
      }
      if (nextItem?.locationId == l.id) nextOrRunning = true;
    }
    if (assignments == 0) return null;
    // Nu afișăm verde dacă aceeași locație mai are o intervenție restantă.
    if (finishedAssignments == assignments) return Colors.green;
    if (nextOrRunning) return Colors.orange;
    return Colors.red;
  }

  String _workBadgeText(Location l) {
    final color = _workBadgeColor(l);
    if (color == Colors.green) return ' · făcută';
    if (color == Colors.orange) return ' · urmează / în lucru';
    if (color == Colors.red) return ' · nefăcută';
    return '';
  }

  Widget _locationMarkerIcon(Location l) {
    final badge = _workBadgeColor(l);
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Opacity(
        opacity: l.status == LocationStatus.open ? 1 : .62,
        child: DecoratedBox(
          decoration: BoxDecoration(color: _color(l), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)]),
          child: SizedBox(width: 40, height: 40, child: Icon(l.status == LocationStatus.open ? Icons.location_on : l.status.icon, color: Colors.white)),
        ),
      ),
      if (badge != null)
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(color: badge, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          ),
        ),
    ]);
  }

  List<String> get _activeRouteGraphIds {
    final teamId = widget.currentUser.teamId;
    final active = widget.schedules.where((s) => s.started && !s.closed && (teamId == null || s.teamId == teamId)).toList();
    final ids = <String>[];
    for (final s in active) { if (!ids.contains(s.graphId)) ids.add(s.graphId); }
    return ids;
  }

  List<WorkSchedule> get _routeDays {
    final ids = _activeRouteGraphIds;
    if (ids.isEmpty) return <WorkSchedule>[];
    final id = (_routeGraphId != null && ids.contains(_routeGraphId)) ? _routeGraphId! : ids.first;
    return widget.schedules.where((s) => s.graphId == id && s.started && !s.closed).toList()..sort((a,b)=>a.date.compareTo(b.date));
  }

  List<Polyline> _rainbowRouteLines() {
    if (!_showGraphRoute) return const <Polyline>[];
    const colors = <Color>[Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.blue, Colors.indigo, Colors.purple];
    final route = graphRoutePoints(_routeDays, widget.locations);
    // Nu desenăm segmente false peste locațiile fără GPS.
    if (!route.complete) return const <Polyline>[];
    final lines = <Polyline>[];
    for (var i = 1; i < route.points.length; i++) {
      lines.add(Polyline(points: [route.points[i - 1], route.points[i]],
          color: colors[(i - 1) % colors.length], strokeWidth: 6));
    }
    return lines;
  }

  List<Marker> _routeEndpointMarkers() {
    if(!_showGraphRoute||_routeDays.isEmpty)return const <Marker>[];
    final head=_routeDays.first;
    final markers=<Marker>[];
    if(head.departureLatitude!=null&&head.departureLongitude!=null){
      markers.add(Marker(point:LatLng(head.departureLatitude!,head.departureLongitude!),width:54,height:54,child:Tooltip(message:'Plecare · ${head.departureName}',child:const DecoratedBox(decoration:BoxDecoration(color:Colors.teal,shape:BoxShape.circle),child:Icon(Icons.trip_origin,color:Colors.white,size:30)))));
    }
    if(head.returnLatitude!=null&&head.returnLongitude!=null){
      markers.add(Marker(point:LatLng(head.returnLatitude!,head.returnLongitude!),width:54,height:54,child:Tooltip(message:'Întoarcere · ${head.returnName}',child:const DecoratedBox(decoration:BoxDecoration(color:Colors.deepOrange,shape:BoxShape.circle),child:Icon(Icons.flag,color:Colors.white,size:28)))));
    }
    return markers;
  }

  Future<void> _startLocationTracking() async {
    if (_locating) return;
    setState(() { _locating = true; _gpsError = null; });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _gpsError = 'Serviciile de localizare sunt oprite pe dispozitiv.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsError = permission == LocationPermission.deniedForever
            ? 'Permisiunea de localizare este blocată. Activeaz-o din setările browserului/dispozitivului.'
            : 'Permisiunea de localizare nu a fost acordată.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() => _myPosition = p);
      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((position) {
        if (mounted) setState(() => _myPosition = position);
      }, onError: (Object e) {
        if (mounted) setState(() => _gpsError = 'GPS: $e');
      });
    } catch (e) {
      if (mounted) setState(() => _gpsError = 'Nu am putut citi locația: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _centerOnMe() {
    final p = _myPosition;
    if (p == null) {
      unawaited(_startLocationTracking());
      return;
    }
    mapController.move(LatLng(p.latitude, p.longitude), 17);
  }

  @override
  Widget build(BuildContext context) {
    final positioned = widget.locations.where((l) =>
      l.latitude != null && l.longitude != null &&
      _selectedCategoryIds.contains(l.categoryId) &&
      _selectedStatuses.contains(l.status)
    ).toList();
    final unpositioned = widget.locations.where((l) =>
      (l.latitude == null || l.longitude == null) &&
      _selectedCategoryIds.contains(l.categoryId) &&
      _selectedStatuses.contains(l.status)
    ).length;
    final compact = MediaQuery.sizeOf(context).width < 650;
    return _Page(
      title: 'Hartă',
      subtitle: 'Vizualizare și poziționare. Editarea datelor se face din Admin → Locații.',
      actions: [
        IconButton(tooltip: 'Centrează pe mine', onPressed: _locating ? null : _centerOnMe, icon: const Icon(Icons.my_location)),
        if (widget.isAdmin) OutlinedButton.icon(onPressed: saving ? null : _showVerifiedImportPreview, icon: const Icon(Icons.fact_check_outlined), label: Text(compact ? 'Verificare GPS' : 'Import GPS verificat')),
        if (widget.isAdmin) FilledButton.icon(onPressed: (saving || findingAddress) ? null : () => _add(), icon: const Icon(Icons.add_location_alt), label: Text(compact ? 'Adaugă' : 'Adaugă locație')),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_gpsError != null) _InfoCard(icon: Icons.location_disabled_outlined, title: 'Locația mea', text: _gpsError!),
        if (_myPosition != null) _InfoCard(
          icon: Icons.gps_fixed,
          title: 'Locația mea este activă',
          text: 'Precizie aproximativă: ${_myPosition!.accuracy.toStringAsFixed(0)} m. Apasă markerul albastru de pe hartă pentru a memora o locație nouă aici.',
        ),
        if (saving || findingAddress) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text(findingAddress ? 'Caut adresa exactă pentru punctul ales pe hartă...' : 'Se salvează în Firestore...'),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Categorii:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...visibleCategories.map((cat) => FilterChip(
            selected: _selectedCategoryIds.contains(cat.id),
            avatar: categoryBrandWidget(cat.id, size: 22, fallbackColor: cat.color),
            label: Text(cat.name),
            onSelected: (v) => setState(() { if (v) { _selectedCategoryIds.add(cat.id); } else { _selectedCategoryIds.remove(cat.id); } }),
          )),
          TextButton(onPressed: () => setState(() { _selectedCategoryIds..clear()..addAll(visibleCategories.map((e)=>e.id)); }), child: const Text('Toate')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...LocationStatus.values.map((status) => FilterChip(
            selected: _selectedStatuses.contains(status),
            avatar: Icon(status.icon, size: 18, color: status.color),
            label: Text(status.label),
            onSelected: (v) => setState(() { if (v) { _selectedStatuses.add(status); } else { _selectedStatuses.remove(status); } }),
          )),
          TextButton(onPressed: () => setState(() { _selectedStatuses..clear()..addAll(LocationStatus.values); }), child: const Text('Toate statusurile')),
        ]),
        if (_activeRouteGraphIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilterChip(selected: _showGraphRoute, avatar: const Icon(Icons.route, size: 18), label: const Text('Traseu rutier (Mapbox)'), onSelected: (v) => setState(() => _showGraphRoute = v)),
            if (_activeRouteGraphIds.length > 1) DropdownButton<String>(
              value: (_routeGraphId != null && _activeRouteGraphIds.contains(_routeGraphId)) ? _routeGraphId : _activeRouteGraphIds.first,
              items: _activeRouteGraphIds.map((id) { final h = widget.schedules.firstWhere((s)=>s.graphId==id); return DropdownMenuItem(value:id,child:Text(h.graphName)); }).toList(),
              onChanged: (v) => setState(() => _routeGraphId = v),
            ),
          ]),
        ],
        if (_todayOperationalSchedules.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Stare azi:', style: TextStyle(fontWeight: FontWeight.bold)),
            _MapStatusLegend(color: Colors.red, label: 'Nefăcută'),
            _MapStatusLegend(color: Colors.orange, label: 'Urmează / în lucru'),
            _MapStatusLegend(color: Colors.green, label: 'Făcută'),
          ]),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: compact ? 430 : 560,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: const LatLng(45.9432, 24.9668),
                initialZoom: 6.3,
                onTap: widget.isAdmin && !saving && !findingAddress ? (_, point) => _chooseLocationAt(point) : null,
              ),
              children: [
                TileLayer(urlTemplate: kMapTileUrl, userAgentPackageName: 'ro.andicarpeta.app'),
                if (_showGraphRoute &&
                    graphRoutePoints(_routeDays, widget.locations).points.length >= 2)
                  FutureBuilder<List<List<double>>?>(
                    future: _loadRoadGeometry(graphRoutePoints(_routeDays, widget.locations).points),
                    builder: (context, snapshot) {
                      final coords = snapshot.data;
                      final hasRoadGeometry = coords != null && coords.length >= 2;
                      final displayPoints = hasRoadGeometry
                          ? coords.map((p) => LatLng(p[0], p[1])).toList()
                          : graphRoutePoints(_routeDays, widget.locations).points;
                      // Schematic fallback when Mapbox cannot provide road geometry.
                      return PolylineLayer(polylines: [
                        Polyline(
                          points: displayPoints,
                          color: hasRoadGeometry ? Colors.deepOrangeAccent : Colors.blueGrey,
                          strokeWidth: hasRoadGeometry ? 6 : 3,
                        ),
                      ]);
                    },
                  ),
                MarkerLayer(markers: [
                  ..._routeEndpointMarkers(),
                  ...positioned.map((l) => Marker(
                    point: LatLng(l.latitude!, l.longitude!), width: 46, height: 46,
                    child: Tooltip(
                      message: '${_categoryName(l)} · ${l.name} · ${l.status.label}${_workBadgeText(l)}',
                      child: GestureDetector(
                        onTap: () => _details(l),
                        child: _locationMarkerIcon(l),
                      ),
                    ),
                  )),
                  if (_myPosition != null) Marker(
                    point: LatLng(_myPosition!.latitude, _myPosition!.longitude), width: 62, height: 62,
                    child: Tooltip(
                      message: 'Locația mea',
                      child: GestureDetector(
                        onTap: _showMyLocationActions,
                        onLongPress: decodeProfilePhoto(widget.currentUser.photoBase64)==null?null:()=>showProfilePhotoViewer(context,widget.currentUser.photoBase64,widget.currentUser.name),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black38)]),
                          child: CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.blue,
                            backgroundImage: decodeProfilePhoto(widget.currentUser.photoBase64)==null?null:MemoryImage(decodeProfilePhoto(widget.currentUser.photoBase64)!),
                            child: decodeProfilePhoto(widget.currentUser.photoBase64)==null?const Icon(Icons.person_pin_circle,color:Colors.white,size:34):null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('liveLocations').snapshots(),
                  builder: (context, snap) {
                    final now = DateTime.now();
                    final markers = <Marker>[];
                    for (final doc in snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                      final d = doc.data();
                      final liveUserId = (d['userId'] ?? doc.id).toString();
                      if (!widget.isAdmin && widget.hiddenUserIds.contains(liveUserId)) continue;
                      final lat = d['latitude']; final lng = d['longitude'];
                      if (lat is! num || lng is! num) continue;
                      final updated = d['updatedAt'] is Timestamp ? (d['updatedAt'] as Timestamp).toDate() : null;
                      if (updated != null && now.difference(updated) > const Duration(hours: 24)) continue;
                      final name = (d['name'] ?? 'Membru').toString();
                      final mode = (d['mode'] ?? 'economic').toString();
                      AppUser? matchedUser; for (final u in widget.users) { if (u.id == liveUserId) { matchedUser = u; break; } }
                      final photoData = (d['photoBase64'] ?? matchedUser?.photoBase64 ?? '').toString();
                      final photo = decodeProfilePhoto(photoData);
                      markers.add(Marker(
                        point: LatLng(lat.toDouble(), lng.toDouble()),
                        width: 60,
                        height: 60,
                        child: Tooltip(
                          message: '$name · ${updated == null ? 'ora necunoscută' : 'actualizat ${timeText(updated)}'} · ${mode.startsWith('operational') ? 'mod operațional · ${mode.replaceFirst('operational-', '')}' : 'mod $mode'}',
                          child: GestureDetector(
                            onTap: photo == null ? null : () => showProfilePhotoViewer(context, photoData, name),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                              ),
                              child: CircleAvatar(
                                radius: 27,
                                backgroundColor: mode.startsWith('operational') ? Colors.green : Colors.indigo,
                                backgroundImage: photo == null ? null : MemoryImage(photo),
                                child: photo == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                              ),
                            ),
                          ),
                        ),
                      ));
                    }
                    return MarkerLayer(markers: markers);
                  },
                ),
                RichAttributionWidget(attributions: [TextSourceAttribution(kMapboxEnabled ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap contributors')]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (unpositioned > 0) _InfoCard(icon: Icons.gps_off, title: '$unpositioned locații neașezate pe hartă', text: widget.isAdmin ? 'Le găsești grupate imediat mai jos. Poți poziționa fiecare locație printr-un click pe hartă.' : 'Coordonatele pot fi completate de Admin.'),
        const SizedBox(height: 12),
        Text('Locații', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _unpositionedPanel(),
        ..._categoryPanels(),
      ]),
    );
  }

  Widget _unpositionedPanel() {
    final items = widget.locations.where((l) =>
      (l.latitude == null || l.longitude == null) &&
      _selectedCategoryIds.contains(l.categoryId) &&
      _selectedStatuses.contains(l.status)
    ).toList()..sort((a,b) {
      final cat = _categoryName(a).toLowerCase().compareTo(_categoryName(b).toLowerCase());
      return cat != 0 ? cat : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    if (items.isEmpty) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.gps_fixed)),
          title: const Text('Neașezate pe hartă', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Nu există locații fără coordonate pentru filtrele selectate.'),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
        ),
      );
    }
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(backgroundColor: Colors.orange.withValues(alpha:.15), child: const Icon(Icons.gps_off, color: Colors.orange)),
        title: const Text('Neașezate pe hartă', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${items.length} locații fără poziție GPS'),
        children: items.map((l) => ListTile(
          onTap: () => _details(l),
          leading: categoryBrandWidget(l.categoryId, size: 34, fallbackColor: _color(l)),
          title: Text(l.name),
          subtitle: Text('${_categoryName(l)} · ${l.address}\n${l.status.label} · fără GPS'),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Navigație după adresă',
              onPressed: () => _navigationChoice(l),
              icon: const Icon(Icons.navigation_outlined),
            ),
            if (widget.isAdmin) IconButton(
              tooltip: 'Poziționează pe hartă',
              onPressed: () {
                setState(() => selectedLocationId = l.id);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dă click pe hartă pentru a poziționa ${l.name}.')));
              },
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          ]),
        )).toList(),
      ),
    );
  }

  List<Widget> _categoryPanels() {
    final cats = <LocationCategory>[...visibleCategories];
    final known = cats.map((c) => c.id).toSet();
    final unknownIds = widget.locations.map((l) => l.categoryId).where((id) => !known.contains(id)).toSet();
    for (final id in unknownIds) {
      cats.add(LocationCategory(id: id, name: categoryName(widget.categories, id), colorValue: categoryColor(widget.categories, id).value));
    }
    return cats.map((cat) {
      final items = widget.locations.where((l) =>
        l.categoryId == cat.id &&
        l.latitude != null && l.longitude != null &&
        _selectedCategoryIds.contains(cat.id) &&
        _selectedStatuses.contains(l.status)
      ).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (items.isEmpty) return const SizedBox.shrink();
      return Card(
        child: ExpansionTile(
          leading: categoryBrandWidget(cat.id, size: 34, fallbackColor: cat.color),
          title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${items.length} locații poziționate'),
          children: items.map((l) => ListTile(
            onTap: () => _details(l),
            leading: Icon(l.status == LocationStatus.open ? Icons.location_on : l.status.icon, color: l.status == LocationStatus.open ? cat.color : l.status.color),
            title: Text(l.name),
            subtitle: Text('${l.address}\n${l.status.label} · GPS salvat'),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Deschide navigația',
                onPressed: () => _navigationChoice(l),
                icon: const Icon(Icons.navigation_outlined),
              ),
              if (widget.isAdmin) IconButton(
                tooltip: 'Mută pe hartă',
                onPressed: () {
                  setState(() => selectedLocationId = l.id);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dă click pe hartă pentru a muta ${l.name}.')));
                },
                icon: const Icon(Icons.edit_location_alt_outlined),
              ),
            ]),
          )).toList(),
        ),
      );
    }).toList();
  }

  Future<void> _navigationChoice(Location l) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('Google Maps'),
          subtitle: Text(l.latitude != null && l.longitude != null ? 'Rutare către coordonatele GPS salvate' : 'Rutare după adresa salvată'),
          onTap: () => Navigator.pop(c, 'maps'),
        ),
        ListTile(
          leading: const Icon(Icons.navigation_outlined),
          title: const Text('Waze'),
          subtitle: Text(l.latitude != null && l.longitude != null ? 'Rutare către coordonatele GPS salvate' : 'Rutare după adresa salvată'),
          onTap: () => Navigator.pop(c, 'waze'),
        ),
      ])),
    );
    if (choice != null && mounted) await _openNavigationForLocation(l, choice);
  }

  Future<void> _showMyLocationActions() async {
    final p = _myPosition;
    if (p == null) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Locația mea', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)} · precizie ${p.accuracy.toStringAsFixed(0)} m'),
        const SizedBox(height: 14),
        if (widget.isAdmin) FilledButton.icon(
          onPressed: () { Navigator.pop(c); unawaited(_add(initialPoint: LatLng(p.latitude, p.longitude))); },
          icon: const Icon(Icons.add_location_alt), label: const Text('Adaugă locație aici'),
        ) else const Text('Doar Adminul poate adăuga locații în registru.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () { Navigator.pop(c); _centerOnMe(); }, icon: const Icon(Icons.center_focus_strong), label: const Text('Centrează harta aici')),
      ]),
    )));
  }


}


