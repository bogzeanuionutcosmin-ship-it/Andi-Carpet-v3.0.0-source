import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Durable intent for a Dashboard record transition. The payload and its CAS
/// baseline are kept until the server writer confirms the operation.
class DashboardRecordIntent {
  const DashboardRecordIntent({
    required this.userId,
    required this.teamId,
    required this.recordId,
    required this.transition,
    required this.desired,
    required this.expected,
  });

  final String userId;
  final String teamId;
  final String recordId;
  final String transition;
  final Map<String, dynamic> desired;
  final Map<String, dynamic>? expected;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'userId': userId,
        'teamId': teamId,
        'recordId': recordId,
        'transition': transition,
        'desired': _encode(desired),
        'expected': expected == null ? null : _encode(expected),
      };

  factory DashboardRecordIntent.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['userId'] is! String ||
        json['teamId'] is! String ||
        json['recordId'] is! String ||
        !const {'start', 'finish', 'waiting', 'outcome'}.contains(json['transition']) ||
        json['desired'] is! Map ||
        (json['expected'] != null && json['expected'] is! Map)) {
      throw const FormatException('Invalid Dashboard record intent.');
    }
    final intent = DashboardRecordIntent(
      userId: json['userId'] as String,
      teamId: json['teamId'] as String,
      recordId: json['recordId'] as String,
      transition: json['transition'] as String,
      desired: Map<String, dynamic>.from(_decode(json['desired']) as Map),
      expected: json['expected'] == null
          ? null
          : Map<String, dynamic>.from(_decode(json['expected']) as Map),
    );
    intent.validate();
    return intent;
  }

  void validate() {
    final status = desired['status'];
    final validStatus = switch (transition) {
      'start' => status == 'running',
      'finish' || 'outcome' => const {'completed', 'refused', 'notCompleted'}.contains(status),
      'waiting' => status == 'waitingAccess',
      _ => false,
    };
    if (userId.trim().isEmpty || teamId.trim().isEmpty || recordId.trim().isEmpty ||
        desired['teamId'] != teamId || desired['locationId'] is! String ||
        (desired['locationId'] as String).trim().isEmpty || !validStatus) {
      throw const FormatException('Dashboard record payload does not match its scope or transition.');
    }
    if (expected != null && (expected!['teamId'] != teamId ||
        expected!['locationId'] != desired['locationId'] ||
        (expected!['interventionId'] ?? '') != (desired['interventionId'] ?? ''))) {
      throw const FormatException('Dashboard record baseline identity does not match its payload.');
    }
  }

  bool sameOperation(DashboardRecordIntent other) =>
      userId == other.userId &&
      teamId == other.teamId &&
      recordId == other.recordId &&
      transition == other.transition &&
      _deepEquals(desired, other.desired) &&
      _deepEquals(expected, other.expected);
}

class DashboardRecordJournal {
  const DashboardRecordJournal({
    required this.read,
    required this.write,
    required this.remove,
    this.trace,
  });

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) remove;
  final void Function(String stage, Object? error)? trace;
  static final Set<String> _inFlight = <String>{};

  void _trace(String stage, [Object? error]) {
    try {
      trace?.call(stage, error);
    } catch (_) {
      // Diagnostic observers must not change the durability path.
    }
  }

  String _key(String userId, String teamId) {
    final scope = jsonEncode([userId, teamId]);
    return 'dashboard_record_intent_v1_${base64Url.encode(utf8.encode(scope))}';
  }

  Future<DashboardRecordIntent?> pending({
    required String userId,
    required String teamId,
  }) async {
    final raw = await read(_key(userId, teamId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Intent is not an object.');
      final intent = DashboardRecordIntent.fromJson(Map<String, dynamic>.from(decoded));
      if (intent.userId != userId || intent.teamId != teamId) {
        throw const FormatException('Intent scope does not match its storage key.');
      }
      return intent;
    } on FormatException catch (error) {
      // A corrupt journal is preserved for diagnosis; never replace it with a
      // new operation that could make the original outcome unknowable.
      throw StateError('Dashboard record recovery data is unreadable: $error');
    }
  }

  Future<void> persist(DashboardRecordIntent intent) async {
    intent.validate();
    await write(_key(intent.userId, intent.teamId), jsonEncode(intent.toJson()));
  }

  Future<void> clear(DashboardRecordIntent intent) =>
      remove(_key(intent.userId, intent.teamId));

  /// Replays the persisted intent when present. A different operation in the
  /// same user/team scope is blocked until the previous outcome is resolved.
  Future<void> run({
    required DashboardRecordIntent candidate,
    required Future<void> Function(DashboardRecordIntent intent) send,
  }) async {
    _trace('journal.run.begin');
    candidate.validate();
    final key = _key(candidate.userId, candidate.teamId);
    if (!_inFlight.add(key)) {
      _trace('journal.run.in_flight');
      throw StateError('A Dashboard record save is already running for this team.');
    }
    try {
      _trace('journal.pending.read.begin');
      final current = await pending(userId: candidate.userId, teamId: candidate.teamId);
      _trace(current == null ? 'journal.pending.empty' : 'journal.pending.existing');
      if (current != null && !current.sameOperation(candidate)) {
        _trace('journal.pending.conflict');
        throw StateError('A previous Dashboard record save is unresolved; reconnect and retry it first.');
      }
      final intent = current ?? candidate;
      if (current == null) {
        _trace('journal.persist.begin');
        await persist(intent);
        _trace('journal.persist.done');
      }
      _trace('journal.send.begin');
      await send(intent);
      _trace('journal.send.done');
      _trace('journal.clear.begin');
      await clear(intent);
      _trace('journal.clear.done');
    } catch (error) {
      _trace('journal.run.failed', error);
      rethrow;
    } finally {
      _inFlight.remove(key);
      _trace('journal.run.released');
    }
  }
}

dynamic _encode(dynamic value) {
  if (value is Timestamp) return {'__dashboardTimestamp': value.toDate().toIso8601String()};
  if (value is DateTime) return {'__dashboardTimestamp': value.toIso8601String()};
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _encode(item)));
  }
  if (value is List) return value.map(_encode).toList();
  if (value == null || value is String || value is num || value is bool) return value;
  throw ArgumentError('Unsupported value in Dashboard record intent: ${value.runtimeType}');
}

dynamic _decode(dynamic value) {
  if (value is Map) {
    if (value.length == 1 && value['__dashboardTimestamp'] is String) {
      final date = DateTime.tryParse(value['__dashboardTimestamp'] as String);
      if (date == null) throw const FormatException('Invalid timestamp in Dashboard record intent.');
      return Timestamp.fromDate(date);
    }
    return value.map((key, item) => MapEntry(key.toString(), _decode(item)));
  }
  if (value is List) return value.map(_decode).toList();
  return value;
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a is Timestamp) a = a.toDate();
  if (b is Timestamp) b = b.toDate();
  if (a is DateTime && b is DateTime) return a.isAtSameMomentAs(b);
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((key) => b.containsKey(key) && _deepEquals(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length && List.generate(a.length, (i) => i).every((i) => _deepEquals(a[i], b[i]));
  }
  return a == b;
}
