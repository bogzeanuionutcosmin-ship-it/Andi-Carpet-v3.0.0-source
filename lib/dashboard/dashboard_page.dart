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
      