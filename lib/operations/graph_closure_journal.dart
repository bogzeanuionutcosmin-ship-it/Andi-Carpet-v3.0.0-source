import 'dart:convert';

import 'graph_closure_client.dart';

/// Saves intent before sending. A new process replays the original revisions
/// and request ID, even if its schedule listener has already seen the commit.
class GraphClosureJournal {
  GraphClosureJournal({required this.read, required this.write, required this.remove});

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) remove;
  static final Set<String> _inFlight = <String>{};

  Future<String> close({
    required String projectId,
    required String userId,
    required Map<String, dynamic> operation,
    required Future<String> Function(Map<String, dynamic> operation) send,
  }) async {
    final scope = [projectId, userId, operation['teamId'], operation['graphId']];
    if (scope.any((value) => value is! String || value.isEmpty)) {
      throw StateError('Identitate STOP incompletă.');
    }
    final key = 'graph-stop-v1-${base64Url.encode(utf8.encode(jsonEncode(scope)))}';
    if (!_inFlight.add(key)) throw StateError('STOP este deja în curs.');
    try {
      final saved = await read(key);
      Map<String, dynamic> pending;
      if (saved == null) {
        // Detach mutable caller lists/maps before the first asynchronous write.
        pending = jsonDecode(jsonEncode(operation)) as Map<String, dynamic>;
        await write(key, jsonEncode(pending));
      } else {
        try {
          pending = jsonDecode(saved) as Map<String, dynamic>;
          if (pending['teamId'] != operation['teamId'] ||
              pending['graphId'] != operation['graphId'] ||
              pending['requestId'] is! String ||
              (pending['requestId'] as String).isEmpty || pending['days'] is! List) {
            throw const FormatException('Invalid STOP journal');
          }
        } catch (_) {
          // Never overwrite an unreadable intent with a new request ID.
          throw StateError('Cererea STOP salvată nu poate fi citită. Necesită reconciliere.');
        }
      }
      try {
        final receipt = await send(pending);
        await remove(key);
        return receipt;
      } on GraphClosureRejected {
        // Only an explicit server rejection retires an uncommitted intent.
        await remove(key);
        rethrow;
      }
      // Timeout, crash, bad ACK, storage failure or session change retain intent.
    } finally {
      _inFlight.remove(key);
    }
  }
}
