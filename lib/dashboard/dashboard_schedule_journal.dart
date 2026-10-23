import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// One schedule document in a durable graph START or STOP batch.
/// `desired` carries stable updatedAt/writeToken values so a replay can be
/// recognized exactly after the original transaction committed but its ACK was
/// lost.
class DashboardScheduleWrite {
  const DashboardScheduleWrite({
    required this.scheduleId,
    required this.expectedExists,
    required this.expectedUpdatedAt,
    required this.expectedWriteToken,
    required this.desired,
  });

  final String scheduleId;
  final bool expectedExists;
  final Timestamp? expectedUpdatedAt;
  final String? expectedWriteToken;
  final Map<String, dynamic> desired;

  Map<String, dynamic> toJson() => {
        'scheduleId': scheduleId,
        'expectedExists': expectedExists,
        'expectedUpdatedAt': expectedUpdatedAt?.toDate().toIso8601String(),
        'expectedWriteToken': expectedWriteToken,
        'desired': _encode(desired),
      };

  factory DashboardScheduleWrite.fromJson(Map<String, dynamic> json) {
    if (json['scheduleId'] is! String ||
        json['expectedExists'] is! bool ||
        (json['expectedUpdatedAt'] != null && json['expectedUpdatedAt'] is! String) ||
        (json['expectedWriteToken'] != null && json['expectedWriteToken'] is! String) ||
        json['desired'] is! Map) {
      throw const FormatException('Invalid Dashboard schedule write.');
    }
    final atText = json['expectedUpdatedAt'] as String?;
    final at = atText == null ? null : DateTime.tryParse(atText);
    if (atText != null && at == null) throw const FormatException('Invalid schedule baseline timestamp.');
    final value = DashboardScheduleWrite(
      scheduleId: json['scheduleId'] as String,
      expectedExists: json['expectedExists'] as bool,
      expectedUpdatedAt: at == null ? null : Timestamp.fromDate(at),
      expectedWriteToken: json['expectedWriteToken'] as String?,
      desired: Map<String, dynamic>.from(_decode(json['desired']) as Map),
    );
    value.validate();
    return value;
  }

  void validate({String? teamId, String? graphId, required String transition}) {
    if (scheduleId.trim().isEmpty ||
        (teamId != null && desired['teamId'] != teamId) ||
        (graphId != null && desired['graphId'] != graphId) ||
        desired['teamId'] is! String ||
        desired['graphId'] is! String ||
        desired['updatedAt'] is! Timestamp ||
        desired['writeToken'] is! String ||
        (desired['writeToken'] as String).trim().isEmpty ||
        desired['started'] != (transition == 'start') ||
        desired['paused'] != false ||
        (!expectedExists && (expectedUpdatedAt != null || expectedWriteToken != null))) {
      throw const FormatException('Dashboard schedule write does not match its transition or scope.');
    }
  }
}

class DashboardScheduleIntent {
  const DashboardScheduleIntent({
    required this.userId,
    required this.teamId,
    required this.graphId,
    required this.transition,
    required this.writes,
  });

  final String userId;
  final String teamId;
  final String graphId;
  final String transition;
  final List<DashboardScheduleWrite> writes;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'userId': userId,
        'teamId': teamId,
        'graphId': graphId,
        'transition': transition,
        'writes': writes.map((write) => write.toJson()).toList(),
      };

  factory DashboardScheduleIntent.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['userId'] is! String ||
        json['teamId'] is! String ||
        json['graphId'] is! String ||
        !const {'start', 'stop'}.contains(json['transition']) ||
        json['writes'] is! List) {
      throw const FormatException('Invalid Dashboard schedule intent.');
    }
    final intent = DashboardScheduleIntent(
      userId: json['userId'] as String,
      teamId: json['teamId'] as String,
      graphId: json['graphId'] as String,
      transition: json['transition'] as String,
      writes: (json['writes'] as List).map((item) {
        if (item is! Map) throw const FormatException('Invalid schedule write row.');
        return DashboardScheduleWrite.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
    );
    intent.validate();
    return intent;
  }

  void validate() {
    if (userId.trim().isEmpty || teamId.trim().isEmpty || graphId.trim().isEmpty ||
        !const {'start', 'stop'}.contains(transition) || writes.isEmpty) {
      throw const FormatException('Dashboard schedule intent is outside its valid scope.');
    }
    final ids = <String>{};
    for (final write in writes) {
      write.validate(teamId: teamId, graphId: graphId, transition: transition);
      if (!ids.add(write.scheduleId)) throw const FormatException('Duplicate schedule ID in Dashboard write batch.');
    }
  }

  bool sameOperation(DashboardScheduleIntent other) =>
      userId == other.userId && teamId == other.teamId && graphId == other.graphId &&
      transition == other.transition && _deepEquals(writes.map((w) => w.toJson()).toList(), other.writes.map((w) => w.toJson()).toList());
}

enum DashboardScheduleWritePlan { write, replay }

/// Returns replay only when every document already contains the exact desired
/// version. Returns write only when every document still matches its original
/// CAS baseline. Mixed or changed batches fail closed.
DashboardScheduleWritePlan dashboardScheduleWritePlan({
  required DashboardScheduleIntent intent,
  required List<Map<String, dynamic>?> currentDocuments,
}) {
  intent.validate();
  if (currentDocuments.length != intent.writes.length) {
    throw StateError('Graficul s-a schimbat; reîncarcă înainte de a salva.');
  }
  final exactReplay = List.generate(intent.writes.length, (index) {
    final current = currentDocuments[index];
    return current != null && _containsDesired(current, intent.writes[index].desired);
  }).every((matches) => matches);
  if (exactReplay) return DashboardScheduleWritePlan.replay;

  final baselineMatches = List.generate(intent.writes.length, (index) {
    final write = intent.writes[index];
    final current = currentDocuments[index];
    if (current == null) return !write.expectedExists;
    if (!write.expectedExists) return false;
    if (current['teamId'] != intent.teamId || current['graphId'] != intent.graphId) return false;
    final updatedAt = current['updatedAt'];
    final writeToken = current['writeToken'];
    if (write.expectedUpdatedAt == null ? updatedAt != null :
        updatedAt is! Timestamp || !updatedAt.toDate().isAtSameMomentAs(write.expectedUpdatedAt!.toDate())) {
      return false;
    }
    return writeToken == write.expectedWriteToken;
  }).every((matches) => matches);
  if (baselineMatches) return DashboardScheduleWritePlan.write;
  throw StateError('Una sau mai multe zile au fost modificate de pe alt dispozitiv. Reîncarcă graficul și aplică din nou operația.');
}

bool _containsDesired(Map<String, dynamic> current, Map<String, dynamic> desired) =>
    desired.keys.every((key) => current.containsKey(key) && _deepEquals(current[key], desired[key]));

class DashboardScheduleJournal {
  const DashboardScheduleJournal({required this.read, required this.write, required this.remove});

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) remove;
  static final Set<String> _inFlight = <String>{};

  String _key(String userId, String teamId) =>
      'dashboard_schedule_intent_v1_${base64Url.encode(utf8.encode(jsonEncode([userId, teamId])))}';

  Future<DashboardScheduleIntent?> pending({required String userId, required String teamId}) async {
    final raw = await read(_key(userId, teamId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Intent is not an object.');
      final intent = DashboardScheduleIntent.fromJson(Map<String, dynamic>.from(decoded));
      if (intent.userId != userId || intent.teamId != teamId) throw const FormatException('Intent scope mismatch.');
      return intent;
    } on FormatException catch (error) {
      throw StateError('Dashboard schedule recovery data is unreadable: $error');
    }
  }

  Future<void> run({
    required DashboardScheduleIntent candidate,
    required Future<void> Function(DashboardScheduleIntent intent) send,
  }) async {
    candidate.validate();
    final key = _key(candidate.userId, candidate.teamId);
    if (!_inFlight.add(key)) throw StateError('A Dashboard schedule save is already running for this team.');
    try {
      final current = await pending(userId: candidate.userId, teamId: candidate.teamId);
      if (current != null && !current.sameOperation(candidate)) {
        throw StateError('A previous Dashboard schedule save is unresolved; reconnect and retry it first.');
      }
      final intent = current ?? candidate;
      if (current == null) await write(key, jsonEncode(intent.toJson()));
      await send(intent);
      await remove(key);
    } finally {
      _inFlight.remove(key);
    }
  }
}

dynamic _encode(dynamic value) {
  if (value is Timestamp) return {'__dashboardScheduleTimestamp': value.toDate().toIso8601String()};
  if (value is DateTime) return {'__dashboardScheduleTimestamp': value.toIso8601String()};
  if (value is Map) return value.map((key, item) => MapEntry(key.toString(), _encode(item)));
  if (value is List) return value.map(_encode).toList();
  if (value == null || value is String || value is num || value is bool) return value;
  throw ArgumentError('Unsupported value in Dashboard schedule intent: ${value.runtimeType}');
}

dynamic _decode(dynamic value) {
  if (value is Map) {
    if (value.length == 1 && value['__dashboardScheduleTimestamp'] is String) {
      final date = DateTime.tryParse(value['__dashboardScheduleTimestamp'] as String);
      if (date == null) throw const FormatException('Invalid timestamp in Dashboard schedule intent.');
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
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((key) => b.containsKey(key) && _deepEquals(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length && List.generate(a.length, (index) => index).every((index) => _deepEquals(a[index], b[index]));
  }
  return a == b;
}
