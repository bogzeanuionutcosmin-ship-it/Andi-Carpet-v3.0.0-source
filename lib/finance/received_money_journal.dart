import 'dart:convert';

import '../models/app_data_models.dart';

/// Retains the exact received-money intent until the server confirms it.
/// A later process must replay the same entry ID after an uncertain ACK.
class ReceivedMoneyJournal {
  ReceivedMoneyJournal({required this.read, required this.write, required this.remove});

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) remove;
  static final Set<String> _inFlight = <String>{};

  String _key({required String userId, required String teamId, required String targetId}) {
    if ([userId, teamId, targetId].any((value) => value.trim().isEmpty)) {
      throw StateError('Identitatea financiară nu este completă.');
    }
    final scope = jsonEncode([userId, teamId, targetId]);
    return 'received-money-v1-${base64Url.encode(utf8.encode(scope))}';
  }

  Future<ReceivedMoneyEntry?> pending({required String userId, required String teamId, required String targetId}) async {
    final raw = await read(_key(userId: userId, teamId: teamId, targetId: targetId));
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['id'] is! String || value['kind'] is! String ||
          value['amount'] is! num || value['method'] is! String || value['fromName'] is! String ||
          value['date'] is! String) throw const FormatException('Invalid received-money intent');
      final entry = ReceivedMoneyEntry(id: value['id'] as String, kind: value['kind'] as String,
        amount: (value['amount'] as num).toDouble(), method: value['method'] as String,
        fromName: value['fromName'] as String, date: DateTime.parse(value['date'] as String));
      if (entry.id.isEmpty || !entry.amount.isFinite || entry.amount <= 0 ||
          !['departure', 'during'].contains(entry.kind) || entry.fromName.trim().isEmpty) {
        throw const FormatException('Invalid received-money intent');
      }
      return entry;
    } catch (_) {
      throw StateError('Cererea financiară salvată nu poate fi citită; este necesară reconcilierea.');
    }
  }

  Future<void> persist({required String userId, required String teamId, required String targetId,
      required ReceivedMoneyEntry entry}) async {
    final key = _key(userId: userId, teamId: teamId, targetId: targetId);
    final existing = await read(key);
    if (existing != null) {
      final saved = await pending(userId: userId, teamId: teamId, targetId: targetId);
      if (!_same(saved!, entry)) throw StateError('Există deja o sumă în curs de confirmare.');
      return;
    }
    await write(key, jsonEncode({'id': entry.id, 'kind': entry.kind, 'amount': entry.amount,
      'method': entry.method, 'fromName': entry.fromName, 'date': entry.date.toIso8601String()}));
  }

  Future<void> acknowledge({required String userId, required String teamId, required String targetId,
      required ReceivedMoneyEntry entry}) async {
    final key = _key(userId: userId, teamId: teamId, targetId: targetId);
    final saved = await pending(userId: userId, teamId: teamId, targetId: targetId);
    if (saved == null || !_same(saved, entry)) throw StateError('Suma salvată nu corespunde confirmării.');
    await remove(key);
  }

  Future<T> run<T>({required String userId, required String teamId, required String targetId,
      required ReceivedMoneyEntry candidate, required Future<T> Function(ReceivedMoneyEntry) send}) async {
    final key = _key(userId: userId, teamId: teamId, targetId: targetId);
    if (!_inFlight.add(key)) throw StateError('Există deja o sumă în curs de salvare.');
    try {
      final saved = await pending(userId: userId, teamId: teamId, targetId: targetId);
      final entry = saved ?? candidate;
      if (saved == null) await persist(userId: userId, teamId: teamId, targetId: targetId, entry: candidate);
      final result = await send(entry);
      await acknowledge(userId: userId, teamId: teamId, targetId: targetId, entry: entry);
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  bool _same(ReceivedMoneyEntry a, ReceivedMoneyEntry b) => a.id == b.id && a.kind == b.kind &&
      a.amount == b.amount && a.method == b.method && a.fromName == b.fromName && a.date.isAtSameMomentAs(b.date);
}
