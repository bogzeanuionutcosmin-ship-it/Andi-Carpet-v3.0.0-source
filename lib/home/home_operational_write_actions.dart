part of '../main.dart';

// Acțiuni operaționale mutate textual din HomePage. Permisiunile,
// jurnalizarea Learning și ordinea actualizărilor sunt păstrate integral.
extension _HomeOperationalWriteActions on _HomePageState {
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

}
