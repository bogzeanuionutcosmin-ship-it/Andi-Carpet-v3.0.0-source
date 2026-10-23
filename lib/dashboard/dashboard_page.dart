part of '../main.dart';

class DashboardPage extends StatefulWidget {
  final List<Team> teams; final List<AppUser> users; final List<FunctionDefinition> functionDefinitions; final List<Location> locations; final List<LocationCategory> categories; final List<WorkSchedule> schedules; final List<CentralizerRecord> records; final AppSettings settings; final AppUser currentUser; final bool canEditProgram; final String Function(String) userName; final VoidCallback onChanged; final Future<void> Function(CentralizerRecord) saveRecord; final Future<void> Function(DashboardScheduleIntent) saveDashboardScheduleOperation; final void Function(String,String) log;
  final void Function(String, Object?)? onRecordJournalTrace;
  const DashboardPage({super.key, required this.teams, required this.users, required this.functionDefinitions, required this.locations, required this.categories, required this.schedules, required this.records, required this.settings, required this.currentUser, required this.canEditProgram, required this.userName, required this.onChanged, required this.saveRecord, required this.saveDashboardScheduleOperation, required this.log, this.onRecordJournalTrace});
  @override State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  int teamIndex = 0;
  String? selectedGraphId;
  static const FlutterSecureStorage _recordStorage = FlutterSecureStorage();
  static const FlutterSecureStorage _scheduleStorage = FlutterSecureStorage();
  final Set<String> _recoveryStarted = {};
  final Set<String> _journalRetryTeams = {};
  final Set<String> _journalBusyTeams = {};
  Timer? _journalRetryTimer;
  bool _appResumed = true;

  DashboardRecordJournal get _recordJournal => DashboardRecordJournal(
        read: (key) => _recordStorage.read(key: key),
        write: (key, value) => _recordStorage.write(key: key, value: value),
        remove: (key) => _recordStorage.delete(key: key),
        trace: widget.onRecordJournalTrace,
      );

  void _traceRecordOperation(String stage, [Object? error]) {
    try {
      widget.onRecordJournalTrace?.call(stage, error);
    } catch (_) {
      // Diagnostics must never affect an operational transition.
    }
  }

  DashboardScheduleJournal get _scheduleJournal => DashboardScheduleJournal(
        read: (key) => _scheduleStorage.read(key: key),
        write: (key, value) => _scheduleStorage.write(key: key, value: value),
        remove: (key) => _scheduleStorage.delete(key: key),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed && widget.teams.isNotEmpty) {
      unawaited(_recoverDashboardRecord(widget.teams[teamIndex.clamp(0, widget.teams.length - 1)].id));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _journalRetryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRecordRecovery(String teamId) {
    if (!_recoveryStarted.add(teamId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_recoverDashboardRecord(teamId));
    });
  }

  void _ensureJournalRetryTimer() {
    if (!mounted) return;
    _journalRetryTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_appResumed || _journalRetryTeams.isEmpty) return;
      for (final teamId in _journalRetryTeams.toList()) {
        unawaited(_recoverDashboardRecord(teamId));
      }
    });
  }

  Future<void> _recoverDashboardRecord(String teamId) async {
    if (!_journalBusyTeams.add(teamId)) {
      _traceRecordOperation('recovery.busy');
      return;
    }
    _traceRecordOperation('recovery.begin');
    final userId = widget.currentUser.id;
    try {
      var recovered = false;
      _traceRecordOperation('recovery.record.pending.read.begin');
      final intent = await _recordJournal.pending(userId: userId, teamId: teamId);
      _traceRecordOperation(intent == null ? 'recovery.record.pending.empty' : 'recovery.record.pending.existing');
      if (intent != null) {
        await _recordJournal.run(candidate: intent, send: (pending) async {
          final record = centralizerRecordFromData(pending.recordId, pending.desired)
            ..writeBaseline = pending.expected;
          await widget.saveRecord(record);
        });
        recovered = true;
      }
      final scheduleIntent = await _scheduleJournal.pending(userId: userId, teamId: teamId);
      if (scheduleIntent != null) {
        await _scheduleJournal.run(candidate: scheduleIntent, send: widget.saveDashboardScheduleOperation);
        recovered = true;
      }
      if (!recovered) {
        _journalRetryTeams.remove(teamId);
        if (_journalRetryTeams.isEmpty) {
          _journalRetryTimer?.cancel();
          _journalRetryTimer = null;
        }
        return;
      }
      _journalRetryTeams.remove(teamId);
      if (mounted) {
        widget.onChanged();
        showSuccessMessage(context, 'O operație salvată în așteptare a fost confirmată după reconectare.');
      }
      if (_journalRetryTeams.isEmpty) {
        _journalRetryTimer?.cancel();
        _journalRetryTimer = null;
      }
    } catch (error) {
      _traceRecordOperation('recovery.failed', error);
      // Keep the exact intent and retry only while the app is active. The
      // authoritative Home writer validates server state and rejects conflicts.
      if (_journalRetryTeams.add(teamId) && mounted) {
        showErrorMessage(context, 'O salvare de intervenție este în așteptare. Reconectează-te; sistemul va reîncerca aceeași operație.');
      }
      _ensureJournalRetryTimer();
    } finally {
      _journalBusyTeams.remove(teamId);
      _traceRecordOperation('recovery.released');
    }
  }

  Future<void> _saveRecordJournalled(CentralizerRecord record) async {
    if (!_journalBusyTeams.add(record.teamId)) {
      _traceRecordOperation('record.busy.conflict', StateError('team=${record.teamId}'));
      throw StateError('O altă salvare a intervenției acestei echipe este în curs.');
    }
    _traceRecordOperation('record.journalled.begin');
    final transition = record.status == WorkAttemptStatus.running && record.finishedAt == null
        ? 'start'
        : record.status == WorkAttemptStatus.completed || record.status == WorkAttemptStatus.refused || record.status == WorkAttemptStatus.notCompleted
            ? 'finish'
            : record.status == WorkAttemptStatus.waitingAccess
                ? 'waiting'
                : 'outcome';
    final desired = recordDocumentData(record)..remove('updatedAt');
    final intent = DashboardRecordIntent(
      userId: widget.currentUser.id,
      teamId: record.teamId,
      recordId: record.id,
      transition: transition,
      desired: desired,
      expected: record.writeBaseline == null ? null : Map<String, dynamic>.from(record.writeBaseline!),
    );
    try {
      _traceRecordOperation('record.journal.run.begin');
      await _recordJournal.run(candidate: intent, send: (pending) async {
        _traceRecordOperation('record.saveRecord.callback.begin');
        final replay = centralizerRecordFromData(pending.recordId, pending.desired)
          ..writeBaseline = pending.expected;
        await widget.saveRecord(replay);
        _traceRecordOperation('record.saveRecord.callback.done');
      });
      _traceRecordOperation('record.journal.run.done');
      _journalRetryTeams.remove(record.teamId);
      if (_journalRetryTeams.isEmpty) {
        _journalRetryTimer?.cancel();
        _journalRetryTimer = null;
      }
    } catch (error) {
      _traceRecordOperation('record.journalled.failed', error);
      _journalRetryTeams.add(record.teamId);
      _ensureJournalRetryTimer();
      rethrow;
    } finally {
      _journalBusyTeams.remove(record.teamId);
      _traceRecordOperation('record.journalled.released');
    }
  }

  DashboardScheduleIntent _dashboardScheduleIntent({
    required String transition,
    required List<WorkSchedule> schedules,
  }) {
    final now = DateTime.now();
    final committedAt = Timestamp.fromDate(now);
    final teamId = schedules.first.teamId;
    final graphId = schedules.first.graphId;
    return DashboardScheduleIntent(
      userId: widget.currentUser.id,
      teamId: teamId,
      graphId: graphId,
      transition: transition,
      writes: schedules.map((schedule) {
        final token = '${now.microsecondsSinceEpoch}-${newInterventionId()}-${schedule.id}';
        return DashboardScheduleWrite(
          scheduleId: schedule.id,
          expectedExists: schedule.persisted,
          expectedUpdatedAt: schedule.updatedAt == null ? null : Timestamp.fromDate(schedule.updatedAt!),
          expectedWriteToken: schedule.writeToken,
          desired: scheduleDocumentData(schedule, updatedAt: committedAt, writeToken: token),
        );
      }).toList(),
    );
  }

  Future<void> _saveDashboardScheduleJournalled({
    required String transition,
    required List<WorkSchedule> schedules,
  }) async {
    if (schedules.isEmpty) throw StateError('Graficul nu conține zile de salvat.');
    final teamId = schedules.first.teamId;
    if (!_journalBusyTeams.add(teamId)) {
      throw StateError('O altă salvare a acestei echipe este în curs.');
    }
    final intent = _dashboardScheduleIntent(transition: transition, schedules: schedules);
    try {
      await _scheduleJournal.run(candidate: intent, send: widget.saveDashboardScheduleOperation);
      _journalRetryTeams.remove(teamId);
      if (_journalRetryTeams.isEmpty) {
        _journalRetryTimer?.cancel();
        _journalRetryTimer = null;
      }
    } catch (_) {
      var shouldRetry = true;
      try {
        shouldRetry = await _scheduleJournal.pending(userId: intent.userId, teamId: teamId) != null;
      } catch (_) {
        // An unreadable journal leaves the commit outcome unknown; keep retry.
        shouldRetry = true;
      }
      if (shouldRetry) {
        _journalRetryTeams.add(teamId);
        _ensureJournalRetryTimer();
      }
      rethrow;
    } finally {
      _journalBusyTeams.remove(teamId);
    }
  }

  Team get team => widget.teams[teamIndex.clamp(0, widget.teams.length - 1)];

  WorkSchedule? _scheduleForItem(ScheduleItem item) {
    final matches = widget.schedules.where((s) => s.teamId == team.id &&
      s.graphId == selectedGraphId && s.items.any((i) => identical(i, item) ||
        (item.interventionId.isNotEmpty && i.interventionId == item.interventionId)));
    return matches.length == 1 ? matches.single : null;
  }

  List<CentralizerRecord> _recordsForItem(ScheduleItem item, DateTime workDate) =>
      dashboardRecordsForItem(widget.records, teamId: team.id, item: item, workDate: workDate);

  CentralizerRecord? _latestRecord(ScheduleItem item, DateTime workDate) {
    final rs = _recordsForItem(item, workDate);
    return rs.isEmpty ? null : rs.last;
  }

  List<CentralizerRecord> _completedHistory(String locationId) =>
      dashboardCompletedHistory(widget.records, locationId: locationId);

  Duration? _averageDuration(String locationId) => learnedAverageDuration(widget.records, locationId, widget.settings);



  Future<Map<String,dynamic>?> _dashboardGeocodeTripPoint(String query) async {
    return RomaniaPlaceGeocoder(
      serverEndpoint: Uri.parse(_geocodeRomaniaPlaceUrl),
      getIdToken: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
      get: (uri, {headers}) => http.get(uri, headers: headers),
      post: (uri, {headers, body}) => http.post(uri, headers: headers, body: body),
      isWeb: kIsWeb,
      includeName: false,
      logPrefix: 'Dashboard',
      log: (message) => debugPrint(message),
    ).geocode(query);
  }

  Future<void> _toggleProgram(WorkSchedule schedule) async {
    if(!schedule.started){
      final dep=TextEditingController(text:schedule.departureName);
      final ret=TextEditingController(text:schedule.returnName);
      final choice=await showDialog<Map<String,String>>(context:context,builder:(c)=>AlertDialog(
        title:const Text('START program'),
        content:SizedBox(width:540,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Punctele sunt folosite numai pentru deplasare, kilometri și consum. Nu apar în Centralizator.'),
          const SizedBox(height:12),
          TextField(controller:dep,decoration:const InputDecoration(labelText:'Plecare',hintText:'Ex: Brăila')),
          const SizedBox(height:10),
          TextField(controller:ret,decoration:const InputDecoration(labelText:'Întoarcere / destinație finală',hintText:'Ex: Brăila')),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Anulează')),FilledButton(onPressed:()=>Navigator.pop(c,{'departure':dep.text.trim(),'return':ret.text.trim()}),child:const Text('START'))],
      ));
      dep.dispose();ret.dispose();
      if(choice==null)return;
      final departureText=(choice['departure']??'').trim();final returnText=(choice['return']??'').trim();
      if(departureText.isEmpty||returnText.isEmpty){if(mounted)showErrorMessage(context,'Completează plecarea și punctul final.');return;}
      final startPoint=await _dashboardGeocodeTripPoint(departureText);
      final endPoint=departureText.toLowerCase()==returnText.toLowerCase()?startPoint:await _dashboardGeocodeTripPoint(returnText);
      if(startPoint==null||endPoint==null){if(mounted)showErrorMessage(context,'Nu am putut identifica una dintre localități. Scrie localitatea mai explicit.');return;}
      final sameGraph = dashboardSchedulesForGraphStart(
        schedules: widget.schedules,
        selectedSchedule: schedule,
        departureName: departureText,
        departureLatitude: startPoint['lat'] as double,
        departureLongitude: startPoint['lon'] as double,
        returnName: returnText,
        returnLatitude: endPoint['lat'] as double,
        returnLongitude: endPoint['lon'] as double,
      );
      try {
        await _saveDashboardScheduleJournalled(transition: 'start', schedules: sameGraph);
      } catch(e) {
        if(mounted)showErrorMessage(context,'Programul nu a putut fi pornit: ${scheduleSaveFailureMessage(e)}');
        return;
      }
      widget.onChanged();
      widget.log('START program din Acasă','${team.name} · ${schedule.graphName} · $departureText → $returnText');
      if(mounted)showSuccessMessage(context,'Programul echipei a fost pornit cu traseul complet.');
      return;
    }
    final updated = dashboardScheduleForGraphStop(schedule);
    try {
      await _saveDashboardScheduleJournalled(transition: 'stop', schedules: [updated]);
      widget.onChanged();
      widget.log('STOP program din Acasă','${team.name} · ${updated.graphName} · ${formatDate(updated.date)}');
      if(mounted)showSuccessMessage(context,'Programul echipei a fost oprit.');
    } catch (e) {
      if (mounted) showErrorMessage(context,'Programul nu a putut fi oprit: ${scheduleSaveFailureMessage(e)}');
    }
  }

  String _memberLocationLabel(String userId, Map<String, Map<String,dynamic>> live, String teamId) {
    return dashboardMemberLocationLabel(
      live: live[userId],
      teamId: teamId,
      records: widget.records,
      locations: widget.locations,
      now: DateTime.now,
      belongsToWorkDate: recordBelongsToWorkDate,
      distanceBetween: Geolocator.distanceBetween,
      formatTime: timeText,
      locationCityLabel: (name, address) => dashboardLocationCityLabel(
        name: name,
        address: address,
      ),
    );
  }

  String _confidenceLabel(List<int> counts) {
    if (counts.isEmpty) return '—';
    final minCount = counts.reduce((a, b) => a < b ? a : b);
    if (minCount >= 8) return 'ridicată';
    if (minCount >= 5) return 'medie';
    return 'inițială';
  }

  String _recordStateText(CentralizerRecord? r) => dashboardRecordStateText(
    status: r?.status,
    refusalReason: r?.refusalReason,
    duration: r?.duration,
    startedAt: r?.startedAt,
    finishedAt: r?.finishedAt,
    waitingStartedAt: r?.waitingStartedAt,
    waitingDuration: r?.waitingDuration,
  );

  Color _recordStateColor(CentralizerRecord? r) =>
      dashboardRecordStateColor(r?.status);

  IconData _recordStateIcon(CentralizerRecord? r) =>
      dashboardRecordStateIcon(r?.status);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final compact = MediaQuery.sizeOf(context).width < 650;
    if (widget.teams.isEmpty) {
      return _Page(title: 'Acasă', subtitle: formatDate(now), child: const _Empty(icon: Icons.groups_outlined, text: 'Nu există încă nicio echipă. Adminul poate crea prima echipă din Admin Panel → Echipe.'));
    }
    if (teamIndex >= widget.teams.length) teamIndex = 0;
    _scheduleRecordRecovery(team.id);

    final candidates = widget.schedules.where((s) => s.teamId == team.id && sameDay(s.date, workDate) && !s.closed).toList();
    candidates.sort((a, b) {
      final startedCompare = (b.started ? 1 : 0).compareTo(a.started ? 1 : 0);
      if (startedCompare != 0) return startedCompare;
      return a.graphName.toLowerCase().compareTo(b.graphName.toLowerCase());
    });
    final graphIds = <String>[];
    for (final s in candidates) {
      if (!graphIds.contains(s.graphId)) graphIds.add(s.graphId);
    }
    if (selectedGraphId == null || !graphIds.contains(selectedGraphId)) {
      selectedGraphId = graphIds.isEmpty ? null : graphIds.first;
    }
    final scheduleMatches = candidates.where((s) => s.graphId == selectedGraphId).toList();
    final schedule = scheduleMatches.isEmpty ? null : scheduleMatches.first;
    final items = schedule?.items ?? <ScheduleItem>[];
    final done = items.where((i) => _latestRecord(i, workDate)?.completed == true).length;
    final failed = items.where((i) {
      final r = _latestRecord(i, workDate);
      return r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted;
    }).length;
    final running = dashboardRunningRecords(widget.records, teamId: team.id);
    final waiting = dashboardWaitingRecords(
      widget.records,
      teamId: team.id,
      workDate: workDate,
    );
    final inWindow = isInsideWorkWindow(now, workDate);

    final operationalStatus = dashboardTeamOperationalStatus(
      hasRunningRecord: running.isNotEmpty,
      waitingForAccess: waiting.isNotEmpty,
      schedulePaused: schedule?.paused == true,
      schedulePostponed: schedule?.postponed == true,
      scheduleStarted: schedule?.started == true,
      insideWorkWindow: inWindow,
    );

    String stateText;
    IconData stateIcon;
    Color stateColor;
    switch (operationalStatus) {
      case DashboardOperationalStatus.running:
        stateText = 'PE SALĂ · ${running.first.locationNameSnapshot}';
        stateIcon = Icons.location_on;
        stateColor = Colors.green;
        break;
      case DashboardOperationalStatus.waitingAccess:
        stateText = 'AȘTEPTARE ACCES · ${waiting.first.locationNameSnapshot}';
        stateIcon = Icons.hourglass_top;
        stateColor = Colors.orange;
        break;
      case DashboardOperationalStatus.paused:
        stateText = 'ÎN PAUZĂ';
        stateIcon = Icons.pause_circle;
        stateColor = Colors.orange;
        break;
      case DashboardOperationalStatus.postponed:
        stateText = 'PROGRAM AMÂNAT';
        stateIcon = Icons.event_busy;
        stateColor = Colors.deepOrange;
        break;
      case DashboardOperationalStatus.duringWorkWindow:
        stateText = 'ÎN TIMPUL PROGRAMULUI';
        stateIcon = Icons.nightlight_round;
        stateColor = Colors.blue;
        break;
      case DashboardOperationalStatus.outsideWorkWindow:
        stateText = 'ÎN AFARA PROGRAMULUI';
        stateIcon = Icons.schedule;
        stateColor = Colors.blueGrey;
        break;
    }

    final pendingForEstimate = items.where((item) {
      final r = _latestRecord(item, workDate);
      if (r?.completed == true) return false;
      if (r?.status == WorkAttemptStatus.refused || r?.status == WorkAttemptStatus.notCompleted) return false;
      return true;
    }).toList();
    var estimateAvailable = pendingForEstimate.isNotEmpty;
    var estimatedSeconds = 0;
    final confidenceCounts = <int>[];
    var insufficientHistory = 0;
    for (final item in pendingForEstimate) {
      final history = _completedHistory(item.locationId);
      if (history.length < 3) {
        estimateAvailable = false;
        insufficientHistory++;
        continue;
      }
      confidenceCounts.add(history.length);
      final average = _averageDuration(item.locationId)!;
      final r = _latestRecord(item, workDate);
      if (r?.status == WorkAttemptStatus.running && r?.startedAt != null) {
        final elapsed = now.difference(r!.startedAt!).inSeconds;
        estimatedSeconds += (average.inSeconds - elapsed).clamp(0, average.inSeconds).toInt();
      } else {
        estimatedSeconds += average.inSeconds;
      }
    }
    final estimatedEnd = estimateAvailable ? now.add(Duration(seconds: estimatedSeconds)) : null;

    return _Page(
      title: 'Acasă',
      subtitle: '${formatDate(now)} · zi de lucru ${formatDate(workDate)}',
      actions: [IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment:Alignment.centerRight,child:_InstallAppButtons(settings:widget.settings,compact:true)),
        const SizedBox(height:10),
        Text('Echipe acum', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: widget.teams.map((t) {
          final ts = widget.schedules.where((s)=>s.teamId==t.id && sameDay(s.date,workDate) && !s.closed).toList();
          final active = ts.any((s)=>s.started && !s.paused && !s.postponed);
          final paused = ts.any((s)=>s.paused);
          final color = active ? Colors.green : paused ? Colors.orange : Colors.blueGrey;
          return SizedBox(width: compact ? double.infinity : 260, child: Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withValues(alpha:.15), child: Icon(active?Icons.play_arrow:paused?Icons.pause:Icons.schedule,color:color)),
            title: Text(t.name, style: const TextStyle(fontWeight:FontWeight.w800)),
            subtitle: Text(active?'În program':paused?'În pauză':'În afara programului'),
            onTap:(){final idx=widget.teams.indexWhere((x)=>x.id==t.id);if(idx>=0)setState((){teamIndex=idx;selectedGraphId=null;});},
          )));
        }).toList()),
        const SizedBox(height: 14),
        _TeamSelector(teams: widget.teams, selected: teamIndex, onChanged: (v) => setState(() { teamIndex = v; selectedGraphId = null; })),
        if (graphIds.length > 1) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedGraphId,
            decoration: const InputDecoration(labelText: 'Grafic activ pentru ziua de lucru'),
            items: graphIds.map((id) {
              final s = candidates.firstWhere((x) => x.graphId == id);
              return DropdownMenuItem(value: id, child: Text('${s.graphName}${s.started ? ' · pornit' : ' · pregătit'}'));
            }).toList(),
            onChanged: (v) => setState(() => selectedGraphId = v),
          ),
        ],
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          CircleAvatar(backgroundColor: stateColor.withValues(alpha: .16), child: Icon(stateIcon, color: stateColor)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Stare echipă', style: TextStyle(fontSize: 12)),
            Text(stateText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Fereastră standard: ${timeText(workWindowStart(workDate))} → ${timeText(workWindowEnd(workDate))}'),
          ])),
          if(schedule!=null && widget.canEditProgram) ...[
            const SizedBox(width:10),
            compact
              ? IconButton.filled(tooltip:schedule.started?'STOP program':'START program',onPressed:()=>_toggleProgram(schedule),icon:Icon(schedule.started?Icons.stop:Icons.play_arrow))
              : FilledButton.icon(onPressed:()=>_toggleProgram(schedule),icon:Icon(schedule.started?Icons.stop:Icons.play_arrow),label:Text(schedule.started?'STOP program':'START program')),
          ],
        ]))),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: FirebaseFirestore.instance.collection('liveLocations').snapshots(),
          builder:(context,snap){
            final live=<String,Map<String,dynamic>>{};
            for(final d in snap.data?.docs??<QueryDocumentSnapshot<Map<String,dynamic>>>[]) live[d.id]=d.data();
            final visibleUserIds = widget.users.map((u) => u.id).toSet();
            final visibleMemberIds = team.members.where(visibleUserIds.contains).toList();
            final members=visibleMemberIds.map((id){
              final u=(() { for(final x in widget.users){if(x.id==id)return x;} return null; })();
              final name=u?.name??widget.userName(id);
              final photo=decodeProfilePhoto(u?.photoBase64 ?? '');
              final functions=u==null?'' : u.functionIds.map((fid)=>widget.functionDefinitions.where((f)=>f.id==fid).map((f)=>f.name).cast<String?>().firstWhere((v)=>v!=null,orElse:()=>fid)!).join(', ');
              return ListTile(
                dense:true,
                leading:GestureDetector(
                  onTap:u==null||photo==null?null:()=>showProfilePhotoViewer(context,u.photoBase64,name),
                  child:CircleAvatar(radius:22,backgroundImage:photo==null?null:MemoryImage(photo),child:photo==null?const Icon(Icons.person_outline):null),
                ),
                title:Text(name,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(_memberLocationLabel(id,live,team.id)),if(functions.isNotEmpty)Text(functions),if(u!=null&&u.functionIds.isNotEmpty)...[const SizedBox(height:6),memberBadgeStripWidget(widget.functionDefinitions,u.functionIds,size:30)]]),
              );
            }).toList();
            return Card(child:ExpansionTile(
              initiallyExpanded:true,
              leading:const Icon(Icons.groups_2_outlined),
              title:Text('Membrii ${team.name}',style:const TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('${visibleMemberIds.length} membri · poziție live dacă este disponibilă'),
              children:members.isEmpty?[const ListTile(title:Text('Echipa nu are membri alocați.'))]:members,
            ));
          },
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _StatCard(title: 'Grafic azi', value: schedule == null ? 'Nu există' : '${items.length} locații', asset: 'assets/ui/tab_grafic.png'),
          _StatCard(title: 'Progres', value: '$done finalizate · ${items.length - done} rămase', asset: 'assets/ui/tab_centralizator.png'),
          _StatCard(title: 'Acum', value: running.isNotEmpty ? running.first.locationNameSnapshot : waiting.isNotEmpty ? 'Așteptare · ${waiting.first.locationNameSnapshot}' : (inWindow ? 'Între locații' : 'Liber'), asset: 'assets/ui/tab_harta.png'),
          if (failed > 0) _StatCard(title: 'Excepții', value: '$failed refuzate / nerealizate', icon: Icons.warning_amber_rounded),
        ]),
        const SizedBox(height: 14),
        if (estimatedEnd != null)
          _InfoCard(icon: Icons.schedule_send, title: 'Final estimat ${timeText(estimatedEnd)}', text: 'Încredere ${_confidenceLabel(confidenceCounts)} · calculat numai din locații cu minimum 3 execuții finalizate.'),
        if (estimatedEnd == null && pendingForEstimate.isNotEmpty && insufficientHistory > 0)
          _InfoCard(icon: Icons.auto_graph, title: 'Estimare încă indisponibilă', text: '$insufficientHistory locații rămase au sub 3 execuții istorice. Aplicația nu afișează o oră estimată până când datele nu sunt suficiente.'),
        if (estimatedEnd != null && estimatedEnd.isAfter(workWindowEnd(workDate)))
          Card(color:Theme.of(context).colorScheme.errorContainer,child:ListTile(leading:Icon(Icons.warning_amber_rounded,color:Theme.of(context).colorScheme.error),title:const Text('Risc de depășire a planului',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Finalul estimat este ${timeText(estimatedEnd)}, după limita ${timeText(workWindowEnd(workDate))}. În Grafic de lucru poți recalcula traseul rămas sau transfera locațiile neîncepute.'))),
        if (schedule?.planAlertAt != null && schedule!.planAlertReason.trim().isNotEmpty)
          _InfoCard(icon:Icons.notifications_active,title:'Ultima alertă de plan · ${timeText(schedule.planAlertAt)}',text:schedule.planAlertReason),
        if (schedule != null) ...[
          const SizedBox(height: 12),
          _InfoCard(icon: Icons.route, title: schedule.graphName, text: 'Grafic activ · ${formatDate(schedule.date)} · ${schedule.started ? 'pornit' : 'nepornit'}${schedule.paused ? ' · pauză' : ''}${schedule.postponed ? ' · amânat' : ''}'),
        ],
        if (schedule != null && items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Locațiile zilei curente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...items.map((item) {
            final r = _latestRecord(item, workDate);
            final color = _recordStateColor(r);
            final isRunning = r?.status == WorkAttemptStatus.running && r?.finishedAt == null;
            final canEnter = !isRunning && r?.completed != true && r?.status != WorkAttemptStatus.refused && r?.status != WorkAttemptStatus.notCompleted;
            return Card(child: ListTile(
              leading: Stack(alignment: Alignment.bottomRight, children: [
                categoryBrandWidget(item.categoryIdSnapshot, size: 36, fallbackColor: categoryColor(widget.categories, item.categoryIdSnapshot, fallbackType: item.typeSnapshot)),
                Container(width: 19, height: 19, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), child: Icon(_recordStateIcon(r), color: Colors.white, size: 11)),
              ]),
              title: Text(item.locationNameSnapshot, maxLines: 3, overflow: TextOverflow.ellipsis, softWrap: true),
              subtitle: Text(_recordStateText(r), maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: (r?.refusalReason ?? '').trim().isNotEmpty,
              trailing: r?.completed == true
                ? const Icon(Icons.check_circle, color: Colors.green)
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (canEnter)
                      Tooltip(
                        message: 'Intră / începe lucrul',
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                          onPressed: !widget.canEditProgram || schedule.paused || schedule.postponed || !schedule.started ? null : () => _startLocation(item),
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        ),
                      ),
                    if (isRunning)
                      Tooltip(
                        message: 'Stop / ieși din locație',
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                          onPressed: widget.canEditProgram ? () => _finishLocation(r!) : null,
                          icon: const Icon(Icons.stop_rounded, size: 28),
                        ),
                      ),
                    const SizedBox(width: 4),
                    if (widget.canEditProgram) PopupMenuButton<String>(
                      tooltip: 'Alte acțiuni',
                      onSelected: (value) {
                        if (value == 'wait') unawaited(_markWaiting(item));
                        if (value == 'refused') unawaited(_markOutcome(item, WorkAttemptStatus.refused));
                        if (value == 'notCompleted') unawaited(_markOutcome(item, WorkAttemptStatus.notCompleted));
                      },
                      itemBuilder: (_) => [
                        if (!isRunning && r?.completed != true) const PopupMenuItem(value: 'wait', child: ListTile(leading: Icon(Icons.hourglass_top), title: Text('Așteptare acces'))),
                        if (r?.completed != true) const PopupMenuItem(value: 'refused', child: ListTile(leading: Icon(Icons.block), title: Text('Refuzată'))),
                        if (r?.completed != true) const PopupMenuItem(value: 'notCompleted', child: ListTile(leading: Icon(Icons.warning_amber_rounded), title: Text('Nerealizată'))),
                      ],
                    ),
                  ]),
            ));
          }),
        ] else const _Empty(icon: Icons.route, text: 'Nu există locații în Graficul de lucru pentru această zi.'),
        const SizedBox(height: 12),
        if (schedule != null && items.isNotEmpty && items.every((i) => widget.records.where((r) => r.locationId == i.locationId && r.completed).length >= 3))
          const _InfoCard(icon: Icons.auto_graph, title: 'Learning activ', text: 'Estimările folosesc istoricul real. INTRĂ/IEȘI, așteptările, refuzurile și nerealizările sunt păstrate separat pentru Learning.'),
      ]),
    );
  }

  final Set<String> _pendingStarts = {};

  Future<void> _startLocation(ScheduleItem item) => runDashboardPendingOperation(
        pending: _pendingStarts,
        key: item.locationId,
        action: () async {
          _traceRecordOperation('start.button.callback');
          await _startLocationOnce(item);
        },
      );

  Future<void> _startLocationOnce(ScheduleItem item) async {
    _traceRecordOperation('start.callback.enter');
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final decision = dashboardStartRecordDecision<CentralizerRecord>(
      records: widget.records,
      belongsToIntervention: (r) => recordMatchesIntervention(r, item),
      teamId: team.id,
      locationId: item.locationId,
      teamIdOf: (record) => record.teamId,
      locationIdOf: (record) => record.locationId,
      statusOf: (record) => record.status,
      isRunning: WorkAttemptStatus.running,
      finishedAtOf: (record) => record.finishedAt,
      eventTimeOf: recordEventTime,
    );
    if (decision.action == DashboardStartRecordAction.blockedByOtherLocation) {
      _traceRecordOperation('start.blocked.by.other.location');
      final running = decision.activeRecord!;
      if (mounted) showErrorMessage(context, 'Echipa este deja pe sală la ${running.locationNameSnapshot}. Apasă IEȘI înainte de a intra în altă locație.');
      return;
    }
    if (decision.action == DashboardStartRecordAction.alreadyRunning) {
      _traceRecordOperation('start.already.running');
      return;
    }
    final base = decision.baseRecord;
    final r = CentralizerRecord(
      id: base?.id ?? nextInterventionRecordId(item, widget.records),
      graphId: item.interventionId.isEmpty ? '' : _scheduleForItem(item)?.graphId ?? '',
      scheduleId: item.interventionId.isEmpty ? '' : _scheduleForItem(item)?.id ?? '',
      interventionId: item.interventionId,
      writeBaseline: base?.writeBaseline,
      teamId: team.id,
      locationId: item.locationId,
      type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot,
      addressSnapshot: item.addressSnapshot,
      waitingStartedAt: base?.waitingStartedAt,
      waitingEndedAt: base?.waitingStartedAt != null && base?.waitingEndedAt == null ? now : base?.waitingEndedAt,
      startedAt: now,
      finishedAt: null,
      status: WorkAttemptStatus.running,
      refusalReason: null,
      keptForLearning: base?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: base?.facadeDone ?? false,
    );
    try {
      _traceRecordOperation('start.save.begin');
      await _saveRecordJournalled(r);
      _traceRecordOperation('start.save.done');
      widget.log('INTRĂ pe sală', '${team.name} · ${item.locationNameSnapshot}');
      if (mounted) showSuccessMessage(context, 'Intrare salvată: ${item.locationNameSnapshot} · ${timeText(r.startedAt)}');
    } catch (e) {
      _traceRecordOperation('start.save.failed', e);
      if (mounted) showErrorMessage(context, 'Intrarea nu a putut fi salvată: $e');
    } finally {
      _traceRecordOperation('start.operation.complete');
    }
  }

  final Set<String> _pendingFinishes = {};

  Future<void> _finishLocation(CentralizerRecord source) => runDashboardPendingOperation(
        pending: _pendingFinishes,
        key: source.id,
        action: () => _finishLocationOnce(source),
      );

  Future<void> _finishLocationOnce(CentralizerRecord source) async {
    final facadeDone = !source.facadePlanned ? source.facadeDone : await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Fațada a fost realizată?'),
        content: Text('${source.locationNameSnapshot}\nRăspunsul este obligatoriu înainte de finalizarea intervenției.'),
        actions: [
          OutlinedButton.icon(onPressed: () => Navigator.pop(c, false), icon: const Icon(Icons.close), label: const Text('NU')),
          FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.check), label: const Text('DA')),
        ],
      ),
    );
    if (facadeDone == null) return;
    final r = CentralizerRecord(
      id: source.id,
      graphId: source.graphId, scheduleId: source.scheduleId, interventionId: source.interventionId,
      writeBaseline: source.writeBaseline,
      teamId: source.teamId,
      locationId: source.locationId,
      type: source.type,
      locationNameSnapshot: source.locationNameSnapshot,
      addressSnapshot: source.addressSnapshot,
      waitingStartedAt: source.waitingStartedAt,
      waitingEndedAt: source.waitingEndedAt,
      startedAt: source.startedAt,
      finishedAt: DateTime.now(),
      status: WorkAttemptStatus.completed,
      refusalReason: source.refusalReason,
      keptForLearning: source.keptForLearning,
      facadePlanned: source.facadePlanned,
      facadeDone: facadeDone,
    );
    try {
      await _saveRecordJournalled(r);
      widget.log('IEȘI de pe sală', '${team.name} · ${r.locationNameSnapshot} · ${durationText(r.duration)}');
      if (mounted) {
        showSuccessMessage(context, 'Ieșire salvată: ${r.locationNameSnapshot} · ${timeText(r.finishedAt)} · ${durationText(r.duration)}');
      }
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Ieșirea nu a putut fi salvată: $e');
    }
  }

  Future<void> _markWaiting(ScheduleItem item) async {
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final running = widget.records.where((r) => r.teamId == team.id && r.status == WorkAttemptStatus.running && r.finishedAt == null).toList();
    if (running.isNotEmpty) {
      if (mounted) showErrorMessage(context, 'Există deja o locație în lucru. Închide întâi intervenția curentă.');
      return;
    }
    final existing = widget.records.where((r) => r.teamId == team.id && r.locationId == item.locationId && recordMatchesIntervention(r, item) && r.finishedAt == null).toList()
      ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    final base = existing.isEmpty ? null : existing.last;
    final r = CentralizerRecord(
      id: base?.id ?? nextInterventionRecordId(item, widget.records),
      graphId: item.interventionId.isEmpty ? '' : _scheduleForItem(item)?.graphId ?? '',
      scheduleId: item.interventionId.isEmpty ? '' : _scheduleForItem(item)?.id ?? '',
      interventionId: item.interventionId,
      writeBaseline: base?.writeBaseline,
      teamId: team.id,
      locationId: item.locationId,
      type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot,
      addressSnapshot: item.addressSnapshot,
      waitingStartedAt: base?.waitingStartedAt ?? now,
      waitingEndedAt: null,
      startedAt: null,
      finishedAt: null,
      status: WorkAttemptStatus.waitingAccess,
      refusalReason: null,
      keptForLearning: base?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: base?.facadeDone ?? false,
    );
    try {
      await _saveRecordJournalled(r);
      widget.log('Așteptare acces', '${team.name} · ${item.locationNameSnapshot}');
      if (mounted) showSuccessMessage(context, 'Așteptarea a fost pornită pentru ${item.locationNameSnapshot}.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Așteptarea nu a putut fi salvată: $e');
    }
  }

  Future<String?> _reasonDialog(WorkAttemptStatus status, String locationName) async {
    final controller = TextEditingController();
    final title = status == WorkAttemptStatus.refused ? 'Locație refuzată' : 'Locație nerealizată';
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(locationName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: controller, autofocus: true, maxLines: 3, decoration: const InputDecoration(labelText: 'Motiv *', hintText: 'Ex.: acces refuzat, închis, problemă tehnică...')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
          FilledButton(onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(c, value);
          }, child: const Text('Salvează')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _markOutcome(ScheduleItem item, WorkAttemptStatus status) async {
    final reason = await _reasonDialog(status, item.locationNameSnapshot);
    if (reason == null) return;
    final now = DateTime.now();
    final workDate = operationalWorkDate(now);
    final existing = widget.records.where((r) => r.teamId == team.id && r.locationId == item.locationId && recordMatchesIntervention(r, item) && r.finishedAt == null).toList()
      ..sort((a, b) => recordEventTime(a).compareTo(recordEventTime(b)));
    final base = existing.isEmpty ? null : existing.last;
    final r = CentralizerRecord(
      id: base?.id ?? nextInterventionRecordId(item, widget.records),
      graphId: item.interventionId.isEmpty ? '' : _scheduleForItem(item)?.graphId ?? '',
      scheduleId: item.interventionId.isEmpty ? '' : _scheduleForItem(item)?.id ?? '',
      interventionId: item.interventionId,
      writeBaseline: base?.writeBaseline,
      teamId: team.id,
      locationId: item.locationId,
      type: item.typeSnapshot,
      locationNameSnapshot: item.locationNameSnapshot,
      addressSnapshot: item.addressSnapshot,
      waitingStartedAt: base?.waitingStartedAt,
      waitingEndedAt: base?.waitingStartedAt != null && base?.waitingEndedAt == null ? now : base?.waitingEndedAt,
      startedAt: base?.startedAt,
      finishedAt: now,
      status: status,
      refusalReason: reason,
      keptForLearning: base?.keptForLearning ?? true,
      facadePlanned: item.facadePlanned, facadeDone: base?.facadeDone ?? false,
    );
    try {
      await _saveRecordJournalled(r);
      final label = status == WorkAttemptStatus.refused ? 'Refuzată' : 'Nerealizată';
      widget.log(label, '${team.name} · ${item.locationNameSnapshot} · $reason');
      if (mounted) showSuccessMessage(context, '$label: ${item.locationNameSnapshot}. Motivul a fost păstrat pentru Learning.');
    } catch (e) {
      if (mounted) showErrorMessage(context, 'Statusul nu a putut fi salvat: $e');
    }
  }
}
