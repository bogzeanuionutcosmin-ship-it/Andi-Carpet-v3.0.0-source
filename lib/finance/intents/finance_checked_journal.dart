import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'finance_intent.dart';
import 'finance_journal.dart';
import 'finance_repository.dart';

// Opt-in single-writer candidate. Readback is an integrity barrier, not proof
// of OS durability, cross-process exclusion, or production rollout readiness.
// The existing journal owns in-isolate serialization and payload validation.
class FinanceCheckedJournalStorage implements FinanceJournalStorage {
  final FinanceJournalStorage storage;
  final String ownerUid;
  final bool Function() _owner;
  bool _open = true;
  static const format = 'AndiFinanceDeviceJournalV1';
  static const maxEnvelopeBytes = FinanceIntentJournal.maxBytes * 3;
  FinanceCheckedJournalStorage.singleWriterCandidate({required this.storage,
    required this.ownerUid, required bool Function() sessionIsCurrent})
      : _owner = sessionIsCurrent {
    if (ownerUid.isEmpty || ownerUid.length > 128 || ownerUid.contains('/')) {
      throw ArgumentError('finance_invalid_owner');
    }
  }
  void dispose() { _open = false; }
  void _guard(String key) {
    if (!_open) throw const FinanceRefusal('finance_session_expired');
    try { if (!_owner()) { _open = false; } } catch (_) { _open = false; }
    if (!_open) throw const FinanceRefusal('finance_session_expired');
    if (key != 'finance_intents_v1_$ownerUid') {
      throw const FinanceRefusal('finance_wrong_owner');
    }
  }
  String _digest(String payload) => sha256.convert(utf8.encode(
    canonicalFinanceJson({'format':format,'ownerUid':ownerUid,'payload':payload}))).toString();
  String _unwrap(String raw) {
    if (utf8.encode(raw).length > maxEnvelopeBytes) {
      throw const FinanceRefusal('finance_device_journal_corrupt');
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['version'] == 1) {
        throw const FinanceRefusal('finance_device_journal_upgrade_required');
      }
      if (decoded is! Map || decoded.length != 4 || decoded['format'] != format ||
          decoded['ownerUid'] != ownerUid || decoded['payload'] is! String ||
          decoded['digest'] is! String) throw const FormatException();
      final payload = decoded['payload'] as String;
      if (utf8.encode(payload).length > FinanceIntentJournal.maxBytes ||
          decoded['digest'] != _digest(payload)) throw const FormatException();
      return payload;
    } on FinanceRefusal { rethrow; }
    catch (_) { throw const FinanceRefusal('finance_device_journal_corrupt'); }
  }
  @override Future<String?> read(String key) async {
    _guard(key);
    final raw = await storage.read(key);
    _guard(key);
    return raw == null ? null : _unwrap(raw);
  }
  @override Future<void> write(String key, String value) async {
    _guard(key);
    if (utf8.encode(value).length > FinanceIntentJournal.maxBytes) {
      throw const FinanceRefusal('finance_journal_full');
    }
    final envelope = canonicalFinanceJson({'format':format,'ownerUid':ownerUid,
      'payload':value,'digest':_digest(value)});
    if (utf8.encode(envelope).length > maxEnvelopeBytes) {
      throw const FinanceRefusal('finance_journal_full');
    }
    await storage.write(key, envelope);
    _guard(key);
    // Do not infer persistence from a successful plugin Future alone. A failed
    // write/readback never authorizes the coordinator's financial submission.
    final stored = await storage.read(key);
    _guard(key);
    if (stored == null || stored != envelope || _unwrap(stored) != value) {
      throw const FinanceRefusal('finance_device_journal_readback_failed');
    }
  }
  @override String toString() => 'FinanceCheckedJournalStorage';
}
