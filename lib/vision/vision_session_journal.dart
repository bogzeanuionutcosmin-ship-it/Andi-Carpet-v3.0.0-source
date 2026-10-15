import 'vision_diagnostic_report.dart';
import 'vision_error_log.dart';

/// One active, strictly in-memory Vision diagnostic journal per owner epoch.
///
/// This is NOT the installation-wide [VisionErrorTelemetry] journal. It never
/// restores old snapshots or writes to secure storage, Firebase or a backend.
///
/// The caller MUST bind [startSession] to the authoritative AuthGate
/// UID-plus-generation ownership callback. A UID-only callback is insufficient
/// after A -> B -> A: no independent object can authenticate its own caller.
/// This is a port for a future authenticated integration, not a route or an
/// authorization mechanism by itself.
class VisionSessionJournal {
  VisionSessionJournal({
    this.maxEntries = 150,
    this.maxBytes = 48 * 1024,
    this.retention = const Duration(days: 7),
    DateTime Function()? clock,
  })  : assert(maxEntries > 0),
        assert(maxBytes > 0),
        assert(retention > Duration.zero),
        _clock = clock;

  final int maxEntries;
  final int maxBytes;
  final Duration retention;
  final DateTime Function()? _clock;

  Object? _currentKey;
  VisionErrorLog? _activeLog;

  /// Always creates a fresh lease, even if the same UID logs in again.
  ///
  /// Starting a new lease discards the previous in-memory log. Nothing is
  /// exported into the installation-wide journal or saved across restarts.
  VisionSessionJournalLease startSession({
    required bool Function() isSessionCurrent,
  }) {
    final key = Object();
    _currentKey = key;
    _activeLog = VisionErrorLog(
      maxEntries: maxEntries,
      maxBytes: maxBytes,
      retention: retention,
      clock: _clock,
    );
    return VisionSessionJournalLease._(this, key, isSessionCurrent);
  }

  /// Explicit logout, disposal or revocation discards all collected events.
  void revoke() {
    _currentKey = null;
    _activeLog = null;
  }

  bool _owns(Object key, bool Function() verify) {
    if (!identical(_currentKey, key)) return false;
    try {
      if (verify()) return true;
    } catch (_) {
      // A throwing ownership check denies access, never grants it.
    }
    // Invalidation also disposes this epoch's log. A stale lease must not
    // invalidate a newer active lease for user B or a returning A2.
    if (identical(_currentKey, key)) revoke();
    return false;
  }

  VisionErrorLog? _read(Object key, bool Function() verify) =>
      _owns(key, verify) ? _activeLog : null;
}

/// A revocable capability limited to one authenticated session generation.
///
/// Do not cache returned entries/reports across a logout or route change.
/// Any UI consuming these methods must check [isCurrent] before rendering and
/// again immediately before an export/share operation.
class VisionSessionJournalLease {
  VisionSessionJournalLease._(this._journal, this._key, this._verify);

  final VisionSessionJournal _journal;
  final Object _key;
  final bool Function() _verify;

  bool get isCurrent => _journal._owns(_key, _verify);

  /// Reports only fixed, sanitized diagnostic identifiers.
  /// Returns false for revoked/expired ownership, without side effects.
  bool record({
    required String area,
    required String code,
    required String platform,
    VisionErrorSeverity severity = VisionErrorSeverity.error,
  }) {
    final current = _journal._read(_key, _verify);
    if (current == null) return false;
    current.record(
      area: area,
      code: code,
      platform: platform,
      severity: severity,
    );
    return isCurrent;
  }

  /// Returns an immutable point-in-time copy only if this epoch still owns
  /// the log. Consumers must never retain/display it after revocation.
  List<VisionErrorEntry> get entries =>
      _journal._read(_key, _verify)?.entries ??
      const <VisionErrorEntry>[];

  bool resolve(String fingerprint) {
    final current = _journal._read(_key, _verify);
    if (current == null) return false;
    return current.resolve(fingerprint) && isCurrent;
  }

  /// Build a detached, bounded read-only *view snapshot* for the diagnostics
  /// widget. No caller receives the live mutable session journal.
  ///
  /// The caller MUST pass [isCurrent] to the consuming UI and re-check it at
  /// render/copy/share time. A detached snapshot is NOT an auth credential:
  /// retaining/displaying it after revocation would be a privacy bug.
  VisionErrorLog? snapshotForDisplay() {
    final current = _journal._read(_key, _verify);
    if (current == null) return null;
    final snapshot = VisionErrorLog(
      maxEntries: _journal.maxEntries,
      maxBytes: _journal.maxBytes,
      retention: _journal.retention,
      clock: _journal._clock,
    );
    // A validated summary round-trip; no global journal, I/O or backend.
    snapshot.restore(current.encode());
    if (!isCurrent) return null;
    return snapshot;
  }

  /// Optional, anonymous opt-in handoff, not a background upload.
  /// This never gives access to the device-wide persisted journal.
  String? buildReport() {
    final current = _journal._read(_key, _verify);
    if (current == null) return null;
    final report = VisionDiagnosticReport.build(current);
    if (!isCurrent) return null;
    return report;
  }
}
