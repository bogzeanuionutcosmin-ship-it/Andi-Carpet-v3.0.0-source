part of '../main.dart';

extension _HomeWorkAutomation on _HomePageState {
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

}
