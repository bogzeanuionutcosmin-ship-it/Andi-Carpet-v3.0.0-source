import '../intents/finance_repository.dart';
import 'history_v2_journal.dart';

// Android/iOS/Windows require a separately verified transactional native store.
HistoryV2Journal createBrowserHistoryV2Journal({required String ownerUid,
  required String teamId, required bool Function() sessionIsCurrent}) {
  throw const FinanceRefusal('journal_v2_native_platform_blocked');
}
