import 'package:flutter/foundation.dart';
import '../../main.dart' show TravelSettlement, TeamFinance, FinanceSaveRejected;
import 'finance_checked_journal.dart';
import 'finance_demo_panel.dart';
import 'finance_expense_demo_adapter.dart';
import 'finance_journal.dart';
import 'finance_repository.dart';

// Explicit, inactive candidate for Home's original callback signatures. The
// shipped SDK port is emulator-only. This is NOT a production feature flag.
// Caller must bind UID + AuthGate generation + active team in sessionIsCurrent,
// and synchronously dispose this object when that ownership ends.
class FinanceHomeCandidate extends ChangeNotifier {
  final String teamId;
  final bool Function() _owner;
  bool _open = true;
  final _observed = <String>{};
  late final FinanceCheckedJournalStorage _storage;
  late final FinanceDemoScope _scope;
  late final FinanceExpenseDemoAdapter _adapter;

  FinanceHomeCandidate.singleWriterCandidate({
    required String ownerUid,
    required this.teamId,
    required bool Function() sessionIsCurrent,
    required FinanceAtomicPort port,
    required FinanceJournalStorage deviceStorage,
    required Future<void> Function(String, Map<String, Object?>) acceptServerSnapshot,
    required Object? Function(String) readAcceptedModel,
  }) : _owner = sessionIsCurrent {
    if (teamId.isEmpty || teamId.length > 128 || teamId.contains('/')) {
      throw ArgumentError('finance_invalid_team');
    }
    _storage = FinanceCheckedJournalStorage.singleWriterCandidate(
      storage: deviceStorage, ownerUid: ownerUid, sessionIsCurrent: this.sessionIsCurrent);
    _scope = FinanceDemoScope(ownerUid: ownerUid,
      sessionIsCurrent: this.sessionIsCurrent, port: port, storage: _storage);
    _adapter = FinanceExpenseDemoAdapter(scope: _scope, port: port,
      readAcceptedModel: readAcceptedModel,
      acceptServerSnapshot: (path, data) async {
        _guard(data['teamId']);
        await acceptServerSnapshot(path, data);
        _guard(data['teamId']);
        _observed.add(path);
      });
    _adapter.addListener(_changed);
    // No storage read, server read, intent creation, or recovery on construction.
  }

  bool sessionIsCurrent() {
    if (!_open) return false;
    try { if (!_owner()) _open = false; } catch (_) { _open = false; }
    return _open;
  }
  void _guard(Object? team) {
    if (!sessionIsCurrent()) throw FinanceSaveRejected('finance_session_expired');
    if (team != teamId) throw FinanceSaveRejected('finance_wrong_team');
  }
  void _changed() { if (_open) notifyListeners(); }
  Map<String, String> get pendingCodes => sessionIsCurrent()
    ? _adapter.pendingCodes : const {};

  void observeSettlement(TravelSettlement model, FinanceServerObservation server) {
    _guard(model.teamId);
    _adapter.observeSettlement(model, server);
    _observed.add('settlements/${model.id}');
  }
  void observeFinance(TeamFinance model, FinanceServerObservation server) {
    _guard(model.teamId);
    _adapter.observeFinance(model, server);
  }
  Future<void> saveSettlement(TravelSettlement model) {
    _guard(model.teamId);
    // Unknown target is CREATE only. Its absence is verified atomically on the
    // server; an unobserved existing target can never become an edit/overwrite.
    return _observed.contains('settlements/${model.id}')
      ? _adapter.saveSettlement(model) : _adapter.createSettlement(model);
  }
  Future<void> saveFinance(TeamFinance model) {
    _guard(model.teamId);
    return _adapter.saveFinance(model);
  }
  Future<void> loadPendingForReviewExplicitly() async {
    _guard(teamId);
    final pending = await _scope.coordinator.journal.pending();
    _guard(teamId);
    // UID storage may contain another team's unresolved work after a transfer.
    // Preserve it and block this composition; never display or adopt that work.
    if (pending.any((intent) => intent.teamId != teamId)) {
      throw FinanceSaveRejected('finance_foreign_team_pending');
    }
    await _adapter.loadPendingForReviewExplicitly();
  }
  Future<void> reconcileExplicitly(String path) async {
    _guard(teamId);
    await _adapter.reconcileExplicitly(path);
  }
  @override void dispose() {
    _open = false;
    _adapter.removeListener(_changed);
    _adapter.dispose();
    _storage.dispose();
    super.dispose();
  }
}
