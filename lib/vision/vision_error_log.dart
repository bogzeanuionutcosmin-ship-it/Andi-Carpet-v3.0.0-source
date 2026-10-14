import 'dart:convert';

/// A device-local diagnostic summary. Raw exceptions, stack traces and user
/// data are intentionally NOT accepted by this model.
enum VisionErrorSeverity { warning, error, critical }

class VisionErrorEntry {
  final String fingerprint;
  final String area;
  final String code;
  final String platform;
  final VisionErrorSeverity severity;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int count;
  final bool resolved;

  const VisionErrorEntry({
    required this.fingerprint,
    required this.area,
    required this.code,
    required this.platform,
    required this.severity,
    required this.firstSeen,
    required this.lastSeen,
    required this.count,
    this.resolved = false,
  });

  Map<String, Object> toJson() => <String, Object>{
        'area': area,
        'code': code,
        'platform': platform,
        'severity': severity.name,
        'firstSeen': firstSeen.toUtc().toIso8601String(),
        'lastSeen': lastSeen.toUtc().toIso8601String(),
        'count': count,
        'resolved': resolved,
      };
}

/// Bounded offline diagnostics, independent of Firebase and paid AI services.
///
/// Only constant-like identifiers are accepted, never exception.toString(),
/// message bodies, OCR text, coordinates, tokens or arbitrary stack traces.
/// Entries are summaries; identical events update one counter.
class VisionErrorLog {
  VisionErrorLog({
    this.maxEntries = 500,
    this.maxBytes = 1024 * 1024,
    this.retention = const Duration(days: 7),
    DateTime Function()? clock,
  })  : assert(maxEntries > 0),
        assert(maxBytes > 0),
        assert(retention > Duration.zero),
        _clock = clock ?? DateTime.now;

  final int maxEntries;
  final int maxBytes;
  final Duration retention;
  final DateTime Function() _clock;
  final Map<String, VisionErrorEntry> _entries = <String, VisionErrorEntry>{};

  // Reject unstructured strings instead of trying to redact sensitive text.
  static final RegExp _identifier = RegExp(r'^[a-z][a-z0-9_]{0,47}$');

  static String safeCode(String value) {
    final lowered = value.toLowerCase();
    return _identifier.hasMatch(lowered) ? lowered : 'unknown';
  }

  static String _fingerprint(String area, String code, String platform) =>
      area + '/' + code + '/' + platform;

  int get length {
    prune();
    return _entries.length;
  }

  List<VisionErrorEntry> get entries {
    prune();
    return List<VisionErrorEntry>.unmodifiable(
      _entries.values.toList()
        ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen)),
    );
  }

  int get encodedBytes => utf8.encode(encode()).length;

  void record({
    required String area,
    required String code,
    required String platform,
    VisionErrorSeverity severity = VisionErrorSeverity.error,
  }) {
    final now = _clock().toUtc();
    prune();
    final safeArea = safeCode(area);
    final safeEventCode = safeCode(code);
    final safePlatform = safeCode(platform);
    final key = _fingerprint(safeArea, safeEventCode, safePlatform);
    final previous = _entries[key];
    if (previous != null) {
      _entries[key] = VisionErrorEntry(
        fingerprint: key,
        area: safeArea,
        code: safeEventCode,
        platform: safePlatform,
        severity: severity.index > previous.severity.index
            ? severity
            : previous.severity,
        firstSeen: previous.firstSeen,
        // Wall clocks can move backward briefly after a network time fix.
        // Preserve a valid firstSeen <= lastSeen interval so this summary
        // survives the next encrypted-cache restore without dropping counts.
        lastSeen: now.isAfter(previous.lastSeen)
            ? now
            : previous.lastSeen,
        count: previous.count == 0x7fffffff ? previous.count : previous.count + 1,
        resolved: false, // A new occurrence reopens a resolved incident.
      );
    } else {
      _entries[key] = VisionErrorEntry(
        fingerprint: key,
        area: safeArea,
        code: safeEventCode,
        platform: safePlatform,
        severity: severity,
        firstSeen: now,
        lastSeen: now,
        count: 1,
      );
    }
    _trim();
  }

  bool resolve(String fingerprint) {
    prune();
    final previous = _entries[fingerprint];
    if (previous == null || previous.resolved) return false;
    _entries[fingerprint] = VisionErrorEntry(
      fingerprint: previous.fingerprint,
      area: previous.area,
      code: previous.code,
      platform: previous.platform,
      severity: previous.severity,
      firstSeen: previous.firstSeen,
      lastSeen: previous.lastSeen,
      count: previous.count,
      resolved: true,
    );
    return true;
  }

  void prune() {
    final now = _clock().toUtc();
    _entries.removeWhere((_, e) =>
        e.lastSeen.isAfter(now.add(const Duration(minutes: 1))) ||
        now.difference(e.lastSeen) > retention);
    _trim();
  }

  void _trim() {
    while (_entries.length > maxEntries || _sizeBytes() > maxBytes) {
      if (_entries.isEmpty) return;
      // Evict resolved entries first, then the least recently seen.
      final ordered = _entries.values.toList()
        ..sort((a, b) {
          if (a.resolved != b.resolved) return a.resolved ? -1 : 1;
          // Among equally resolved items, evict lower severity first.
          // This is storage prioritization, not an incident diagnosis.
          // Retention and hard byte/entry caps still apply to critical items.
          final severity = a.severity.index.compareTo(b.severity.index);
          if (severity != 0) return severity;
          return a.lastSeen.compareTo(b.lastSeen);
        });
      _entries.remove(ordered.first.fingerprint);
    }
  }

  int _sizeBytes() => utf8.encode(_serialize()).length;

  String _serialize() => jsonEncode(<String, Object>{
        'version': 1,
        'items': _entries.values.map((e) => e.toJson()).toList(),
      });

  String encode() {
    prune();
    return _serialize();
  }

  /// Imports only validated summaries. Malformed or untrusted cached content
  /// cannot become a diagnostic message. Values outside the cap are ignored.
  void restore(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > maxBytes * 4) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['version'] != 1 ||
          decoded['items'] is! List) {
        return;
      }
      final items = decoded['items'] as List;
      final now = _clock().toUtc();
      for (final value in items.take(maxEntries * 2)) {
        if (value is! Map) continue;
        final area = value['area'];
        final code = value['code'];
        final platform = value['platform'];
        final first = value['firstSeen'];
        final last = value['lastSeen'];
        final severityValue = value['severity'];
        final count = value['count'];
        if (area is! String || code is! String || platform is! String ||
            first is! String || last is! String ||
            severityValue is! String || count is! int ||
            count <= 0 || count > 0x7fffffff) {
          continue;
        }
        if (!_identifier.hasMatch(area) ||
            !_identifier.hasMatch(code) ||
            !_identifier.hasMatch(platform)) {
          continue;
        }
        final firstTime = DateTime.tryParse(first)?.toUtc();
        final lastTime = DateTime.tryParse(last)?.toUtc();
        if (firstTime == null || lastTime == null ||
            firstTime.isAfter(lastTime) ||
            lastTime.isAfter(now.add(const Duration(minutes: 1))) ||
            now.difference(lastTime) > retention) {
          continue;
        }
        final severity = VisionErrorSeverity.values.where(
          (s) => s.name == severityValue,
        );
        if (severity.isEmpty) continue;
        final key = _fingerprint(area, code, platform);
        if (_entries.containsKey(key)) continue;
        _entries[key] = VisionErrorEntry(
          fingerprint: key,
          area: area,
          code: code,
          platform: platform,
          severity: severity.first,
          firstSeen: firstTime,
          lastSeen: lastTime,
          count: count,
          resolved: value['resolved'] == true,
        );
      }
      prune();
    } on FormatException {
      // Corrupt cache is disposable and never prevents app startup.
    } on TypeError {
      // Ignore unexpected old cache format.
    }
  }
}
