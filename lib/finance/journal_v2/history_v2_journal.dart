import '../history/history_xi.dart';
import '../intents/finance_intent.dart';
import '../intents/finance_repository.dart';

// Port bound to protocol V2 + UID + team. No V1 adapter or bulk reset/import.
abstract interface class HistoryV2Journal {
  String get ownerUid;
  String get teamId;
  Future<List<HistoryXiIntent>> pending();
  Future<bool> prepare(HistoryXiIntent intent);
  Future<bool> confirm(HistoryXiIntent intent);
  void dispose();
}
class HistoryV2Outcome {
  final FinanceIntentResult result;
  final bool journalPending;
  const HistoryV2Outcome(this.result, {required this.journalPending});
}
class HistoryV2Coordinator {
  final FinanceHistoryXiRepository repository;
  final HistoryV2Journal journal;
  HistoryV2Coordinator({required this.repository, required this.journal}) {
    if (repository.ownerUid != journal.ownerUid) throw ArgumentError('journal_v2_scope_mismatch');
  }
  bool _bound(HistoryXiIntent i) => i.receipt.actorUid == journal.ownerUid && i.receipt.teamId == journal.teamId;
  Future<HistoryV2Outcome> executeExplicitly(HistoryXiIntent i) async {
    try {
      if (!_bound(i)) throw const FinanceRefusal('journal_v2_scope_mismatch');
      if (!await journal.prepare(i)) {
        return const HistoryV2Outcome(FinanceIntentResult(FinanceIntentStatus.uncertain,
          'journal_v2_reconcile_required'), journalPending: true);
      }
    } catch (_) {
      // This invocation sent nothing, but the same ID may already be pending
      // or committed in another context. Storage failure is not a global refusal.
      return const HistoryV2Outcome(FinanceIntentResult(FinanceIntentStatus.uncertain,
        'journal_v2_prepare_failed'), journalPending: true);
    }
    return _finish(i, await repository.executeExplicitly(i));
  }
  Future<HistoryV2Outcome> reconcileExplicitly(HistoryXiIntent i) async {
    try {
      if (!_bound(i) || !(await journal.pending()).any((old) => old.encode() == i.encode())) {
        throw const FinanceRefusal('journal_v2_missing_evidence');
      }
    } catch (_) {
      return const HistoryV2Outcome(FinanceIntentResult(FinanceIntentStatus.uncertain,
        'journal_v2_missing_evidence'), journalPending: true);
    }
    return _finish(i, await repository.reconcileExplicitly(i));
  }
  Future<HistoryV2Outcome> _finish(HistoryXiIntent i, FinanceIntentResult result) async {
    // Retain even a fresh certain refusal. Conservative manual review beats
    // accidentally treating another context's attempted send as rejected.
    if (result.status != FinanceIntentStatus.confirmed) {
      return HistoryV2Outcome(result, journalPending: true);
    }
    try {
      await journal.confirm(i);
      return HistoryV2Outcome(result, journalPending: false);
    } catch (_) {
      // Financial confirmation survives cleanup failure; same-ID reconcile is safe.
      return HistoryV2Outcome(result, journalPending: true);
    }
  }
}
